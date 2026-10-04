-- Rules: what makes an item safe to delete. Pure Lua with no game API, so it can be tested
-- standalone (tests/rules_test.lua).
--
-- A rule, keyed by item ID, is one of:
--   true                           always safe
--   96139                          safe once quest 96139 is complete
--   {96139, 96140}                 safe once every listed quest is complete
--   {96139, 96140, any = true}     safe once any listed quest is complete
--   {96139, account = true}        a quest counts if any character on the account completed it
--   false                          (user rules only) hide the built-in rule for this item

local _, ns = ...
local Rules = {}
ns.Rules = Rules

-- Returns {quests = {...}, any = bool, account = bool}, or nil if raw isn't a rule.
function Rules.Normalize(raw)
    if raw == true then return { quests = {}, any = false, account = false } end
    if type(raw) == "number" then return { quests = { raw }, any = false, account = false } end
    if type(raw) ~= "table" then return nil end
    local quests = {}
    for _, questID in ipairs(raw) do
        if type(questID) == "number" then quests[#quests + 1] = questID end
    end
    return { quests = quests, any = raw.any == true, account = raw.account == true }
end

-- User rules win over built-in ones; a user rule of false hides the built-in one.
function Rules.Lookup(itemID, builtin, user)
    local raw = user and user[itemID]
    if raw == nil then raw = builtin[itemID] end
    if not raw then return nil end
    return Rules.Normalize(raw)
end

-- isComplete(questID, account) -> bool.
-- Returns false, or true plus the list of completed quest IDs that made the item safe
-- (empty for an always-safe rule).
function Rules.Evaluate(rule, isComplete)
    local done = {}
    for _, questID in ipairs(rule.quests) do
        if isComplete(questID, rule.account) then
            done[#done + 1] = questID
            if rule.any then return true, done end
        elseif not rule.any then
            return false
        end
    end
    if rule.any and #rule.quests > 0 then return false end
    return true, done
end

-- Every quest ID referenced by the given rule tables, as a set.
function Rules.QuestIDs(...)
    local set = {}
    for i = 1, select("#", ...) do
        for _, raw in pairs(select(i, ...)) do
            local rule = Rules.Normalize(raw)
            if rule then
                for _, questID in ipairs(rule.quests) do set[questID] = true end
            end
        end
    end
    return set
end

-- Builds the most compact raw rule for a list of quest IDs. Returns raw, or nil, error message.
function Rules.Build(quests, any, account)
    if #quests == 0 then
        if any or account then return nil, "'any' and 'account' need at least one quest ID" end
        return true
    end
    if #quests == 1 and not account then return quests[1] end
    local raw = {}
    for i, questID in ipairs(quests) do raw[i] = questID end
    if any then raw.any = true end
    if account then raw.account = true end
    return raw
end

-- Parses quest IDs separated by spaces or commas. Returns the list, or nil, error message.
function Rules.ParseQuestList(text)
    local quests = {}
    for token in (text or ""):gsub(",", " "):gmatch("%S+") do
        local questID = tonumber(token)
        if not questID then return nil, ("'%s' isn't a quest ID"):format(token) end
        quests[#quests + 1] = questID
    end
    return quests
end

-- Parses "/reclaim add" arguments: an item ID or item link, then quest IDs and the words
-- "any" and "account". Returns itemID, raw rule; or nil, error message.
function Rules.Parse(text)
    text = text or ""
    local itemID = tonumber(text:match("item:(%d+)"))
    if itemID then
        text = text:gsub("|c.-|r", "", 1):gsub("|H.-|h.-|h", "", 1)
    end
    local quests, any, account = {}, false, false
    for token in text:gmatch("%S+") do
        local lower = token:lower()
        local number = tonumber(token)
        if lower == "any" then
            any = true
        elseif lower == "account" then
            account = true
        elseif number and not itemID then
            itemID = number
        elseif number then
            quests[#quests + 1] = number
        else
            return nil, ("didn't understand '%s'"):format(token)
        end
    end
    if not itemID then return nil, "give an item ID or shift-click an item" end
    local raw, err = Rules.Build(quests, any, account)
    if not raw then return nil, err end
    return itemID, raw
end

-- A short description of a raw rule. questName(questID) names a quest; quest IDs are used
-- when it's omitted.
function Rules.Describe(raw, questName)
    if raw == false then return "built-in rule hidden" end
    local rule = Rules.Normalize(raw)
    if not rule then return "invalid" end
    if #rule.quests == 0 then return "always safe" end
    local names = {}
    for i, questID in ipairs(rule.quests) do
        names[i] = questName and questName(questID) or ("quest " .. questID)
    end
    local text
    if #names == 1 then
        text = "after " .. names[1]
    elseif rule.any then
        text = "after any of " .. table.concat(names, ", ")
    else
        text = "after all of " .. table.concat(names, ", ")
    end
    if rule.account then text = text .. " (any character)" end
    return text
end
