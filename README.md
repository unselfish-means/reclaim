# Reclaim

A **WoW: Forever** addon (toc `16001`) that marks the bag items you no longer need, so you can delete
them with confidence. An item is marked by item ID, either always or once one or more quests are
complete.

## How it shows up

Reclaim stays quiet: no chat spam and no popups.

| Surface | When you see it |
|---|---|
| **Bag slot mark**: a red X in the slot's corner | Whenever your bags are open. Works with Blizzard's bags and with Baganator (as a corner widget, which you can move in Baganator's settings). Neither is required. |
| **Tooltip line**: "Reclaim: safe to delete" and the completed quests | When you hover the item. |
| **Review panel**: the list of safe items, one Delete button per stack | Left-click the minimap icon or its entry in the addon compartment, or type `/reclaim`. |
| **Count badge** on the backpack button and the minimap icon | Optional. By default it appears only when 4 or fewer bag slots are free. |

Right-clicking the minimap icon or the compartment entry opens a menu with three entries: turn the
count badge on or off, add a rule, and open the options page (Options › AddOns › Reclaim).

Nothing is ever deleted without a click. Before deleting, the panel checks that the slot still holds the
same item and that the item is still safe to delete.

## Rules

Each rule is keyed by item ID. Built-in rules live in [BuiltinRules.lua](Reclaim/BuiltinRules.lua),
and your own rules are saved account-wide. When both exist for an item, your rule wins.

To add your own rule, choose **Add rule…** from the minimap right-click menu, or use **Add rule** on
the options page. To fill in the item, drop it on the dialog's slot, shift-click it, or type its ID.
Then enter quest IDs separated by commas, or leave the box blank for "always safe". The options page
lists your rules, each with Edit and Remove.

| Rule | Meaning |
|---|---|
| `true` | Always safe |
| `96139` | Safe once quest 96139 is complete |
| `{96139, 96140}` | Safe once **all** the listed quests are complete |
| `{96139, 96140, any = true}` | Safe once **any** of the listed quests is complete |
| `{96139, account = true}` | A quest counts if **any character** on the account completed it |

**How account-wide works:** Reclaim remembers every quest a rule mentions once any character has it
complete. A character only counts after it has logged in with Reclaim installed. If the client has
`C_QuestLog.IsQuestFlaggedCompletedOnAccount`, Reclaim checks that too.

## Commands

```
/reclaim                                      toggle the review panel
/reclaim add <item> [quest ...] [any] [account]
/reclaim remove <item>                        remove your rule; run it again to hide a built-in rule
/reclaim list
/reclaim threshold <n>                        count badge appears at n or fewer free slots
/reclaim options
```

For `<item>`, give an item ID or shift-click the item into chat, for example
`/reclaim add 281149 96139`. To bring back a built-in rule you hid, add it again with
`/reclaim add`.

## Development

- **Deploy**: `scripts/deploy.ps1` links the `Reclaim` folder into the beta client's `Interface\AddOns`
  as a junction. Edits are live after `/reload`.
- **Tests**: The rules logic in [Rules.lua](Reclaim/Rules.lua) is pure Lua. Run its tests with any Lua
  interpreter from the repo root: `lua tests/rules_test.lua`.
- **Libraries**: LibStub, CallbackHandler-1.0, LibDataBroker-1.1, and LibDBIcon-1.0 (minor 55) are
  vendored in `Reclaim/Libs`.

### Not yet verified in game

- Bag slot marks on Blizzard's bags. These hook `UpdateItems` and `EnumerateValidItems` on the container
  frames (Retail-style), with a fallback to `ContainerFrame_Update` (Classic-style). Which one Forever
  uses hasn't been confirmed.
- Whether `C_QuestLog.IsQuestFlaggedCompletedOnAccount` exists on Forever. Reclaim works without it.

## CurseForge project

Quick reference for the values on the CurseForge project page.

| Field | Value |
|---|---|
| Project name | Reclaim |
| Summary | Marks bag items you no longer need, like leftover quest items, so you can delete them with confidence. |
| Description | Paste [CURSEFORGE.md](CURSEFORGE.md) (choose Markdown in the editor) |
| Main category | Bags & Inventory |
| Additional categories | Quests & Leveling, Tooltip |
| Game version | WoW: Forever (Classic Plus), toc `16001` |
| License | MIT |
| Project icon | [media/icon.png](media/icon.png) |

To publish a release, see [RELEASING.md](RELEASING.md).
