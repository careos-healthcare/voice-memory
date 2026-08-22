# Device evidence runbook — TestFlight + offline sync

Machine gate source: `release/focused_beta_status.json`  
Preflight: `npm run release:device-evidence-guide`

---

## A. Preflight (Mac — before upload)

From repository root:

```bash
npm run release:verify-focused-beta
npm run release:preflight-ios
```

`release:preflight-ios` runs the focused release suite and produces a release iOS build with `SOURCE_COMMIT_SHA` embedded for device evidence export.

Fix any blocking gates that are tool-verifiable before uploading.

---

## B. TestFlight upload (Mac + Xcode)

**Screen-by-screen:** [XCODE_TESTFLIGHT_UPLOAD.md](./XCODE_TESTFLIGHT_UPLOAD.md)

### 1. Identity check

| Field | Source |
| --- | --- |
| Version | `apps/mobile/pubspec.yaml` → `0.2.0+48` |
| Manifest | `release/focused_beta_status.json` |
| Bundle ID | `com.voicememory.mobile` |

Increment `+N` in `pubspec.yaml` before each App Store Connect upload if Apple rejects duplicate build numbers.

### 2. Build with commit binding (recommended)

```bash
cd apps/mobile
export SOURCE_COMMIT_SHA="$(git -C ../.. rev-parse HEAD)"
flutter build ipa \
  --dart-define=VOICE_MEMORY_API_BASE_URL=https://voice-memory-iota.vercel.app \
  --dart-define=SOURCE_COMMIT_SHA="$SOURCE_COMMIT_SHA"
```

Or archive via Xcode after:

```bash
flutter build ios --release \
  --dart-define=VOICE_MEMORY_API_BASE_URL=https://voice-memory-iota.vercel.app \
  --dart-define=SOURCE_COMMIT_SHA="$SOURCE_COMMIT_SHA"
```

Do **not** pass `ARCHIVEME_TRIAL_MODE=true` or `VOICE_MEMORY_SCREENSHOT_MODE=true`.

### 3. Xcode archive + upload

1. Open `apps/mobile/ios/Runner.xcworkspace` (not `.xcodeproj`).
2. Runner target → Signing & Capabilities → correct team, bundle ID `com.voicememory.mobile`.
3. Product → Archive (Release, Any iOS Device).
4. Window → Organizer → Distribute App → App Store Connect → Upload.
5. Wait for processing → TestFlight → add **internal** testers.

### 4. TestFlight smoke on physical iPhone

Use `apps/mobile/docs/TESTFLIGHT_MANUAL_QA.md` (reviewer demo path in `APP_STORE_SUBMISSION_PACK.md`).

Minimum smoke before updating evidence:

- [ ] Fresh install from TestFlight
- [ ] Typed moment saves
- [ ] Voice moment saves (or Type instead if skipping mic)
- [ ] Archive Home loads
- [ ] Sample Archive — example data only
- [ ] Pro preview — no live purchase claim
- [ ] Restore purchases — honest unavailable copy

### 5. Commit TestFlight evidence

After smoke on the **same build** you uploaded, edit `mobile/evidence/testflight_tested.json`.

While `livePurchases=false` in the manifest, set `purchase_completed` and `restore_completed` to `false` but keep smoke booleans `true`:

```json
{
  "success": true,
  "build_uploaded": true,
  "build_installed": true,
  "onboarding_completed": true,
  "record_completed": true,
  "archive_viewed": true,
  "purchase_completed": false,
  "restore_completed": false,
  "timestamp": "2026-08-12T20:00:00.000Z",
  "marketing_version": "0.2.0",
  "build_number": 48,
  "platform": "ios",
  "device": "iPhone16,2"
}
```

When billing goes live, set `purchase_completed` / `restore_completed` to `true` and re-run validators.

Also update signing evidence when archive upload succeeds:

`mobile/evidence/ios_signing_tested.json`:

```json
{
  "success": true,
  "archive_build_created": true,
  "uploaded_to_app_store_connect": true,
  "timestamp": "2026-08-12T20:00:00.000Z",
  "marketing_version": "0.2.0",
  "build_number": 48
}
```

Validate:

```bash
npm run validate:testflight-proof
npm run validate:ios-signing
```

Update `release/focused_beta_status.json` gate rows (`testflight_internal_smoke`, `ios_android_build_signing`) to `pass` with matching `commitSha`, `buildNumber`, and `recordedAt`.

---

## C. Offline sync re-verification (physical iPhone)

Required when `sync` capability is enabled in the manifest.

### 1. Unlock verification routes on TestFlight build

1. Install the TestFlight build on a **physical iPhone** (not Simulator).
2. Settings → **About** → tap the **version label 7 times** until developer tools unlock.
3. Settings → **Offline sync verify** (appears after unlock).

### 2. Run the flow

On **Offline sync verify** (`/offline-sync-verify`):

1. Enable **Airplane mode**.
2. Record **5 eligible** reflections (non-draft, real moments).
3. **Lock baseline** → force-quit app → reopen → confirm local archive intact.
4. Disable Airplane mode → sign in if prompted → **Sync**.
5. Tap **Export evidence** → JSON copied to clipboard.

Export includes `build_number` and `commit_sha` (when built with `SOURCE_COMMIT_SHA`).

### 3. Commit evidence

Save clipboard to `mobile/evidence/offline_sync_tested.json`. Example:

```json
{
  "success": true,
  "belief_preserved": true,
  "evidence_preserved": true,
  "reflections_recorded_offline": 5,
  "reflections_synced": 5,
  "timestamp": "2026-08-12T20:30:00.000Z",
  "platform": "ios",
  "device": "iPhone16,2",
  "marketing_version": "0.2.0",
  "build_number": 48,
  "commit_sha": "1eabdc74cd255548af59e626a75f93f3731ea385"
}
```

Validate:

```bash
npm run validate:offline-sync-production
```

Update manifest gate `sync_offline_conflict` → `pass` with the same `commitSha`, `buildNumber`, and fresh `recordedAt`.

### 4. Re-run release verification

```bash
npm run validate:testflight-proof
npm run validate:ios-signing
npm run validate:offline-sync-production
npm run release:apply-device-evidence -- --ios-only
npm run release:verify-focused-beta
```

`release:apply-device-evidence` runs validators and updates gate rows in `release/focused_beta_status.json`. Use `--dry-run` to preview. Add `--voiceover-pass` after completing `ACCESSIBILITY_MANUAL_CHECKLIST.md`.

---

## D. VoiceOver manual gate (optional but required for release)

Follow `apps/mobile/docs/ACCESSIBILITY_MANUAL_CHECKLIST.md` on the TestFlight build. Record sign-off in the manifest gate `voiceover_talkback_manual` (status `pass`, evidence path to QA notes or checklist export).

---

## E. Manifest update checklist

After each device session, update **only** the gates you actually proved:

| Gate | Evidence file |
| --- | --- |
| `ios_android_build_signing` | `mobile/evidence/ios_signing_tested.json` |
| `testflight_internal_smoke` | `mobile/evidence/testflight_tested.json` |
| `sync_offline_conflict` | `mobile/evidence/offline_sync_tested.json` |
| `purchase_restore` | `mobile/evidence/testflight_tested.json` + `revenuecat_store_tested.json` |
| `voiceover_talkback_manual` | QA notes (manual) |

Never set `success: true` without running the physical flow on the current build.
