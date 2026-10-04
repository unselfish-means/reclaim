-- BagOverlay: marks safe-to-delete items in the bags.
--
-- Works with Blizzard's bags, and with Baganator through its corner-widget API when Baganator is
-- loaded. Neither is required: anything missing on this client is skipped.

local _, ns = ...

local MARK_TEXTURE = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"

local function setMark(button, show)
    if not button.ReclaimMark then
        if not show then return end
        local mark = button:CreateTexture(nil, "OVERLAY", nil, 7)
        mark:SetTexture(MARK_TEXTURE)
        mark:SetSize(16, 16)
        mark:SetPoint("TOPRIGHT", 2, 2)
        button.ReclaimMark = mark
    end
    button.ReclaimMark:SetShown(show)
end

local function markSlot(button, bag, slot)
    local info = C_Container.GetContainerItemInfo(bag, slot)
    setMark(button, info ~= nil and ns.state.byItem[info.itemID] ~= nil)
end

-- Blizzard bags (Retail-style container frames).
local function updateFrame(frame)
    if not frame.EnumerateValidItems then return end
    for _, button in frame:EnumerateValidItems() do
        markSlot(button, button:GetBagID(), button:GetID())
    end
end

local frames = { ContainerFrameCombinedBags }
for i = 1, NUM_CONTAINER_FRAMES or 13 do
    local frame = _G["ContainerFrame" .. i]
    if frame then frames[#frames + 1] = frame end
end
for _, frame in ipairs(frames) do
    if frame.UpdateItems then hooksecurefunc(frame, "UpdateItems", updateFrame) end
end

-- Blizzard bags (Classic-style container frames), in case this client still uses them.
local function updateLegacyFrame(frame)
    local name = frame:GetName()
    for i = 1, frame.size or 0 do
        local button = _G[name .. "Item" .. i]
        if button then markSlot(button, frame:GetID(), button:GetID()) end
    end
end

if ContainerFrame_Update then hooksecurefunc("ContainerFrame_Update", updateLegacyFrame) end

local function refreshBlizzard()
    for _, frame in ipairs(frames) do
        if frame:IsShown() then updateFrame(frame) end
    end
    for i = 1, NUM_CONTAINER_FRAMES or 13 do
        local frame = _G["ContainerFrame" .. i]
        if frame and frame:IsShown() and not frame.EnumerateValidItems then updateLegacyFrame(frame) end
    end
end

-- Baganator.
local baganator = Baganator and Baganator.API and Baganator.API.RegisterCornerWidget and Baganator.API

if baganator then
    baganator.RegisterCornerWidget("Reclaim: safe to delete", "reclaim", function(_, details)
        return details.itemID ~= nil and ns.state.byItem[details.itemID] ~= nil
    end, function(itemButton)
        local mark = itemButton:CreateTexture(nil, "OVERLAY")
        mark:SetTexture(MARK_TEXTURE)
        mark:SetSize(15, 15)
        return mark
    end, { corner = "top_right", priority = 1 })
end

ns.Listen("Scanned", function()
    refreshBlizzard()
    if baganator then baganator.RequestItemButtonsRefresh() end
end)
