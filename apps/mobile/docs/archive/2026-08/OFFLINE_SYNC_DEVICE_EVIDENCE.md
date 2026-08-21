# Offline sync device evidence — re-certification runbook

**Gate:** `sync_offline_conflict` in `release/focused_beta_status.json`  
**Evidence file:** `mobile/evidence/offline_sync_tested.json`  
**Canonical release steps:** [release/DEVICE_EVIDENCE_RUNBOOK.md](../../../release/DEVICE_EVIDENCE_RUNBOOK.md) § C

This is a **physical-device re-certification** task, not a code fix. The gate cannot honestly pass until someone runs the flow on the **current TestFlight build** and commits fresh evidence.

---

## How evidence is generated

Evidence is **not** produced by CI. It is exported from the in-app verification screen:

| Component | Path |
| --- | --- |
| Screen | `Settings → Offline sync verify` (`/offline-sync-verify`) |
| Route | `apps/mobile/lib/features/sync/screens/offline_sync_verification_screen.dart` |
| Journey persistence | `apps/mobile/lib/features/offline_sync/offline_sync_journey_store.dart` |
| JSON export | `apps/mobile/lib/features/offline_sync/offline_sync_production_evidence.dart` |

The screen is **developer-gated**: Settings → About → tap the **version label 7 times** to unlock developer tools, then open **Offline sync verify**.

Build the TestFlight IPA with commit binding so export includes `commit_sha`:

```bash
flutter build ipa \
  --dart-define=VOICE_MEMORY_API_BASE_URL=https://voice-memory-iota.vercel.app \
  --dart-define=SOURCE_COMMIT_SHA=$(git rev-parse HEAD)
```

---

## Device procedure (physical iPhone required)

1. Install **TestFlight build 0.2.0+48** (commit `1eabdc74…`) on a physical iPhone — not Simulator.
2. Unlock developer tools (About → version label ×7).
3. Open **Offline sync verify**.
4. **Start airplane mode** (in-app step — records baseline snapshot).
5. Record **5 eligible** moments on `/record` while offline (non-draft, real captures).
6. **Lock baseline** → force-quit app → reopen → **Verify restart** (counts, timestamps, belief, evidence must match).
7. **Network restored** → sign in if prompted → **Sync**.
8. **Export evidence** — JSON copied to clipboard.
9. Paste into `mobile/evidence/offline_sync_tested.json` and commit.

Required export shape (see `release/evidence/templates/offline_sync_tested.template.json`):

```json
{
  "success": true,
  "belief_preserved": true,
  "evidence_preserved": true,
  "reflections_recorded_offline": 5,
  "reflections_synced": 5,
  "timestamp": "2026-08-13T…",
  "platform": "ios",
  "device": "iPhone16,2",
  "marketing_version": "0.2.0",
  "build_number": 48,
  "commit_sha": "1eabdc74cd255548af59e626a75f93f3731ea385"
}
```

---

## Two validators — both must pass

| Command | What it checks |
| --- | --- |
| `npm run validate:offline-sync-production` | Structural evidence: booleans, counts match, physical device, timestamp present |
| `npm run release:apply-device-evidence -- --ios-only` | **Release binding:** `build_number` and `commit_sha` must match `release/focused_beta_status.json` identity |

**Important:** Structural validation can pass while the release gate still fails if evidence is stale or missing `build_number` / `commit_sha`. Current committed evidence (2026-08-11) is in that state.

After updating the JSON:

```bash
npm run validate:offline-sync-production
npm run release:apply-device-evidence -- --ios-only
npm run release:verify-focused-beta
```

Shortcut guide: `npm run release:device-evidence-guide`

---

## Re-certification required for 0.2.0+48 @ 1eabdc74

**Current evidence** (`mobile/evidence/offline_sync_tested.json`):

- `timestamp`: **2026-08-11** — predates current build/commit
- `reflections_recorded_offline`: **1** — below the screen’s required **5**
- **Missing** `build_number` and `commit_sha` — release gate fails binding checks

Treat as **invalid for this release** until re-run on build 48.

### Sync-related commits since last evidence (2026-08-11)

| Date | Commit | Area | Impact |
| --- | --- | --- | --- |
| 2026-08-12 | `e61c5e17` | `sync_notifier.dart` | New sync boundary + release-safe logging on sync path used by `/offline-sync-verify` |
| 2026-08-12 | `61b1437f` | `mobile_prefs_store.dart` | Encrypted prefs migration — `OfflineSyncJourneyStore` persists journey via this store |

No commits to `offline_sync_verification_screen.dart` or `offline_sync_journey_store.dart` since 2026-08-11, but **dependencies changed** — re-certification is **higher priority** than a pure timestamp refresh.

`apps/mobile/lib/sync/sync_engine.dart` exists locally as **untracked WIP** and is **not** part of commit `1eabdc74`. The shipped sync path at HEAD uses `SyncNotifier` → `SyncRepository`, not `SyncEngine`.

---

## Gate honesty rule

Never set `success: true` without completing the full physical flow on the current TestFlight build. The manifest gate `sync_offline_conflict` must record matching `commitSha`, `buildNumber`, and a fresh `recordedAt` after evidence is committed.
