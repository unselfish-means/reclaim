-- Standalone tests for Reclaim/Rules.lua. Run from the repo root:  lua tests/rules_test.lua

local ns = {}
assert(loadfile("Reclaim/Rules.lua"))("Reclaim", ns)
local R = ns.Rules

local failures, count = 0, 0
local function check(name, got, want)
    count = count + 1
    if got ~= want then
        failures = failures + 1
        print(("FAIL %s\n  got:  %s\n  want: %s"):format(name, tostring(got), tostring(want)))
    end
end

local function completed(set)
    return function(questID) return set[questID] == true end
end

-- Normalize
local rule = R.Normalize(true)
check("always: no quests", #rule.quests, 0)
rule = R.Normalize(96139)
check("number: one quest", rule.quests[1], 96139)
check("number: all mode", rule.any, false)
rule = R.Normalize({ 1, 2, any = true, account = true })
check("table: quests", #rule.quests, 2)
check("table: any", rule.any, true)
check("table: account", rule.account, true)
check("false is not a rule", R.Normalize(false), nil)
check("string is not a rule", R.Normalize("x"), nil)

-- Lookup: user rules win, false hides a built-in
local builtin = { [10] = 100, [20] = true }
check("builtin used", R.Lookup(10, builtin, {}).quests[1], 100)
check("user overrides", R.Lookup(10, builtin, { [10] = 200 }).quests[1], 200)
check("user false hides", R.Lookup(10, builtin, { [10] = false }), nil)
check("unknown item", R.Lookup(99, builtin, {}), nil)
check("user-only item", #R.Lookup(30, builtin, { [30] = true }).quests, 0)

-- Evaluate
local safe, done = R.Evaluate(R.Normalize(true), completed({}))
check("always safe", safe, true)
check("always safe: no quests listed", #done, 0)
check("single incomplete", R.Evaluate(R.Normalize(1), completed({})), false)
safe, done = R.Evaluate(R.Normalize(1), completed({ [1] = true }))
check("single complete", safe, true)
check("single complete: lists quest", done[1], 1)
check("all: one missing", R.Evaluate(R.Normalize({ 1, 2 }), completed({ [1] = true })), false)
safe, done = R.Evaluate(R.Normalize({ 1, 2 }), completed({ [1] = true, [2] = true }))
check("all: both done", safe, true)
check("all: lists both", #done, 2)
check("any: none done", R.Evaluate(R.Normalize({ 1, 2, any = true }), completed({})), false)
safe, done = R.Evaluate(R.Normalize({ 1, 2, any = true }), completed({ [2] = true }))
check("any: second done", safe, true)
check("any: lists the done one", done[1], 2)
check("any with no quests is always safe", (R.Evaluate(R.Normalize({ any = true }), completed({}))), true)

local sawAccount
R.Evaluate(R.Normalize({ 1, account = true }), function(_, account) sawAccount = account; return false end)
check("account flag passed to isComplete", sawAccount, true)

-- QuestIDs
local ids = R.QuestIDs({ [1] = 100, [2] = { 200, 300 } }, { [3] = true, [4] = false, [5] = 100 })
local n = 0
for _ in pairs(ids) do n = n + 1 end
check("quest ids: unique count", n, 3)
check("quest ids: from table rule", ids[300], true)

-- Parse
local itemID, raw = R.Parse("281149 96139")
check("parse id + quest: item", itemID, 281149)
check("parse id + quest: rule", raw, 96139)
itemID, raw = R.Parse("281149")
check("parse id only: always", raw, true)
itemID, raw = R.Parse("|cffffffff|Hitem:281149::::::::80:::::|h[Weathered Ledger]|h|r 96139 96140 any")
check("parse link: item", itemID, 281149)
check("parse link: quests", #raw, 2)
check("parse link: any", raw.any, true)
check("parse link: account unset", raw.account, nil)
itemID, raw = R.Parse("5 7 ACCOUNT")
check("parse single quest + account stays a table", type(raw), "table")
check("parse account", raw.account, true)
check("parse missing item", select(2, R.Parse("")), "give an item ID or shift-click an item")
check("parse bad token", select(2, R.Parse("5 seven")), "didn't understand 'seven'")
check("parse any without quests", select(2, R.Parse("5 any")), "'any' and 'account' need at least one quest ID")

-- Describe
check("describe always", R.Describe(true), "always safe")
check("describe single", R.Describe(96139), "after quest 96139")
check("describe all", R.Describe({ 1, 2 }), "after all of quests 1, 2")
check("describe any + account", R.Describe({ 1, 2, any = true, account = true }), "after any of quests 1, 2 (any character)")
check("describe hidden", R.Describe(false), "hidden")

print(("%d checks, %d failures"):format(count, failures))
if failures > 0 then os.exit(1) end
