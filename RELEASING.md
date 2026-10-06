# Releasing

How a change goes from a merged PR to a GitHub release and a CurseForge file.

## CurseForge automatic packaging

The CurseForge project is linked to this repo with "Package all commits", and
[.pkgmeta](.pkgmeta) tells the packager what to ship:

- **Every push to `main`** is packaged as an **alpha** file. Players on the release channel don't see
  it.
- **Every pushed tag** is packaged as a **release** file. A tag containing `beta` or `alpha` (such as
  `1.1.0-beta1`) is packaged as that type instead.
- `.pkgmeta` moves `Reclaim/Reclaim/` up to be the package's `Reclaim/` folder and ignores the rest
  of the repo. Dot-folders such as `.claude/` are ignored automatically. A new top-level file or
  folder must be added to `ignore`.
- `Reclaim/LICENSE` is a copy of the repo-root `LICENSE`, so it ships inside the moved folder. The root
  copy stays for GitHub's license detection. Change both together.
- CurseForge sets the file's game version from the `.toc`'s `## Interface` line.

## Conventions

- **Tags** are the bare version, such as `1.0.0` (no `v` prefix). The tag must match `## Version` in
  `Reclaim/Reclaim.toc`.
- **Version bumps** happen in the PR that changes behavior, not at release time. Bump the patch number
  for fixes and the minor number for new features or new client support. Docs-only and tooling-only
  changes don't bump.
- **Interface versions** (`## Interface` in the `.toc`) must list every client build the release is
  uploaded for. The client's build number is in `<WoW install>\_<flavor>_\.build.info` (the `Version`
  column; for example, `1.60.1` becomes `16001`).
- **Release title** is a short description of what changed, not the version. Notes are for players:
  what changed and which clients are supported.

## Before you release

1. The PR is merged to `main`, and `main` is fetched locally.
2. `## Version` in the `.toc` on `main` is the version you're about to tag.
3. The build has been tried in game on the clients you're claiming support for. At minimum, check the
   bag marks, the tooltip line, the review panel, the minimap menu, and adding a rule.

## Package and publish

The `release-addon` skill's script,
[.claude/skills/release-addon/release.ps1](.claude/skills/release-addon/release.ps1), does both (ask
Claude to "cut a release", or run it yourself). It:

- reads `## Version` from the `.toc` at `origin/main`, so the version is never typed in and the tag
  can't drift from what the addon reports;
- refuses if that tag or release already exists (bump the version in a PR);
- packages from `git archive`, not the working tree, so local-only files can't leak in;
- zips the **ship list only** under a `Reclaim/` root and checks it before publishing;
- tags the commit and pushes the tag with `git push`, which triggers the CurseForge release build
  (a tag created through `gh`/the API may not reach the webhook). Never pre-tag;
- creates the GitHub release on that tag with the zip attached.

```
Reclaim/
  Reclaim.toc
  *.lua        (every file the .toc lists)
  Libs/        (whole folder)
  LICENSE      (a copy of the repo-root LICENSE)
```

Nothing else ships: no `.claude/`, `README.md`, `RELEASING.md`, `CURSEFORGE.md`, `tests/`, `scripts/`, `media/`, or
`.git`. Don't upload GitHub's auto-generated source zip. Its root folder is `reclaim-<tag>/`, so the
game won't load it.

Always dry-run first, then publish with a title and a notes **file**. Use a file, not a string:
multi-line strings passed to `gh` on PowerShell get split into separate arguments.

```powershell
& .\.claude\skills\release-addon\release.ps1 -DryRun
```

```powershell
& .\.claude\skills\release-addon\release.ps1 `
  -Title "Short description of the release" `
  -NotesFile .\notes.md
```

### Release notes

```markdown
One-paragraph summary.

## Changes
- What changed, from the player's point of view. Skip tooling and docs.

## Supported clients
WoW: Forever (Classic Plus) 1.60

## Install
Download `Reclaim-<ver>.zip` and extract it into `Interface\AddOns\`.
```

The script prints the release URL. Check the result with
`gh release view <ver> --json tagName,targetCommitish,assets`.

## After releasing

- Check that the *Latest* badge on GitHub points at the new tag.
- On the CurseForge project's *Files* tab, check that `<ver>` appears as a **Release** with the right
  game version. The packager's changelog is built from commits, so edit the file and paste the GitHub
  release notes as its changelog if you want the player-facing notes there.
- If a client build was missing from CurseForge's version list, check back after a few days and edit the
  file's game versions once it appears. The project page values (name, summary, categories) and the
  icon are listed in the README's [CurseForge project](README.md#curseforge-project) section.

## Recovering from a bad release

- **Wrong zip or wrong notes, but the tag is fine**: run `gh release upload <ver> <zip> --clobber` or
  `gh release edit <ver> --notes-file ...`. On CurseForge, edit or archive the packaged file.
- **Bad code**: don't move the tag. Fix it with a patch bump and a new release.
