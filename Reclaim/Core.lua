-- Core: namespace, saved variables, event dispatch, options, and internal change notifications.

local ADDON, ns = ...

ns.name = ADDON

function ns.Print(fmt, ...)
    print("|cff33ccffReclaim:|r " .. fmt:format(...))
end

-- Event dispatch. Unknown events are skipped instead of erroring, since this
-- client mixes Classic and Retail event sets.
local eventFrame = CreateFrame("Frame")
local handlers = {}

function ns.On(event, fn)
    if not handlers[event] then
        if not pcall(eventFrame.RegisterEvent, eventFrame, event) then return false end
        handlers[event] = {}
    end
    table.insert(handlers[event], fn)
    return true
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    for _, fn in ipairs(handlers[event]) do fn(event, ...) end
end)

-- Internal notifications:
--   "Scanned"  the bag scan finished; ns.state holds the result
--   "Options"  an option changed (key, value)
local listeners = {}

function ns.Listen(message, fn)
    listeners[message] = listeners[message] or {}
    table.insert(listeners[message], fn)
end

function ns.Fire(message, ...)
    for _, fn in ipairs(listeners[message] or {}) do fn(...) end
end

local DEFAULTS = {
    badge = true,          -- show the count badge
    badgeOnlyWhenLow = true, -- ...only when free bag slots are at or below the threshold
    threshold = 4,
}

function ns.SetOption(key, value)
    ns.db[key] = value
    ns.Fire("Options", key, value)
end

local function rulesChanged()
    ns.Scanner.RecordNames()
    ns.Fire("Rules")
    ns.Scanner.Request(0)
end

-- Adds or replaces your rule for an item.
function ns.SetRule(itemID, raw)
    ns.db.rules[itemID] = raw
    rulesChanged()
end

-- Removes your rule for an item (which also un-hides a hidden built-in rule). If you have no
-- rule but a built-in one exists, hides the built-in one instead.
-- Returns "removed", "hidden", or nil when there was nothing to remove.
function ns.RemoveRule(itemID)
    local result
    if ns.db.rules[itemID] ~= nil then
        ns.db.rules[itemID] = nil
        ns.db.ruleInfo[itemID] = nil
        result = "removed"
    elseif ns.BuiltinRules[itemID] then
        ns.db.rules[itemID] = false
        result = "hidden"
    end
    if result then rulesChanged() end
    return result
end

-- ReclaimDB is account-wide:
--   rules          user rules, same format as BuiltinRules (false hides a built-in rule)
--   ruleInfo       [itemID] = {item = name, quests = {[questID] = title}} for user rules, so the
--                  rules can be read (and promoted to BuiltinRules.lua) outside the game
--   accountQuests  quests seen complete on any character, for account-wide rules
--   minimap        LibDBIcon position and visibility
ns.On("ADDON_LOADED", function(_, loaded)
    if loaded ~= ADDON then return end
    ReclaimDB = ReclaimDB or {}
    local db = ReclaimDB
    db.rules = db.rules or {}
    db.ruleInfo = db.ruleInfo or {}
    db.accountQuests = db.accountQuests or {}
    db.minimap = db.minimap or {}
    for key, value in pairs(DEFAULTS) do
        if db[key] == nil then db[key] = value end
    end
    ns.db = db
    ns.Fire("Loaded")
end)
