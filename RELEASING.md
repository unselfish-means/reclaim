# Releasing

How a change goes from a merged PR to a GitHub release and a CurseForge file.

## CurseForge packaging

The [Package and release](.github/workflows/release.yml) workflow runs the
[BigWigs packager](https://github.com/BigWigsMods/packager) and uploads the result to CurseForge. It
follows the shared WIKR setup, which is described in the `curseforge-packaging` runbook in
`wow-addons-skill`.

- **Every pushed tag** is uploaded as a **release** file. A tag containing `beta` or `alpha` (such as
  `1.1.0-beta1`) is uploaded as that type instead. Pushes to `main` don't upload anything.
- The CurseForge project ID is `## X-Curse-Project-ID` in the `.toc`. The upload token is the
  `CURSEFORGE_API_TOKEN` repository **Actions** secret (a Codespaces secret doesn't reach Actions). If
  either is missing, the workflow fails.
- The game version comes from `## Interface`. The packager maps `16xxx` to WoW: Forever, so `16001` is
  1.60.1.
- The file and its CurseForge display name are `Reclaim-<tag>`, such as `Reclaim-1.0.4`. Its changelog
  is generated from the commit messages since
  the previous tag, and it ships in the package as `CHANGELOG.md`.
- To retry an upload, run the workflow by hand on the *Actions* tab and give it the existing tag. Only
  tags whose `.toc` has `X-Curse-Project-ID` can be uploaded this way, so 1.0.2 and earlier can't.
- `.pkgmeta` moves `Reclaim/Reclaim/` up to be the package's `Reclaim/` folder and ignores the rest
  of the repo. Dot-folders such as `.claude/` are ignored automatically. A new top-level file or
  folder must be added to `ignore`.
- `Reclaim/LICENSE` is a copy of the repo-root `LICENSE`, so it ships inside the moved folder. The root
  copy stays for GitHub's license detection. Change both together.

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
- tags the commit and pushes the tag with `git push`, which starts the CurseForge workflow. Never
  pre-tag;
- creates the GitHub release on that tag with the zip attached.

```
Reclaim/
  Reclaim.toc
  *.lua        (every file the .toc lists)
  Libs/        (whole folder)
  LICENSE      (a copy of the repo-root LICENSE)
```

Nothing else ships: no `.claude/`, `CLAUDE.md`, `README.md`, `RELEASING.md`, `tests/`, `scripts/`, `media/`, or
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
- Check that the *Package and release* run for the tag passed: `gh run list --workflow release.yml`.
  If it failed, read the log (`gh run view <id> --log-failed`), fix the cause, and retry from the
  *Actions* tab with the tag.
- On the CurseForge project's *Files* tab, check that `<ver>` appears as a **Release** with the right
  game version. If you want the player-facing notes there, edit the file and replace the generated
  changelog with the GitHub release notes.
- If a client build was missing from CurseForge's version list, check back after a few days and edit the
  file's game versions once it appears. The project page values (name, summary, categories) and the
  icon are listed in the [CurseForge project](CLAUDE.md#curseforge-project) section of CLAUDE.md.
- If the release changes what players see (a new feature, command, or client), update
  [README.md](README.md) and paste it into the CurseForge project's description.

## Recovering from a bad release

- **Wrong zip or wrong notes, but the tag is fine**: run `gh release upload <ver> <zip> --clobber` or
  `gh release edit <ver> --notes-file ...`. On CurseForge, edit or archive the uploaded file.
- **Bad code**: don't move the tag. Fix it with a patch bump and a new release.
