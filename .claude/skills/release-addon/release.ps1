<#
.SYNOPSIS
    Packages a zip of the addon from a git ref and (unless -DryRun) pushes a
    tag with the .toc version and publishes a GitHub release on it. The tag
    push is what triggers CurseForge's automatic packaging (see .pkgmeta).

.DESCRIPTION
    The version is never passed in -- it is read from `## Version` in the .toc
    at the given ref, so the tag can't drift from what the addon reports.
    Packaging works from `git archive`, not the working tree, so untracked or
    local-only files can't leak into the zip. The zip's root folder is the
    addon folder (Reclaim/) containing only the ship list: the .toc, every
    file it lists, the whole Libs\ folder, and the repo's LICENSE.

.PARAMETER Title
    Release title. Short description of what changed, not the version.

.PARAMETER NotesFile
    Path to a Markdown file with the release notes. Required unless -DryRun.
    (A file, not a string: multi-line strings passed to gh on PowerShell get
    split into separate arguments.)

.PARAMETER Ref
    Git ref to release. Defaults to origin/main after a fetch.

.PARAMETER DryRun
    Build and verify the zip, print where it is, and stop before touching
    GitHub. Skips the tag-exists and notes checks.

.EXAMPLE
    .\release.ps1 -DryRun
    .\release.ps1 -Title "First release" -NotesFile .\notes.md
