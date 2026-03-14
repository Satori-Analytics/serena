<#
.SYNOPSIS
    Bumps version, commits, and creates a GitHub release for satori-serena.

.DESCRIPTION
    Automates the release process: bumps the version in pyproject.toml using uv,
    commits the change, pushes, and creates a GitHub release that triggers the
    Cloudsmith publish workflow.

.PARAMETER Bump
    Version bump type: dev (default), patch, minor, or major.
    Dev bumps patch and appends a Unix timestamp pre-release segment (e.g. 0.1.4 → 0.1.5.dev1742000000).

.EXAMPLE
    .\Publish-Package.ps1                  # Dev release    (0.1.4 → 0.1.5.dev1742000000)
    .\Publish-Package.ps1 -Bump patch      # Patch release  (0.1.4 → 0.1.5)
    .\Publish-Package.ps1 -Bump minor      # Minor release  (0.1.4 → 0.2.0)
    .\Publish-Package.ps1 -Bump major      # Major release  (0.1.4 → 1.0.0)
#>
[CmdletBinding()]
param(
    [ValidateSet("patch", "minor", "major", "dev")]
    [string]$Bump = "dev"
)

$ErrorActionPreference = "Stop"

# ── Bump version ─────────────────────────────────────────────────────────────
$version = (uv version --short).Trim()

if ($Bump -eq "dev") {
    $devDate = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    # If already on a dev version, reuse the same base (don't re-bump patch)
    $base = $version -replace '\.dev\d+$', ''
    if ($base -eq $version) {
        # Stable version — bump patch first to get the new base
        uv version --bump patch
        $base = (uv version --short).Trim()
    }
    $devVersion = "$base.dev$devDate"
    Write-Host "Setting dev version: $devVersion ..." -ForegroundColor Cyan
    uv version $devVersion
}
else {
    Write-Host "Bumping version ($Bump) ..." -ForegroundColor Cyan
    uv version --bump $Bump
}

$version = (uv version --short).Trim()
Write-Host "New version: v$version" -ForegroundColor Green

# ── Commit and push ──────────────────────────────────────────────────────────
Write-Host "Committing and pushing ..." -ForegroundColor Cyan
git add pyproject.toml
git add uv.lock
git commit -m "chore: bump version to $version"
git push

# ── Create GitHub release ────────────────────────────────────────────────────
Write-Host "Creating GitHub release v$version ..." -ForegroundColor Cyan
$ghArgs = @("release", "create", "v$version", "--title", "v$version", "--generate-notes", "-R", "satori-analytics/serena")
if ($Bump -eq "dev") { $ghArgs += "--prerelease" }
& gh @ghArgs

Write-Host ""
Write-Host "Release v$version created. CI will publish to Cloudsmith." -ForegroundColor Green
Write-Host "Monitor: https://github.com/satori-analytics/serena/actions" -ForegroundColor DarkGray
