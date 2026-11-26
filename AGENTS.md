# AGENTS.md — Repository & Push Standard (All Agents)

These rules are mandatory for **every AI coding agent** (Antigravity, Claude Code / Orca workers, Codex, Cursor, etc.) operating in `my-better-life`.

---

## 1. Open-Core Architecture & Strict Dual-Repo Boundary

This workspace uses a two-remote Open-Core setup:

| Local Branch | Remote / Branch | GitHub Repository | Visibility | Scope |
| :--- | :--- | :--- | :--- | :--- |
| `main` | `origin/main` | `igordonatti/my-better-life` | **PUBLIC (MIT)** | Native macOS/iOS app (`App/`, `Sources/`, `Tests/`), `web/` landing & docs, `.github/workflows/release.yml` |
| `cloud-main` | `cloud/main` | `igordonatti/my-better-life-cloud` | **PRIVATE** | Proprietary Go/PostgreSQL backend (`backend/`), internal `docs/`, `SyncEngine`, `SyncSettingsSheet`, cloud/MCP/Google add-ons |

### Non-Negotiable Safety Rules
1. **Never merge, rebase, or cherry-pick `cloud-main` directly into `main`** if the commit contains `backend/`, internal `docs/`, `SyncEngine`, `SyncSettingsSheet`, credentials, or private endpoints.
2. **Never push `cloud-main` to `origin` (`igordonatti/my-better-life`).**
3. Before every commit/push to `main` (`origin/main`), verify no private paths or secrets exist in the staged tree:
   ```bash
   ! git status --porcelain | grep -qE "backend/|docs/|SyncEngine|SyncSettingsSheet|\.env"
   ```

---

## 2. Standard Push Workflow (`main` → Production)

Whenever the user asks to push work to `main` ("subir para a main", "fazer push", "publicar"):

### Step 1 — Pre-Push Verification (Mandatory)
Run all relevant checks **before** committing or pushing:
- **If Swift/App files (`App/`, `Sources/`, `Tests/`, `Package.swift`) changed:**
  ```bash
  make test
  ```
- **If Web files (`web/`) changed:**
  ```bash
  (cd web && npm run build) && rm -f web/tsconfig.tsbuildinfo
  ```
All tests and builds **must pass with zero errors** before committing.

### Step 2 — Clean Commit & Push to `origin/main`
1. Confirm you are on branch `main` tracking `origin/main` (`git branch -vv`).
2. Stage, double-check `git status -s` (ensure no temporary build artifacts like `web/tsconfig.tsbuildinfo`, `web/.env.local`, or `web/.gitignore` are staged), commit with a Conventional Commit message (`feat:`, `fix:`, `chore:`, `docs:`), and push explicitly:
   ```bash
   git push origin main:main
   ```

### Step 3 — Automatic Vercel Production Deploy (When `web/` Changed)
Whenever a push to `main` includes changes inside `web/` (landing page, docs, components, copy, or Next.js config):
1. Deploy `web/` to Vercel production non-interactively:
   ```bash
   cd web && CI=1 vercel --prod --yes --no-color && rm -f .gitignore .env.local && cd ..
   ```
2. Verify the live site responds with `HTTP/2 200` and the working tree remains clean:
   ```bash
   curl -sS -I https://my-better-life.vercel.app | head -n 5 && git status -s
   ```

### Step 4 — macOS `.dmg` Releases & In-App Update Badge (Only When Requested)
Pushing to `origin/main` updates source code (and Vercel if `web/` changed) **without** triggering a new macOS app update badge.
Only cut and push a SemVer tag (`vX.Y.Z`) when the user explicitly wants to publish a new downloadable app version:
1. Bump version in `App/Info.plist`, `project.yml`, `MyBetterLife.xcodeproj/project.pbxproj`, and `Makefile` (`VERSION`).
2. Commit & push `origin main:main`, then tag and push:
   ```bash
   git tag -a vX.Y.Z -m "My Better Life vX.Y.Z"
   git push origin vX.Y.Z
   ```
3. Watch `.github/workflows/release.yml` to completion (`gh run watch --exit-status`) and confirm `MyBetterLife-vX.Y.Z-macOS.dmg` and `SHA256SUMS.txt` are uploaded to the GitHub Release (which automatically activates the in-app update badge above the user profile card).
