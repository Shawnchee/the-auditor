# How to Update Release Tags 🏷️

This guide explains how to properly manage versioning for **PR Auditor**. Following this process ensures that users can depend on stable versions (e.g., `v1`) while you continue to develop on `main`.

---

## 1. Tagging Strategy

We use Semantic Versioning (SemVer) with **floating major version tags**.
- **`v1.0.0`**: Specific immutable release.
- **`v1`**: Floating tag that always points to the latest stable `v1.x.x` release.

Users are encouraged to use `uses: Shawnchee/the-auditor@v1` so they get non-breaking updates automatically.

---

## 2. Step-by-Step Release Process

When you have changes on `main` that are ready for release:

### Step A: Update the Changelog
1. Open `CHANGELOG.md`.
2. Add a new version header (e.g., `## [1.1.0] - 2026-03-01`).
3. Summarize the changes under `Added`, `Fixed`, or `Changed`.

### Step B: Create and Push the New Version Tag
Replace `v1.1.0` with your actual next version:

```bash
# Ensure you are on main and up to date
git checkout main
git pull origin main

# Create the specific version tag
git tag -a v1.1.0 -m "Release v1.1.0: Description of changes"

# Push the tag to GitHub
git push origin v1.1.0
```

### Step C: Update the Floating Major Tag
To ensure users on `@v1` get the update, you must move the floating tag to the same commit as your new release:

```bash
# Force the 'v1' tag to the current commit
git tag -fa v1 -m "Update v1 floating tag to v1.1.0"

# Force push the updated floating tag
git push origin v1 --force
```

---

## 3. Automation (Recommended)

To automate this, you can create a Release in the GitHub UI:
1. Go to **Releases** → **Draft a new release**.
2. Create a new tag (e.g., `v1.1.0`).
3. Title it `v1.1.0` and paste your `CHANGELOG.md` notes.
4. Click **Publish release**.
5. **CRITICAL**: You still need to manually run the "Update Floating Tag" commands above, or add a GitHub Action to do it automatically.

---

## 4. GitHub Action for Auto-Tagging (Optional)

You can add this to a new file `.github/workflows/release.yml` to automate moving the `v1` tag whenever a new `v1.x.x` tag is pushed:

```yaml
name: Update Floating Tag

on:
  push:
    tags:
      - 'v1.*.*'

jobs:
  update-v1:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Update v1 tag
        run: |
          git config user.name "github-actions"
          git config user.email "github-actions@github.com"
          git tag -fa v1 -m "Update v1 floating tag"
          git push origin v1 --force
```
