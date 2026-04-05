<#
.SYNOPSIS
    Sets version, commits, and creates a GitHub release for satori-serena.

.DESCRIPTION
    Automates the release process: sets or bumps the version in pyproject.toml using uv,
    commits the change, pushes, and creates a GitHub release that triggers the
    Cloudsmith publish workflow.

    Requires either an explicit semver version or one of -Patch, -Minor, -Major.

.PARAMETER Version
    An explicit semver version to set (e.g. 1.0.0, 1.2.3.dev1742000000, 2.0.0.alpha).
    The base must be MAJOR.MINOR.PATCH (all numeric). An optional pre-release suffix
    (.dev*, .alpha*, .beta*, .rc*, .post*) is allowed.

.PARAMETER Patch
    Bump the patch component (e.g. 0.1.4 -> 0.1.5).

.PARAMETER Minor
    Bump the minor component (e.g. 0.1.4 -> 0.2.0).

.PARAMETER Major
    Bump the major component (e.g. 0.1.4 -> 1.0.0).

.EXAMPLE
    .\Publish-Package.ps1 1.2.0               # Set exact version 1.2.0
    .\Publish-Package.ps1 1.2.0.dev1742000000 # Set dev pre-release version
    .\Publish-Package.ps1 -Patch              # Bump patch  (0.1.4 -> 0.1.5)
    .\Publish-Package.ps1 -Minor              # Bump minor  (0.1.4 -> 0.2.0)
    .\Publish-Package.ps1 -Major              # Bump major  (0.1.4 -> 1.0.0)
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Version,

    [switch]$Patch,
    [switch]$Minor,
    [switch]$Major
)

$ErrorActionPreference = "Stop"

# ── Validate arguments ──────────────────────────────────────────────────────
$switchCount = [int]$Patch.IsPresent + [int]$Minor.IsPresent + [int]$Major.IsPresent

if (-not $Version -and $switchCount -eq 0) {
    Write-Error "A version is required. Provide an explicit version (e.g. 1.0.0) or use -Patch, -Minor, or -Major."
    exit 1
}

if ($Version -and $switchCount -gt 0) {
    Write-Error "Specify either an explicit version or a bump switch (-Patch, -Minor, -Major), not both."
    exit 1
}

if ($switchCount -gt 1) {
    Write-Error "Specify only one of -Patch, -Minor, or -Major."
    exit 1
}

if ($Version -and $Version -notmatch '^\d+\.\d+\.\d+(\.(?:dev|alpha|beta|rc|post)\w*)?$') {
    Write-Error "Invalid version '$Version'. Must be semver: MAJOR.MINOR.PATCH with optional pre-release suffix (e.g. 1.0.0, 1.2.3.dev123, 2.0.0.alpha1)."
    exit 1
}

# ── Set / bump version ──────────────────────────────────────────────────────
if ($Version) {
    Write-Host "Setting version: $Version ..." -ForegroundColor Cyan
    uv version $Version
}
else {
    $bump = if ($Patch) { "patch" } elseif ($Minor) { "minor" } else { "major" }
    Write-Host "Bumping version ($bump) ..." -ForegroundColor Cyan
    uv version --bump $bump
}

$version = (uv version --short).Trim()
Write-Host "New version: v$version" -ForegroundColor Green

# ── Commit and push ─────────────────────────────────────────────────────────
Write-Host "Committing and pushing ..." -ForegroundColor Cyan
git add pyproject.toml
git add uv.lock
git commit -m "chore: bump version to $version"
git push

# ── Create GitHub release ────────────────────────────────────────────────────
Write-Host "Creating GitHub release v$version ..." -ForegroundColor Cyan
$ghArgs = @("release", "create", "v$version", "--title", "v$version", "--generate-notes", "-R", "satori-analytics/serena")
if ($version -match '\.(dev|alpha|beta|rc|post)') { $ghArgs += "--prerelease" }
& gh @ghArgs

Write-Host ""
Write-Host "Release v$version created. CI will publish to Cloudsmith." -ForegroundColor Green
Write-Host "Monitor: https://github.com/satori-analytics/serena/actions" -ForegroundColor DarkGray
