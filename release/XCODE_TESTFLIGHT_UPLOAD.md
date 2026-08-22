# Xcode archive & TestFlight upload — screen walkthrough

ArchiveMe **0.2.0+48** · bundle ID `com.voicememory.mobile`  
After upload, run [`DEVICE_EVIDENCE_RUNBOOK.md`](./DEVICE_EVIDENCE_RUNBOOK.md) and `npm run release:apply-device-evidence`.

---

## Before Xcode

From repo root:

```bash
npm run release:preflight-ios
cd apps/mobile
export SOURCE_COMMIT_SHA="$(git -C ../.. rev-parse HEAD)"
flutter build ios --release \
  --dart-define=VOICE_MEMORY_API_BASE_URL=https://voice-memory-iota.vercel.app \
  --dart-define=SOURCE_COMMIT_SHA="$SOURCE_COMMIT_SHA"
```

This produces `build/ios/iphoneos/Runner.app` and runs `pod install` if needed.

---

## 1. Open the workspace

```bash
open ios/Runner.xcworkspace
```

**Always** `.xcworkspace`, never `Runner.xcodeproj`.

---

## 2. Select the Runner target

1. Left sidebar → click **Runner** (blue app icon at top).
2. Center panel → **TARGETS** → **Runner** (not PROJECT Runner).
3. Top toolbar device menu → choose **Any iOS Device (arm64)**.  
   Do not archive while a Simulator is selected — Archive will be disabled or produce a bad build.

---

## 3. Signing & Capabilities

Tab: **Signing & Capabilities**

| Setting | Expected |
| --- | --- |
| Team | Your Apple Developer team |
| Bundle Identifier | `com.voicememory.mobile` |
| Automatically manage signing | ON (recommended) |
| Signing Certificate | Apple Distribution (appears after archive) |
| Provisioning Profile | App Store / Xcode Managed |

**If signing fails:**

- Xcode → Settings → Accounts → your Apple ID → Download Manual Profiles.
- Confirm the App Store Connect app record exists for `com.voicememory.mobile`.
- Clean: Product → Clean Build Folder (⇧⌘K), then retry.

**Do not** add App Groups or widget entitlements — native extensions are disabled for this beta.

---

## 4. Version & build (optional check)

Tab: **General**

| Field | Source |
| --- | --- |
| Version | `0.2.0` from `pubspec.yaml` |
| Build | `48` from `pubspec.yaml` `+48` |

If App Store Connect rejects “build already exists”, bump `pubspec.yaml` (e.g. `0.2.0+49`), re-run `flutter build ios --release …`, then archive again.

---

## 5. Archive

1. Menu **Product → Archive**.
2. First archive may take several minutes (Release + bitcode/symbols).
3. On success, **Organizer** opens automatically.  
   If not: **Window → Organizer** (⇧⌘⌥O).

**Organizer → Archives tab:**

- You should see **ArchiveMe** (or Runner) with today’s date.
- Version **0.2.0 (48)**.

---

## 6. Validate (recommended)

1. Select the new archive → **Validate App**.
2. Distribution method: **App Store Connect**.
3. Options: leave defaults (Upload symbols, Manage Version and Build Number).
4. Signing: **Automatically manage signing**.
5. Wait for “Validation successful”.

Fix any errors before uploading (missing icons, entitlement mismatches, etc.).

---

## 7. Distribute to App Store Connect

1. Select archive → **Distribute App**.
2. **App Store Connect** → Next.
3. **Upload** → Next.
4. Distribution options → Next (defaults OK).
5. Signing → **Automatically manage signing** → Next.
6. Review summary → **Upload**.

Progress bar in Organizer. When done: “Upload Successful”.

**Record signing evidence** (for manifest):

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

Save to `mobile/evidence/ios_signing_tested.json`.

---

## 8. App Store Connect — processing

1. [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **My Apps** → **ArchiveMe**.
2. **TestFlight** tab.
3. Under **iOS Builds**, status progresses: **Processing** → **Ready to Submit** / **Testing**.

Processing usually takes 5–30 minutes. You’ll get email when ready.

**If processing fails:** open the build → view **Activity** / email for ITMS errors (missing compliance, invalid icons, etc.).

---

## 9. Internal testing

1. TestFlight → **Internal Testing** → your internal group (or create one).
2. **+** next to Builds → select build **48**.
3. Test Information: use notes from `apps/mobile/docs/TESTFLIGHT_MANUAL_QA.md`.
4. Add internal testers (must be App Store Connect users with Admin/App Manager/Developer role).

Testers receive TestFlight invite on iPhone.

---

## 10. Install on physical iPhone

1. Install **TestFlight** from App Store if needed.
2. Open invite link or TestFlight app → **ArchiveMe** → **Install**.
3. Launch — confirm home screen label is **ArchiveMe**.

Run smoke from `apps/mobile/docs/TESTFLIGHT_MANUAL_QA.md` sections A–J.

**TestFlight evidence** (`mobile/evidence/testflight_tested.json`) — smoke-only while purchases paused:

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
  "timestamp": "2026-08-12T20:15:00.000Z",
  "marketing_version": "0.2.0",
  "build_number": 48,
  "platform": "ios",
  "device": "iPhone16,2"
}
```

---

## 11. Offline sync re-verification (same build)

1. Settings → **About** → tap version **7×** (developer unlock).
2. Settings → **Offline sync verify**.
3. Complete flow → **Export evidence** → save to `mobile/evidence/offline_sync_tested.json`.

Must include `build_number: 48` and `commit_sha` matching `release/focused_beta_status.json`.

---

## 12. Update manifest

```bash
npm run validate:ios-signing
npm run validate:testflight-proof
npm run validate:offline-sync-production
npm run release:apply-device-evidence
npm run release:verify-focused-beta
```

See [`DEVICE_EVIDENCE_RUNBOOK.md`](./DEVICE_EVIDENCE_RUNBOOK.md) for VoiceOver sign-off and purchase/restore waiver when `livePurchases=false`.

---

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| Archive greyed out | Select **Any iOS Device**, not Simulator |
| No signing certificate | Xcode → Settings → Accounts → Manage Certificates → + Apple Distribution |
| Duplicate build number | Bump `pubspec.yaml` +N, rebuild, re-archive |
| Upload stuck processing | Wait 30 min; check email for compliance export questions |
| TestFlight install fails | Tester must accept invite; device iOS ≥ deployment target (13.0) |
| Offline export missing `commit_sha` | Rebuild with `--dart-define=SOURCE_COMMIT_SHA=$(git rev-parse HEAD)` |
