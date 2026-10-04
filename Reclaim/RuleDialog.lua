-- RuleDialog: add or edit one of your rules. Opened from the minimap menu and the options page.
--
-- The item comes from dropping it on the slot, shift-clicking it while the dialog is open, or
-- typing its ID. Item and quest names fill in as the game loads them.

local _, ns = ...
local RuleDialog = {}
ns.RuleDialog = RuleDialog

local dialog
local editingItemID -- the item whose rule is being edited, nil when adding

local function currentItemID()
    return tonumber(dialog.itemBox:GetText())
end

local function update()
    local itemID = currentItemID()
    if itemID then
        local name = C_Item.GetItemNameByID(itemID)
        if not name then C_Item.RequestLoadItemDataByID(itemID) end
        dialog.itemName:SetText(name or "Item name not loaded yet")
        dialog.icon:SetTexture(C_Item.GetItemIconByID(itemID))
    else
        dialog.itemName:SetText("")
        dialog.icon:SetTexture(nil)
    end

    local quests, err = ns.Rules.ParseQuestList(dialog.questBox:GetText())
    local lines = {}
    if not quests then
        lines[1] = err
    elseif #quests == 0 then
        lines[1] = "Blank: always safe to delete"
    else
        for i, questID in ipairs(quests) do
            local title = C_QuestLog.GetTitleForQuestID(questID)
            if not title then C_QuestLog.RequestLoadQuestByID(questID) end
            lines[i] = title or ("Quest %d (name not loaded yet)"):format(questID)
        end
    end
    dialog.questNames:SetText(table.concat(lines, "\n"))

    local count = quests and #quests or 0
    dialog.all:SetShown(count > 1)
    dialog.any:SetShown(count > 1)
    dialog.account:SetEnabled(count > 0)
    dialog.error:SetText("")
end

local function save()
    local itemID = currentItemID()
    if not itemID then
        dialog.error:SetText("Choose an item first.")
        return
    end
    local quests, err = ns.Rules.ParseQuestList(dialog.questBox:GetText())
    if not quests then
        dialog.error:SetText(err)
        return
    end
    local any = #quests > 1 and dialog.any:GetChecked()
    local account = #quests > 0 and dialog.account:GetChecked()
    local raw = ns.Rules.Build(quests, any, account)
    if editingItemID and editingItemID ~= itemID then ns.RemoveRule(editingItemID) end
    ns.SetRule(itemID, raw)
    dialog:Hide()
end

local function takeCursorItem()
    local kind, itemID = GetCursorInfo()
    if kind ~= "item" then return end
    dialog.itemBox:SetText(itemID)
    ClearCursor()
end

local function createEditBox(label, anchor, numeric)
    local text = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -14)
    text:SetWidth(60)
    text:SetJustifyH("LEFT")
    text:SetText(label)
    local box = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
    box:SetSize(190, 20)
    box:SetPoint("LEFT", text, "RIGHT", 8, 0)
    box:SetAutoFocus(false)
    box:SetNumeric(numeric)
    box:SetScript("OnTextChanged", update)
    box:SetScript("OnEnterPressed", save)
    box:SetScript("OnEscapePressed", box.ClearFocus)
    return box, text
end

