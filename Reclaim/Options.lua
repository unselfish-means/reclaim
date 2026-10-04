-- Options: a page in Blizzard's settings window (Options > AddOns > Reclaim).

local ADDON, ns = ...
local Options = {}
ns.Options = Options

local category
local checks = {}

local function addCheck(panel, anchor, label, get, set)
    local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
    check.Text:SetText(label)
    check:SetScript("OnClick", function(self) set(self:GetChecked()) end)
    check.get = get
    checks[#checks + 1] = check
    return check
end

local function refresh()
    for _, check in ipairs(checks) do check:SetChecked(check.get()) end
    if checks.low then
        checks.low.Text:SetText(("Only when %d or fewer bag slots are free (/reclaim threshold <n>)"):format(ns.db.threshold))
    end
end

local function build()
    local panel = CreateFrame("Frame")
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(ADDON)

    local minimap = addCheck(panel, title, "Show minimap icon",
        function() return not ns.db.minimap.hide end, ns.Minimap.SetShown)
    local badge = addCheck(panel, minimap, "Show count badge on the backpack and minimap icon",
        function() return ns.db.badge end, function(value) ns.SetOption("badge", value) end)
    checks.low = addCheck(panel, badge, "",
        function() return ns.db.badgeOnlyWhenLow end, function(value) ns.SetOption("badgeOnlyWhenLow", value) end)
    checks.low:SetPoint("TOPLEFT", badge, "BOTTOMLEFT", 24, -4)

    panel:SetScript("OnShow", refresh)
    category = Settings.RegisterCanvasLayoutCategory(panel, ADDON)
    Settings.RegisterAddOnCategory(category)
end

function Options.Open()
    Settings.OpenToCategory(category:GetID())
end

ns.Listen("Loaded", build)
ns.Listen("Options", refresh)
