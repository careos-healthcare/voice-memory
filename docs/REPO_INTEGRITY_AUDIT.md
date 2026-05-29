# Repository integrity and workspace isolation audit

**Audit date:** 2026-05-25  
**Mode:** Read-only (no commits, no destructive actions)  
**Auditor context:** Commands run from both the Cursor workspace root and the VoiceMemory git root.

---

## Executive summary

| Check | Result |
| --- | --- |
| VoiceMemory production source repo | **Clean** — `~/Desktop/voice-memory` → `careos-healthcare/voice-memory` |
| Flutter repo contamination of VoiceMemory | **None detected** in source, imports, or tracked files |
| VoiceMemory contamination of Flutter | **None detected** in `lib/`, `pubspec.yaml`, or Next.js artifacts |
| Cursor workspace vs active git repo | **Mismatch** — workspace is Flutter; VoiceMemory work is on disk outside the workspace |
| Vercel linkage | **Correct** — local `.vercel/project.json` → project `voice-memory` → `voice-memory-iota.vercel.app` |
| Cross-project reference scan | **No matches** for `TextRecognitionAppFlutter`, `AndroidStudioProjects`, `package:flutter`, or cross-repo relative imports in VoiceMemory |
| Nested `.git` inside VoiceMemory | **None** — single root `.git` only |

**Primary risk:** Operational — editing and deploying VoiceMemory while Cursor is opened on `TextRecognitionAppFlutter` causes wrong-repo searches, terminal cwd confusion, and agent context stored under the Flutter Cursor project path. This does **not** imply Flutter files are being deployed to Vercel.

---

## 1. Environment snapshot (commands run)

### VoiceMemory (`~/Desktop/voice-memory`)

| Field | Value |
| --- | --- |
| **Current working directory (audit shell)** | `/Users/chiragpatel/Desktop/voice-memory` |
| **Git root** | `/Users/chiragpatel/Desktop/voice-memory` |
| **Remote** | `https://github.com/careos-healthcare/voice-memory.git` |
| **Branch** | `main` |
| **Latest commit** | `10a22f6` — *Add first-week emotional retention engine* |
| **HEAD SHA** | `10a22f6e55219c1db29d06893047ffe7818d58f3` |
| **Modified / untracked (working tree)** | **26** lines in `git status --short` (mix of modified + untracked; see §7) |

### Cursor workspace (`TextRecognitionAppFlutter`)

| Field | Value |
| --- | --- |
| **Workspace path (Cursor)** | `/Users/chiragpatel/AndroidStudioProjects/TextRecognitionAppFlutter` |
| **Git root** | Same as workspace (not nested) |
| **Remote** | `https://github.com/careos-healthcare/app15_full.git` |
| **Branch** | `main` |
| **Latest commit** | `dc84e34` — *core shift: enforced daily habit…* |
| **Modified / untracked** | **341** status lines (**41** untracked `??`) — large in-progress CareOS Flutter tree; unrelated to VoiceMemory deploy |

### `git remote -v` (both)

```text
# voice-memory
origin  https://github.com/careos-healthcare/voice-memory.git (fetch/push)

# TextRecognitionAppFlutter
origin  https://github.com/careos-healthcare/app15_full.git (fetch/push)
```

### `find .. -name ".git" -type d` (maxdepth 4, relevant hits)

```text
/Users/chiragpatel/Desktop/voice-memory/.git
/Users/chiragpatel/AndroidStudioProjects/TextRecognitionAppFlutter/.git
/Users/chiragpatel/Desktop/spp20/youtube-timestamp-search/.git
/Users/chiragpatel/Desktop/app36_full/.git
/Users/chiragpatel/Desktop/app36_full/TextRecognitionApp/.git   # nested repo on Desktop
/Users/chiragpatel/Desktop/moment-search/.git
```

No `.git` inside `voice-memory` subdirectories. No `voice-memory` folder inside the Flutter repo.

---

## 2. Workspace root mismatch (Cursor)

| Item | VoiceMemory truth | Cursor default |
| --- | --- | --- |
| Opened workspace | Should be `~/Desktop/voice-memory` for VM work | `~/AndroidStudioProjects/TextRecognitionAppFlutter` |
| `package.json` name | `voice-memory` | `careos-firestore-rules-tests` (root); Flutter `text_recognition_app_flutter` in `pubspec.yaml` |
| App framework | Next.js 16 (`next.config.ts`, `app/`) | Flutter + Firebase rules helper `package.json` |
| Ripgrep from Cursor | Scoped to Flutter workspace — **misses** `~/Desktop/voice-memory` unless absolute paths are used | |

