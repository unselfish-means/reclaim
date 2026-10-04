-- Slash commands.
--
--   /reclaim                                  toggle the review panel
--   /reclaim add <item> [quest ...] [any] [account]
--                                             add or replace your rule for an item
--   /reclaim remove <item>                    remove your rule, or hide a built-in one
--   /reclaim list                             list built-in and your rules
--   /reclaim threshold <n>                    badge wakes at n or fewer free slots
--   /reclaim options                          open the options page
--
-- <item> is an item ID or a shift-clicked item link.

local _, ns = ...

local function itemName(itemID)
    return ns.Scanner.ItemName(itemID)
end

local commands = {}

function commands.add(rest)
    local itemID, raw = ns.Rules.Parse(rest)
    if not itemID then
        ns.Print("Couldn't add the rule: %s.", raw)
        return
    end
    ns.SetRule(itemID, raw)
    ns.Print("%s: %s.", itemName(itemID), ns.Scanner.Describe(raw))
end

function commands.remove(rest)
    local itemID = tonumber(rest:match("item:(%d+)") or rest:match("^%s*(%d+)"))
    if not itemID then
        ns.Print("Give an item ID or shift-click an item.")
        return
    end
    local wasHidden = ns.db.rules[itemID] == false
    local result = ns.RemoveRule(itemID)
    if result == "removed" then
        ns.Print("%s: %s.", itemName(itemID), wasHidden and "built-in rule restored" or "your rule removed")
    elseif result == "hidden" then
        ns.Print("%s: built-in rule hidden.", itemName(itemID))
    else
        ns.Print("%s has no rule.", itemName(itemID))
    end
end

local function listRules(label, rules)
    local ids = {}
    for itemID in pairs(rules) do ids[#ids + 1] = itemID end
    table.sort(ids)
    ns.Print("%s (%d):", label, #ids)
    for _, itemID in ipairs(ids) do
        ns.Print("  %d %s: %s", itemID, itemName(itemID), ns.Scanner.Describe(rules[itemID]))
    end
end

function commands.list()
    listRules("Built-in rules", ns.BuiltinRules)
    listRules("Your rules", ns.db.rules)
end

function commands.threshold(rest)
    local n = tonumber(rest)
    if not n or n < 0 then
        ns.Print("Threshold is %d free slots. Set it with /reclaim threshold <n>.", ns.db.threshold)
        return
    end
    ns.SetOption("threshold", math.floor(n))
    ns.Print("Badge wakes at %d or fewer free slots.", ns.db.threshold)
end

function commands.options()
    ns.Options.Open()
end

SLASH_RECLAIM1 = "/reclaim"
SlashCmdList.RECLAIM = function(text)
    local command, rest = (text or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "" then
        ns.Panel.Toggle()
    elseif commands[command] then
        commands[command](rest)
    else
        ns.Print("Commands: add, remove, list, threshold, options. /reclaim alone opens the review panel.")
    end
end
