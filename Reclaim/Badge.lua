-- Badge: the count of safe-to-delete items, shown on the backpack button and the minimap icon.
-- Optional (the "badge" option). By default it stays hidden until free bag slots drop to the
-- threshold, the moment the count is worth seeing.

local _, ns = ...
local Badge = {}
ns.Badge = Badge

local badges = {}

function Badge.Attach(parent)
    if not parent then return end
    local badge = CreateFrame("Frame", nil, parent)
    badge:SetSize(18, 18)
    badge:SetPoint("TOPRIGHT", 4, 4)
    badge:SetFrameLevel(parent:GetFrameLevel() + 10)
    local background = badge:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.6, 0.08, 0.08, 0.9)
    local mask = badge:CreateMaskTexture()
    mask:SetAllPoints()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    background:AddMaskTexture(mask)
    badge.text = badge:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    badge.text:SetPoint("CENTER", 0, 0)
    badge:Hide()
    badges[#badges + 1] = badge
    Badge.Refresh()
end

function Badge.ShouldShow()
    local count = #ns.state.items
    if not ns.db or not ns.db.badge or count == 0 then return false end
    return not ns.db.badgeOnlyWhenLow or ns.state.free <= ns.db.threshold
end

function Badge.Refresh()
    local show = Badge.ShouldShow()
    for _, badge in ipairs(badges) do
        badge.text:SetText(#ns.state.items)
        badge:SetShown(show)
    end
end

ns.Listen("Loaded", function() Badge.Attach(MainMenuBarBackpackButton) end)
ns.Listen("Scanned", Badge.Refresh)
ns.Listen("Options", Badge.Refresh)
