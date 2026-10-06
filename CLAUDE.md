# Reclaim

A WoW: Forever addon (toc `16001`, Retail-style API) that marks bag items safe to delete. See
[README.md](README.md) for what it does, the rule format, and commands.

## Layout

- `Reclaim/` is the addon folder. The `.toc` lists every file in load order, so a new file must be
  added there or it never loads.
- `Reclaim/Rules.lua` holds the pure rule logic, with no game API. Its tests are in
  `tests/rules_test.lua`.
- `Reclaim/BuiltinRules.lua` holds the rules that ship with the addon.
- Releases: [RELEASING.md](RELEASING.md) and the `release-addon` skill (`.claude/skills/release-addon/`).
- `scripts/deploy.ps1` links `Reclaim/` into the beta client's AddOns folder as a junction. Edits are
  live after `/reload`.

## GitHub account

The repo is `unselfish-means/reclaim`, under the same account as BestAroundRevisited. In `gh` that
account is the `puppysnuff` login, and it's usually not the active account.

- **Git**: this clone's `.git/config` sets the commit identity to `unselfish-means <48777436+unselfish-means@users.noreply.github.com>`
  and adds a credential helper that hands git `gh auth token -u puppysnuff`, so `git push` works as
  `unselfish-means` whichever `gh` account is active.
- **Signing**: the same `.git/config` sets `user.signingkey` to `~/.ssh/id_ed25519_unselfish_means_signing.pub`,
  a key registered as a signing key on `unselfish-means`, so commits show Verified. Don't sign with the
  global (personal) key.
- **gh**: prefix commands with that account's token instead of switching accounts, for example
  `GH_TOKEN="$(gh auth token -u puppysnuff)" gh pr create ...` (Bash) or
  `$env:GH_TOKEN = gh auth token -u puppysnuff` (PowerShell).

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