**Impact:** Agents and IDE search can report “no matches” for VoiceMemory paths, run `npm run build` in the wrong tree, or attach terminals under `.../TextRecognitionAppFlutter/terminals` while editing Desktop files.

**Accidental shared state:** Cursor agent transcripts for VoiceMemory sessions are stored under:

`~/.cursor/projects/Users-chiragpatel-AndroidStudioProjects-TextRecognitionAppFlutter/`

That is metadata only — not deployed — but it blurs project boundaries in chat history.

---

## 3. Contamination scan results

### 3.1 TextRecognitionAppFlutter / Flutter references in VoiceMemory

Shell grep over `~/Desktop/voice-memory` (excluding `node_modules`, `.next`):

- `TextRecognitionAppFlutter` — **none**
- `AndroidStudioProjects` — **none**
- `app15_full` — **none**
- `package:flutter` — **none**
- `*.dart` files under VoiceMemory — **none**
- `../../AndroidStudio` or `../../TextRecognition` imports — **none**

### 3.2 VoiceMemory references in Flutter repo

Grep over `lib/` and `docs/` in TextRecognitionAppFlutter:

- `voice-memory`, `VoiceMemory`, `voicememory.app` — **none** in Dart/docs sample paths

### 3.3 Duplicate / nested repositories

| Location | Risk |
| --- | --- |
| `Desktop/voice-memory/.git` | Canonical VoiceMemory repo |
| `TextRecognitionAppFlutter/.git` | Separate product (CareOS) |
| `Desktop/app36_full/.git` + nested `TextRecognitionApp/.git` | Unrelated nested Desktop repos — do not merge with VoiceMemory |
| `Desktop/spp20/youtube-timestamp-search/.git` | Separate Vercel Next project |

**Conclusion:** No nested git inside VoiceMemory; no monorepo coupling between Flutter and VoiceMemory.

### 3.4 Incorrect package names

| Repo | Declared name | Expected |
| --- | --- | --- |
| `voice-memory/package.json` | `"name": "voice-memory"` | Correct |
| Flutter `pubspec.yaml` | `text_recognition_app_flutter` | Correct for CareOS app |
| Flutter root `package.json` | `careos-firestore-rules-tests` | Firestore rules tests only — not VoiceMemory |

---

## 4. Deploy and toolchain verification

### 4.1 Next.js app root

- **Root:** `/Users/chiragpatel/Desktop/voice-memory`
- **Router:** `app/` (App Router)
- **Config:** `next.config.ts`, `tsconfig.json` paths `@/*` → `./*` (repo-local only)
- **No** `pubspec.yaml`, **no** `android/`, **no** `lib/*.dart` in VoiceMemory tree

### 4.2 Vercel project linkage

**File:** `.vercel/project.json` (gitignored; present locally)

```json
{
  "projectId": "prj_tr17titHfpvGp9ilMERtdi0gTuGt",
  "orgId": "team_4OqWdMbs2Eehj7ox4ARCw1bQ",
  "projectName": "voice-memory"
}
```

**CLI (`vercel project ls`):** Production URL `https://voice-memory-iota.vercel.app` — project name `voice-memory`, Node 24.x.

**CLI (`vercel inspect voice-memory-iota.vercel.app`):**

- Deployment id: `dpl_3NcUxEkm2BuuwycWHrzEGuUdwqVp`
- Status: Ready (production)
- Aliases include `voice-memory-iota.vercel.app`
- Build output: Next.js serverless routes (`λ` entries) — consistent with this repo, not Flutter

**Deployment source (inferred):** GitHub `careos-healthcare/voice-memory` when connected in Vercel dashboard; local CLI link points at `~/Desktop/voice-memory`. **Not** `app15_full` / TextRecognitionAppFlutter.

### 4.3 Workspace / editor settings

| Path | Present |
| --- | --- |
| `voice-memory/.vscode/` | No |
| `voice-memory/.cursor/` | No |
| `TextRecognitionAppFlutter/.cursor/rules/` | Yes — Firestore multi-tenant rules (CareOS only) |

VoiceMemory does not inherit Flutter `.cursor/rules` from disk; Cursor only applies rules for the **opened** workspace folder.

---

## 5. Contamination and orphan risks

### 5.1 VoiceMemory working tree (non-deploy blockers, hygiene)

**Modified (tracked) — sample from audit:**

- `app/api/debug/auth-env/route.ts`
- `lib/server/env-check.ts`
- `docs/RESEND_DOMAIN_AUTH.md`
- `lib/product-copy.ts`, onboarding/retention-related app and lib files
- `package.json`, validators

**Untracked (orphaned until committed or ignored):**

- `app/internal/onboarding-clarity/`
- `components/onboarding/`, `lib/onboarding/`
- `scripts/verify-production-auth-email.sh`
- `scripts/validate-onboarding-restraint.mjs`
- `types/onboarding-clarity.ts`
- related debug panels

