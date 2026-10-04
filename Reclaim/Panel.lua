-- Panel: the review list, opened from the minimap icon, the addon compartment, or /reclaim.
-- One click deletes one stack. Nothing is ever deleted without a click.

local _, ns = ...
local Panel = {}
ns.Panel = Panel

local ROW_HEIGHT = 36
local MAX_ROWS = 12
local WIDTH = 340

local frame, rows, emptyText, moreText

-- Deletes the stack only if the slot still holds the item the row showed and it's still safe.
local function delete(entry)
    local info = C_Container.GetContainerItemInfo(entry.bag, entry.slot)
    if not info or info.itemID ~= entry.itemID or info.isLocked or not ns.Scanner.Reason(entry.itemID) then
        ns.Scanner.Request(0)
        return
    end
    ClearCursor()
    C_Container.PickupContainerItem(entry.bag, entry.slot)
    if CursorHasItem() then DeleteCursorItem() end
end

local function createRow(index)
    local row = CreateFrame("Button", nil, frame)
    row:SetSize(WIDTH - 24, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 12, -28 - (index - 1) * ROW_HEIGHT)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(28, 28)
    row.icon:SetPoint("LEFT", 0, 0)

    row.count = row:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    row.count:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", -1, 1)

    row.delete = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.delete:SetSize(64, 22)
    row.delete:SetPoint("RIGHT", 0, 0)
    row.delete:SetText(DELETE or "Delete")
    row.delete:SetScript("OnClick", function() delete(row.entry) end)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -1)
    row.name:SetPoint("RIGHT", row.delete, "LEFT", -8, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.reason = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.reason:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 1)
    row.reason:SetPoint("RIGHT", row.delete, "LEFT", -8, 0)
    row.reason:SetJustifyH("LEFT")
    row.reason:SetWordWrap(false)

    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetBagItem(self.entry.bag, self.entry.slot)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    return row
end

local function create()
    frame = CreateFrame("Frame", "ReclaimPanel", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(WIDTH, 120)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    table.insert(UISpecialFrames, "ReclaimPanel")

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("TOP", 0, -6)

    emptyText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyText:SetPoint("TOP", 0, -48)
    emptyText:SetText("Nothing in your bags is safe to delete.")

    moreText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    moreText:SetPoint("BOTTOM", 0, 10)

    rows = {}
    frame:SetScript("OnShow", Panel.Refresh)
end

function Panel.Refresh()
    if not frame or not frame:IsShown() then return end
    local items = ns.state.items
    local shown = math.min(#items, MAX_ROWS)
    frame.title:SetText(#items == 0 and "Reclaim" or ("Reclaim: %d safe to delete"):format(#items))
    for i = 1, math.max(shown, #rows) do
        local entry = items[i]
        if i <= shown then
            rows[i] = rows[i] or createRow(i)
            local row = rows[i]
            row.entry = entry
            row.icon:SetTexture(entry.icon)
            row.count:SetText(entry.count and entry.count > 1 and entry.count or "")
            row.name:SetText(entry.link or ("item:" .. entry.itemID))
            row.reason:SetText(entry.reason)
            row:Show()
        else
            rows[i]:Hide()
        end
    end
    emptyText:SetShown(#items == 0)
    local extra = #items - shown
    moreText:SetText(extra > 0 and ("%d more. Delete some to see them."):format(extra) or "")
    local height = 40 + math.max(shown, 1) * ROW_HEIGHT + (extra > 0 and 20 or 0)
    frame:SetHeight(height)
end

function Panel.Toggle()
    if not frame then create() end
    frame:SetShown(not frame:IsShown())
end

ns.Listen("Scanned", Panel.Refresh)