#>
[CmdletBinding()]
param(
    [string]$Title,
    [string]$NotesFile,
    [string]$Ref = "origin/main",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$AddonName = "Reclaim"
$TocName = "$AddonName.toc"
$TocPath = "$AddonName/$TocName"

if (-not $DryRun) {
    if (-not $Title) { throw "-Title is required (or use -DryRun)." }
    if (-not $NotesFile) { throw "-NotesFile is required (or use -DryRun)." }
    if (-not (Test-Path $NotesFile)) { throw "Notes file not found: $NotesFile" }
    $NotesFile = (Resolve-Path $NotesFile).Path
}

Push-Location $RepoRoot
try {
    # --- Resolve the ref -------------------------------------------------------
    if ($Ref.StartsWith("origin/")) {
        git fetch --quiet origin
        if ($LASTEXITCODE -ne 0) { throw "git fetch origin failed" }
    }
    $Sha = (git rev-parse --verify --quiet "$Ref^{commit}")
    if ($LASTEXITCODE -ne 0 -or -not $Sha) { throw "Ref not found: $Ref" }
    $Sha = $Sha.Trim()

    # --- Read the version from the .toc at that ref -----------------------------
    $tocText = git show "${Sha}:$TocPath"
    if ($LASTEXITCODE -ne 0) { throw "$TocPath not found at $Ref" }
    $versionLine = $tocText | Where-Object { $_ -match '^## Version:\s*(\S+)' } | Select-Object -First 1
    if (-not $versionLine) { throw "No '## Version:' line in $TocPath at $Ref" }
    $Version = $Matches[1]
    Write-Host "Releasing $AddonName $Version from $Ref ($($Sha.Substring(0,7)))"

    # --- Refuse to reuse a tag ------------------------------------------------
    if (-not $DryRun) {
        git rev-parse --verify --quiet "refs/tags/$Version" *> $null
        if ($LASTEXITCODE -eq 0) { throw "Tag $Version already exists locally. Bump ## Version in the .toc first." }
        $remoteTag = git ls-remote --tags origin "refs/tags/$Version"
        if ($remoteTag) { throw "Tag $Version already exists on origin. Bump ## Version in the .toc first." }
        gh release view $Version *> $null
        if ($LASTEXITCODE -eq 0) { throw "GitHub release $Version already exists." }
    }

    # --- Stage a clean tree from git archive -----------------------------------
    $Work = Join-Path $env:TEMP "reclaim-release-$Version"
    if (Test-Path $Work) { Remove-Item -Recurse -Force -Confirm:$false $Work }
    $Src = Join-Path $Work "src"
    $Pkg = Join-Path $Work "pkg\$AddonName"
    New-Item -ItemType Directory -Path $Src, $Pkg | Out-Null

    $tarPath = Join-Path $Work "src.tar"
    git archive --format=tar --output=$tarPath $Sha
    if ($LASTEXITCODE -ne 0) { throw "git archive failed" }
    tar -xf $tarPath -C $Src
    if ($LASTEXITCODE -ne 0) { throw "tar extract failed" }

    # --- Copy the ship list ---------------------------------------------------
    # The .toc and every file it lists (paths are relative to the addon folder),
    # plus Libs\ as a whole folder so nothing a library needs is left behind,
    # plus LICENSE from the repo root, which MIT asks to ship with copies.
    $AddonSrc = Join-Path $Src $AddonName
    $listed = $tocText | ForEach-Object { $_.Trim() } | Where-Object {
        $_ -ne "" -and -not $_.StartsWith("#") -and -not $_.StartsWith("Libs\")
    }
    foreach ($relPath in @($TocName) + $listed) {
        $from = Join-Path $AddonSrc $relPath
        if (-not (Test-Path $from)) { throw "File listed in $TocName not found at ${Ref}: $relPath" }
        $to = Join-Path $Pkg $relPath
        New-Item -ItemType Directory -Force -Path (Split-Path $to) | Out-Null
        Copy-Item $from $to
    }
    $libs = Join-Path $AddonSrc "Libs"
    if (-not (Test-Path $libs)) { throw "$AddonName\Libs\ not found at $Ref" }
    Copy-Item -Recurse $libs (Join-Path $Pkg "Libs")
    $license = Join-Path $Src "LICENSE"
    if (-not (Test-Path $license)) { throw "LICENSE not found at $Ref" }
    Copy-Item $license (Join-Path $Pkg "LICENSE")

    # Every .toc-listed library file must have made it in with the Libs\ copy.
    $tocText | ForEach-Object { $_.Trim() } | Where-Object { $_.StartsWith("Libs\") } | ForEach-Object {
        if (-not (Test-Path (Join-Path $Pkg $_))) { throw "Library listed in $TocName missing from package: $_" }
    }

    # --- Zip and verify the root -----------------------------------------------
    $Zip = Join-Path $Work "$AddonName-$Version.zip"
    Compress-Archive -Path (Join-Path $Work "pkg\$AddonName") -DestinationPath $Zip -CompressionLevel Optimal -Force

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($Zip)
    try {
        $entries = $archive.Entries | ForEach-Object { $_.FullName -replace '\\', '/' }
        $badRoot = $entries | Where-Object { -not $_.StartsWith("$AddonName/") }
        if ($badRoot) { throw "Zip has entries outside $AddonName/: $($badRoot -join ', ')" }
        if ("$AddonName/$TocName" -notin $entries) { throw "Zip is missing $AddonName/$TocName" }
        Write-Host "Packaged $Zip ($($entries.Count) files, $([math]::Round((Get-Item $Zip).Length / 1KB)) KB)"
        Write-Host "Top-level entries:"
        $entries | Where-Object { $_ -notmatch "/Libs/" } | ForEach-Object { Write-Host "  $_" }
    } finally {
        $archive.Dispose()
    }

    if ($DryRun) {
        Write-Host "Dry run -- no tag or release created."
        return
    }

    # --- Publish ---------------------------------------------------------------
    # Push the tag with git so CurseForge's webhook sees a tag push and packages
    # it as a release; then attach the GitHub release to that existing tag.
    git tag $Version $Sha
    if ($LASTEXITCODE -ne 0) { throw "git tag failed" }
    git push origin "refs/tags/$Version"
    if ($LASTEXITCODE -ne 0) { throw "git push of tag $Version failed" }
    gh release create $Version $Zip --verify-tag --title $Title --notes-file $NotesFile --latest
    if ($LASTEXITCODE -ne 0) { throw "gh release create failed (tag $Version is already pushed; retry with gh release create)" }

    Write-Host ""
    Write-Host "CurseForge packages tag $Version automatically. Check the project's Files tab."
} finally {
    Pop-Location
}