These are **in-repo feature WIP**, not Flutter contamination. They affect reproducibility of deploys only if you expect a clean `main` on Vercel without pushing.

**Previously noted:** Weekly support files (`lib/weekly-intelligence.ts`, etc.) are now **tracked** on current `main` (post-audit log).

### 5.2 Flutter workspace orphan (accidental local file)

Untracked file from a mistaken terminal/session name:

```text
lib/core/risk/# This will start a new terminal session
```

This is **CareOS Flutter debris**, not VoiceMemory. It should not be committed to `app15_full`.

### 5.3 Accidental shared state (not in git)

| Artifact | Location | Risk |
| --- | --- | --- |
| Cursor terminals | `~/.cursor/projects/...TextRecognitionAppFlutter/terminals/` | cwd may be wrong project |
| Agent transcripts | Same Cursor project id | History mixes VM + Flutter + youtube-timestamp-search threads |
| `.env*.local` / `.vercel` | Gitignored per repo | Safe if not copied across projects |
| `voice-memory/.next/` | Build cache | Local only; not deployed via git |

---

## 6. Confirmed deployment source chain

```text
Developer machine:  ~/Desktop/voice-memory
        │
        ├─ git → github.com/careos-healthcare/voice-memory (main)
        │
        └─ vercel link → projectId prj_tr17titHfpvGp9ilMERtdi0gTuGt (voice-memory)
                │
                └─ Production → https://voice-memory-iota.vercel.app
```

**Not in chain:** `TextRecognitionAppFlutter`, `app15_full`, Flutter build outputs, or CareOS Firestore rules package.

---

## 7. Recommended cleanup (commands only — do not run blindly)

### 7.1 Open the correct Cursor workspace (recommended)

```bash
cursor ~/Desktop/voice-memory
# or: File → Open Folder → ~/Desktop/voice-memory
```

### 7.2 Remove Flutter accidental orphan file

Review first:

```bash
ls -la "/Users/chiragpatel/AndroidStudioProjects/TextRecognitionAppFlutter/lib/core/risk/# This will start a new terminal session"
```

If it is empty or junk:

```bash
rm "/Users/chiragpatel/AndroidStudioProjects/TextRecognitionAppFlutter/lib/core/risk/# This will start a new terminal session"
```

### 7.3 VoiceMemory — reconcile WIP (choose one strategy)

**Option A — commit on `main` in voice-memory repo:**

```bash
cd ~/Desktop/voice-memory
git status
git add -p   # stage intentionally
git commit -m "Your message"
git push origin main
```

**Option B — stash for later:**

```bash
cd ~/Desktop/voice-memory
git stash push -u -m "WIP onboarding and auth-env"
```

**Option C — discard local changes (destructive):**

```bash
cd ~/Desktop/voice-memory
git checkout -- .
git clean -fd   # removes untracked files — irreversible
```

### 7.4 Verify Vercel deploy origin (dashboard)

In Vercel → **voice-memory** → Settings → Git:

- Repository should be `careos-healthcare/voice-memory`
- Production branch `main`
- Root directory empty (or `.`), framework Next.js

### 7.5 Post-switch verification script

```bash
cd ~/Desktop/voice-memory
pwd
git remote -v
git rev-parse --show-toplevel
npm run build
./scripts/verify-production-auth-email.sh   # if present and chmod +x
```

---

## 8. Audit checklist (for re-runs)

```bash
# 1. Identity
pwd
git rev-parse --show-toplevel
git remote -v
git branch --show-current
git log -1 --oneline
git status --short

# 2. Nested repos
find "$(git rev-parse --show-toplevel)" -name ".git" -type d

# 3. Cross-project grep (VoiceMemory)
grep -r 'TextRecognitionAppFlutter\|AndroidStudioProjects\|package:flutter' . \
  --include='*.ts' --include='*.tsx' --exclude-dir=node_modules --exclude-dir=.next

# 4. Vercel
cat .vercel/project.json
npx vercel inspect voice-memory-iota.vercel.app

# 5. Package identity
node -p "require('./package.json').name"
```

---

## 9. Sign-off

- **Confirmed repo root for VoiceMemory:** `/Users/chiragpatel/Desktop/voice-memory`
- **Confirmed production deploy project:** Vercel `voice-memory` (`voice-memory-iota.vercel.app`)
- **Contamination from TextRecognitionAppFlutter:** **Not found** in VoiceMemory source or Vercel linkage
- **Workspace isolation issue:** **Yes** — Cursor opened on Flutter while VoiceMemory lives on Desktop; fix by switching workspace
- **Commit:** None (per audit instructions)
