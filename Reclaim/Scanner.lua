-- Scanner: walks the bags, decides which items are safe to delete, and publishes the result
-- as ns.state, then fires "Scanned".
--
--   ns.state.items   list of {bag, slot, itemID, link, icon, count, reason}, in bag order
--   ns.state.byItem  [itemID] = reason, for every safe item in the bags
--   ns.state.free    free slots in general-purpose bags

local _, ns = ...
local Scanner = {}
ns.Scanner = Scanner

ns.state = { items = {}, byItem = {}, free = 0 }

local LAST_BAG = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS

local function isComplete(questID, account)
    if C_QuestLog.IsQuestFlaggedCompleted(questID) then return true end
    if not account then return false end
    if ns.db.accountQuests[questID] then return true end
    local onAccount = C_QuestLog.IsQuestFlaggedCompletedOnAccount
    return onAccount ~= nil and onAccount(questID) == true
end

-- Account-wide rules need to know about quests other characters finished. Remember every
-- quest any rule mentions once this character has it complete.
local function recordAccountQuests()
    for questID in pairs(ns.Rules.QuestIDs(ns.BuiltinRules, ns.db.rules)) do
        if not ns.db.accountQuests[questID] and C_QuestLog.IsQuestFlaggedCompleted(questID) then
            ns.db.accountQuests[questID] = true
        end
    end
end

local function questName(questID)
    return C_QuestLog.GetTitleForQuestID(questID) or ("quest " .. questID)
end

-- Returns the reason an item is safe to delete, or nil if it isn't.
function Scanner.Reason(itemID)
    local rule = ns.Rules.Lookup(itemID, ns.BuiltinRules, ns.db.rules)
    if not rule then return nil end
    local safe, done = ns.Rules.Evaluate(rule, isComplete)
    if not safe then return nil end
    if #done == 0 then return "Always safe to delete" end
    local names = {}
    for i, questID in ipairs(done) do names[i] = questName(questID) end
    return "Completed: " .. table.concat(names, ", ")
end

function Scanner.Scan()
    if not ns.db then return end
    recordAccountQuests()
    local items, byItem, free = {}, {}, 0
    local reasons = {}
    for bag = BACKPACK_CONTAINER, LAST_BAG do
        local bagFree, bagFamily = C_Container.GetContainerNumFreeSlots(bag)
        if bagFamily == 0 then free = free + (bagFree or 0) end
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                local itemID = info.itemID
                if reasons[itemID] == nil then reasons[itemID] = Scanner.Reason(itemID) or false end
                local reason = reasons[itemID]
                if reason then
                    byItem[itemID] = reason
                    items[#items + 1] = {
                        bag = bag, slot = slot, itemID = itemID, link = info.hyperlink,
                        icon = info.iconFileID, count = info.stackCount, reason = reason,
                    }
                end
            end
        end
    end
    ns.state = { items = items, byItem = byItem, free = free }
    ns.Fire("Scanned")
end

-- Bag and quest events come in bursts; scan once after they settle.
local pending = false

function Scanner.Request(delay)
    if pending then return end
    pending = true
    C_Timer.After(delay or 0.2, function()
        pending = false
        Scanner.Scan()
    end)
end

ns.On("PLAYER_ENTERING_WORLD", function() Scanner.Request() end)
ns.On("BAG_UPDATE_DELAYED", function() Scanner.Request() end)
ns.On("QUEST_LOG_UPDATE", function() Scanner.Request(0.5) end)
-- The completed flag can lag the turn-in a little.
ns.On("QUEST_TURNED_IN", function() C_Timer.After(1, Scanner.Scan) end)
