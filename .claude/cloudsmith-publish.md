# Serena — Cloudsmith Publishing Guide

This documents how to publish `satori-serena` to the public Cloudsmith `oss-tools` repository.

---

## Overview

The `publish.yml` workflow triggers on GitHub Release creation. It builds a wheel with `uv` and publishes to Cloudsmith. The package is publicly readable — only publishing requires authentication.

---

## One-Time Setup

### 1. Cloudsmith repository

The Cloudsmith repo `oss-tools` under `satorianalytics` must exist with **Public** visibility.

### 2. GitHub secret

Add to the Serena fork: **Settings** → **Secrets and variables** → **Actions** → **New repository secret**:

- **Name:** `SATORI_CLOUDSMITH_PUBLISH_KEY`
- **Value:** Cloudsmith API key with push rights to `satorianalytics/oss-tools`

### 3. pyproject.toml index config

```toml
[[tool.uv.index]]
name        = "cloudsmith"
url         = "https://dl.cloudsmith.io/public/satorianalytics/oss-tools/python/simple/"
publish-url = "https://python.cloudsmith.io/satorianalytics/oss-tools/"
explicit    = true
```

---

## Publish Workflow

File: `.github/workflows/publish.yml`

```yaml
name: Publish to Cloudsmith

on:
  release:
    types: [published]

jobs:
  publish:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    env:
      UV_PUBLISH_USERNAME: token
      UV_PUBLISH_PASSWORD: ${{ secrets.SATORI_CLOUDSMITH_PUBLISH_KEY }}
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Install uv
        uses: astral-sh/setup-uv@v6

      - name: Assert tag matches pyproject.toml version
        run: |
          TAG="${{ github.event.release.tag_name }}"
          PKG="v$(uv version --short)"
          if [[ "$TAG" != "$PKG" ]]; then
            echo "ERROR: Release tag '$TAG' does not match pyproject.toml version '$PKG'"
            exit 1
          fi
          echo "Version check passed: $TAG"

      - name: Build wheel
        run: uv build --wheel --out-dir dist/

      - name: Publish to Cloudsmith
        run: uv publish --index cloudsmith dist/*
```

> **`UV_PUBLISH_USERNAME=token`** — Cloudsmith's HTTP Basic Auth convention. The literal string `token`
> is the username; your API key is the password.

> **Version consistency check** — fails fast if `pyproject.toml` version doesn't match the release tag,
> preventing mismatched versions from reaching Cloudsmith.

---

## Releasing a New Version

### Using `Publish-Package.ps1` (recommended)

The `Publish-Package.ps1` script in the repo root automates the full sequence:

```powershell
.\Publish-Package.ps1                  # Dev release    (0.1.4 → 0.1.5.dev1742000000)
.\Publish-Package.ps1 -Bump patch      # Patch release  (0.1.4 → 0.1.5)
.\Publish-Package.ps1 -Bump minor      # Minor release  (0.1.4 → 0.2.0)
.\Publish-Package.ps1 -Bump major      # Major release  (0.1.4 → 1.0.0)
.\Publish-Package.ps1 -Bump dev        # Dev release    (0.1.4 → 0.1.5.dev1742000000)
```

The default is `dev`. Dev releases bump patch and append a Unix timestamp suffix (e.g. `0.1.4 → 0.1.5.dev1742000000`), and are marked as pre-releases on GitHub.

The script:
1. Reads the current version from `pyproject.toml` via `uv version --short`
2. Bumps version in `pyproject.toml` via `uv version --bump`
3. Commits the change
4. Pushes to origin
5. Creates a GitHub release with `gh release create -R satori-analytics/serena` (pre-release flag set for dev)

CI then picks up the release event and publishes to Cloudsmith automatically.

### Manual release (step-by-step)

```bash
uv version --bump patch
git add pyproject.toml
git commit -m "chore: bump version to $(uv version --short)"
git push
gh release create "v$(uv version --short)" \
  --title "v$(uv version --short)" \
  --generate-notes \
  -R satori-analytics/serena
```

---

## Verification

After a release, check:

1. **CI:** `github.com/satori-analytics/serena/actions` — publish job should succeed
2. **Cloudsmith:** `cloudsmith.io/~satorianalytics/repos/oss-tools/packages/` — new version should appear
3. **Install:** `uvx --from satori-serena --index https://dl.cloudsmith.io/public/satorianalytics/oss-tools/python/simple/ serena --version` — should show new version

---

## Reference

| Item | Value |
|------|-------|
| Package name | `satori-serena` |
| Package manager | uv |
| Cloudsmith org | `satorianalytics` |
| Cloudsmith repo | `oss-tools` |
| Cloudsmith visibility | **Public** (read without auth) |
| Index URL (read) | `https://dl.cloudsmith.io/public/satorianalytics/oss-tools/python/simple/` |
| Publish URL (upload) | `https://python.cloudsmith.io/satorianalytics/oss-tools/` |
| GitHub secret | `SATORI_CLOUDSMITH_PUBLISH_KEY` |
| Workflow file | `.github/workflows/publish.yml` |
| Release script | `Publish-Package.ps1` |
| Python version (CI) | `3.11` |
| setup-uv action | `astral-sh/setup-uv@v6` |