local function createCheck(label, onClick)
    local check = CreateFrame("CheckButton", nil, dialog, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check.Text:SetText(label)
    check:SetScript("OnClick", onClick)
    return check
end

local function create()
    dialog = CreateFrame("Frame", "ReclaimRuleDialog", UIParent, "BasicFrameTemplateWithInset")
    dialog:SetSize(320, 330)
    dialog:SetPoint("CENTER", 0, 60)
    dialog:SetFrameStrata("DIALOG")
    dialog:SetToplevel(true)
    dialog:SetMovable(true)
    dialog:SetClampedToScreen(true)
    dialog:EnableMouse(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
    dialog:Hide()
    table.insert(UISpecialFrames, "ReclaimRuleDialog")

    dialog.title = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dialog.title:SetPoint("TOP", 0, -6)

    local slot = CreateFrame("Button", nil, dialog)
    slot:SetSize(37, 37)
    slot:SetPoint("TOPLEFT", 16, -36)
    local empty = slot:CreateTexture(nil, "BACKGROUND")
    empty:SetAllPoints()
    empty:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
    dialog.icon = slot:CreateTexture(nil, "ARTWORK")
    dialog.icon:SetAllPoints()
    slot:SetScript("OnReceiveDrag", takeCursorItem)
    slot:SetScript("OnClick", takeCursorItem)
    slot:SetScript("OnEnter", function(self)
        local itemID = currentItemID()
        if not itemID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(itemID)
        GameTooltip:Show()
    end)
    slot:SetScript("OnLeave", GameTooltip_Hide)

    local hint = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("LEFT", slot, "RIGHT", 10, 0)
    hint:SetPoint("RIGHT", -16, 0)
    hint:SetJustifyH("LEFT")
    hint:SetText("Drop an item here, shift-click one, or type its ID.")

    local itemLabel
    dialog.itemBox, itemLabel = createEditBox("Item ID", slot, true)
    dialog.itemName = dialog:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    dialog.itemName:SetPoint("TOPLEFT", dialog.itemBox, "BOTTOMLEFT", -4, -4)

    local questLabel
    dialog.questBox, questLabel = createEditBox("Quests", itemLabel, false)
    questLabel:SetPoint("TOPLEFT", itemLabel, "BOTTOMLEFT", 0, -32)
    dialog.questNames = dialog:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    dialog.questNames:SetPoint("TOPLEFT", dialog.questBox, "BOTTOMLEFT", -4, -4)
    dialog.questNames:SetWidth(190)
    dialog.questNames:SetJustifyH("LEFT")

    dialog.all = createCheck("All", function()
        dialog.all:SetChecked(true)
        dialog.any:SetChecked(false)
    end)
    dialog.any = createCheck("Any", function()
        dialog.any:SetChecked(true)
        dialog.all:SetChecked(false)
    end)
    dialog.account = createCheck("Any character counts")
    dialog.all:SetPoint("TOPLEFT", dialog.questNames, "BOTTOMLEFT", -4, -8)
    dialog.any:SetPoint("LEFT", dialog.all.Text, "RIGHT", 16, 0)
    dialog.account:SetPoint("TOPLEFT", dialog.all, "BOTTOMLEFT", 0, -4)

    dialog.error = dialog:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
    dialog.error:SetPoint("BOTTOMLEFT", 16, 44)
    dialog.error:SetPoint("BOTTOMRIGHT", -16, 44)

    local saveButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    saveButton:SetSize(90, 22)
    saveButton:SetPoint("BOTTOMRIGHT", -14, 14)
    saveButton:SetText(SAVE or "Save")
    saveButton:SetScript("OnClick", save)

    local cancelButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    cancelButton:SetSize(90, 22)
    cancelButton:SetPoint("RIGHT", saveButton, "LEFT", -6, 0)
    cancelButton:SetText(CANCEL or "Cancel")
    cancelButton:SetScript("OnClick", function() dialog:Hide() end)
end

-- Opens the dialog empty to add a rule, or filled in to edit your rule for itemID.
function RuleDialog.Open(itemID)
    if not dialog then create() end
    editingItemID = itemID
    local rule = itemID and ns.Rules.Normalize(ns.db.rules[itemID])
    dialog.title:SetText(rule and "Edit rule" or "Add rule")
    dialog.itemBox:SetText(itemID and tostring(itemID) or "")
    dialog.questBox:SetText(rule and table.concat(rule.quests, ", ") or "")
    dialog.any:SetChecked(rule ~= nil and rule.any)
    dialog.all:SetChecked(not dialog.any:GetChecked())
    dialog.account:SetChecked(rule ~= nil and rule.account)
    dialog:Show()
    update()
end

-- Shift-clicking an item while the dialog is open fills in the item.
local function onInsertLink(link)
    if not dialog or not dialog:IsShown() or type(link) ~= "string" then return end
    local itemID = link:match("item:(%d+)")
    if itemID then dialog.itemBox:SetText(itemID) end
end

if ChatFrameUtil and ChatFrameUtil.InsertLink then
    hooksecurefunc(ChatFrameUtil, "InsertLink", onInsertLink)
elseif ChatEdit_InsertLink then
    hooksecurefunc("ChatEdit_InsertLink", onInsertLink)
end

local function refreshIfShown()
    if dialog and dialog:IsShown() then update() end
end

ns.On("ITEM_DATA_LOAD_RESULT", refreshIfShown)
ns.On("QUEST_DATA_LOAD_RESULT", refreshIfShown)
