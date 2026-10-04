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

-- "Your rules": the rules you added (and built-in rules you hid), with Edit and Remove.
local ROW_HEIGHT = 34
local ruleList, ruleRows, emptyText = nil, {}, nil

local function createRuleRow(index)
    local row = CreateFrame("Frame", nil, ruleList)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    row:SetPoint("RIGHT", ruleList, "RIGHT", 0, 0)

    row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.remove:SetSize(70, 22)
    row.remove:SetPoint("RIGHT", 0, 0)
    row.remove:SetText(REMOVE or "Remove")
    row.remove:SetScript("OnClick", function() ns.RemoveRule(row.itemID) end)

    row.edit = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.edit:SetSize(60, 22)
    row.edit:SetPoint("RIGHT", row.remove, "LEFT", -4, 0)
    row.edit:SetText(EDIT or "Edit")
    row.edit:SetScript("OnClick", function() ns.RuleDialog.Open(row.itemID) end)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("TOPLEFT", 0, -2)
    row.name:SetPoint("RIGHT", row.edit, "LEFT", -8, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.description = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.description:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
    row.description:SetPoint("RIGHT", row.edit, "LEFT", -8, 0)
    row.description:SetJustifyH("LEFT")
    row.description:SetWordWrap(false)
    return row
end

local function refreshRules()
    if not ruleList then return end
    local ids = {}
    for itemID in pairs(ns.db.rules) do ids[#ids + 1] = itemID end
    table.sort(ids, function(a, b) return ns.Scanner.ItemName(a) < ns.Scanner.ItemName(b) end)
    for i, itemID in ipairs(ids) do
        ruleRows[i] = ruleRows[i] or createRuleRow(i)
        local row, raw = ruleRows[i], ns.db.rules[itemID]
        row.itemID = itemID
        row.name:SetText(("%s |cff808080(%d)|r"):format(ns.Scanner.ItemName(itemID), itemID))
        row.description:SetText(ns.Scanner.Describe(raw))
        row.edit:SetShown(raw ~= false)
        row:Show()
    end
    for i = #ids + 1, #ruleRows do ruleRows[i]:Hide() end
    ruleList:SetHeight(math.max(#ids, 1) * ROW_HEIGHT)
    emptyText:SetShown(#ids == 0)
end

local function buildRuleList(panel, anchor)
    local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -24, -24)
    header:SetText("Your rules")

    local add = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    add:SetSize(100, 22)
    add:SetPoint("LEFT", header, "RIGHT", 16, 0)
    add:SetText("Add rule")
    add:SetScript("OnClick", function() ns.RuleDialog.Open() end)

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -12)
    scroll:SetPoint("BOTTOMRIGHT", -32, 16)

    ruleList = CreateFrame("Frame", nil, scroll)
    ruleList:SetSize(1, ROW_HEIGHT)
    scroll:SetScrollChild(ruleList)
    scroll:SetScript("OnSizeChanged", function(self, width) ruleList:SetWidth(width) end)

    emptyText = ruleList:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyText:SetPoint("TOPLEFT", 0, -4)
    emptyText:SetText("You haven't added any rules. Use Add rule, or right-click the minimap icon.")
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

    buildRuleList(panel, checks.low)

    panel:SetScript("OnShow", function()
        refresh()
        refreshRules()
    end)
    category = Settings.RegisterCanvasLayoutCategory(panel, ADDON)
    Settings.RegisterAddOnCategory(category)
end

function Options.Open()
    Settings.OpenToCategory(category:GetID())
end

ns.Listen("Loaded", build)
ns.Listen("Options", refresh)
ns.Listen("Rules", refreshRules)
