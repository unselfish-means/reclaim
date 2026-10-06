# Reclaim

A WoW: Forever addon (toc `16001`, Retail-style API) that marks bag items safe to delete.
[README.md](README.md) is the player-facing description of what it does and its commands, and it's
also the description pasted into CurseForge. Keep development notes out of it; they belong here,
in [RELEASING.md](RELEASING.md), or in files linked from here.

## Layout

- `Reclaim/` is the addon folder. The `.toc` lists every file in load order, so a new file must be
  added there or it never loads.
- `Reclaim/Rules.lua` holds the pure rule logic, with no game API. Its tests are in
  `tests/rules_test.lua`.
- `Reclaim/BuiltinRules.lua` holds the rules that ship with the addon.
- Releases: [RELEASING.md](RELEASING.md) and the `release-addon` skill (`.claude/skills/release-addon/`).
- `scripts/deploy.ps1` links `Reclaim/` into the beta client's AddOns folder as a junction. Edits are
  live after `/reload`.
- `Reclaim/Libs/` vendors LibStub, CallbackHandler-1.0, LibDataBroker-1.1, and LibDBIcon-1.0 (minor 55).
- `media/icon.png` is the CurseForge project icon. It doesn't ship.

## Rule format

Each rule is keyed by item ID. Built-in rules live in `Reclaim/BuiltinRules.lua`, and the player's own
rules are saved account-wide in `ReclaimDB.rules`. When both exist for an item, the player's rule wins.

| Rule | Meaning |
|---|---|
| `true` | Always safe |
| `96139` | Safe once quest 96139 is complete |
| `{96139, 96140}` | Safe once **all** the listed quests are complete |
| `{96139, 96140, any = true}` | Safe once **any** of the listed quests is complete |
| `{96139, account = true}` | A quest counts if **any character** on the account completed it |

Account-wide quests: Reclaim records every quest a rule mentions once any character has it complete,
so a character only counts after it has logged in with Reclaim installed. If the client has
`C_QuestLog.IsQuestFlaggedCompletedOnAccount`, Reclaim checks that too.

## Not yet verified in game

- Bag slot marks on Blizzard's bags. These hook `UpdateItems` and `EnumerateValidItems` on the container
  frames (Retail-style), with a fallback to `ContainerFrame_Update` (Classic-style). Which one Forever
  uses hasn't been confirmed.
- Whether `C_QuestLog.IsQuestFlaggedCompletedOnAccount` exists on Forever. Reclaim works without it.

## GitHub account

The GitHub account and commit setup are in `CLAUDE.local.md` at the repo root (in a
worktree, look in the main checkout's root). It isn't committed. Read it before any commit, push, or `gh` command.

## Testing

There's no system Lua. Run the tests with fengari from npm, installed in a scratch directory:

```
npm i fengari-node-cli   # in a scratch dir, once
<scratch>/node_modules/.bin/fengari tests/rules_test.lua
```

Everything else is verified in game by the owner.

## Promoting the owner's in-game rules

The owner adds rules in game (from the Add rule dialog or with `/reclaim add`). WoW writes them when the
owner types `/reload` or logs out, to:

```
F:\Blizzard\World of Warcraft\_classic_beta_\WTF\Account\589955#1\SavedVariables\Reclaim.lua
```

- `ReclaimDB.rules[itemID]` is the rule, in the same format as `BuiltinRules.lua`. A value of `false`
  means the owner hid a built-in rule. Don't promote those.
- `ReclaimDB.ruleInfo[itemID]` holds `{item = name, quests = {[questID] = title}}`. Use these names for
  the comment on each promoted line.

To promote rules ("pull in my rules"):

1. Read the SavedVariables file. Never write to it: the game overwrites it on logout.
2. Add each rule that isn't already in `BuiltinRules.lua`, keeping the table sorted by item ID, with a
   comment naming the item and quest, for example `[281149] = 96139, -- Memories of Valor: The Valor Family`.
3. Open a PR. The owner's copies in SavedVariables can stay; a user rule that matches the built-in
   one changes nothing.

## CurseForge project

Quick reference for the values on the CurseForge project page (project ID 1727163).

| Field | Value |
|---|---|
| Project name | Reclaim |
| Summary | Marks bag items you no longer need, like leftover quest items, so you can delete them with confidence. |
| Description | Paste [README.md](README.md) (choose Markdown in the editor) |
| Main category | Bags & Inventory |
| Additional categories | Quests & Leveling, Tooltip |
| Game version | WoW: Forever (Classic Plus), toc `16001` |
| License | MIT |
| Project icon | [media/icon.png](media/icon.png) |
