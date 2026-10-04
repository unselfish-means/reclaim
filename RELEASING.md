# Releasing

How a change goes from a merged PR to a GitHub release and a CurseForge upload.
There is no CI or packager. Every step is manual, which is fine at this size.

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
- creates the GitHub release with `gh release create --target <sha>`, which creates the tag for you.
  Never pre-tag.

```
Reclaim/
  Reclaim.toc
  *.lua        (every file the .toc lists)
  Libs/        (whole folder)
  LICENSE      (copied from the repo root)
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

The script prints the release URL and the local path of the zip to upload to CurseForge. Check the
result with `gh release view <ver> --json tagName,targetCommitish,assets`.

## Upload to CurseForge

The upload is manual, on the project page's *Upload File* form. The project page values (name, summary,
categories) and the icon are listed in the README's [CurseForge project](README.md#curseforge-project)
section.

1. **File**: the `Reclaim-<ver>.zip` you just attached to the GitHub release. Using the same file keeps
   the two in sync.
2. **Display name**: `<ver>`, such as `1.0.0`.
3. **Release type**: Release. Use Beta only if the `.toc` targets a beta client you haven't been able to
   test properly.
4. **Game versions**: select every build listed in the `.toc`'s `## Interface` line. A brand-new client
   build may not be in the list yet. If so, upload without it and say so in the changelog rather than
   picking the wrong version.
5. **Changelog**: paste the GitHub release notes (Markdown works).

## After releasing

- Check that the *Latest* badge on GitHub points at the new tag.
- If a client build was missing from CurseForge's version list, check back after a few days and edit the
  file's game versions once it appears.

## Recovering from a bad release

- **Wrong zip or wrong notes, but the tag is fine**: run `gh release upload <ver> <zip> --clobber` or
  `gh release edit <ver> --notes-file ...`. Re-upload to CurseForge as a new file, and archive the bad
  one there.
- **Bad code**: don't move the tag. Fix it with a patch bump and a new release.
