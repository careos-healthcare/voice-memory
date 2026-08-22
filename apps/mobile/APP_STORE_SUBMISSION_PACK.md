# ArchiveMe — iOS / TestFlight Submission Readiness Pack

Single checklist for preparing an internal TestFlight build and App Store review.
Run from `apps/voicememory_mobile` unless noted.

## Release identity

| Field | Value |
| --- | --- |
| **Public app name** | ArchiveMe |
| **iOS bundle ID** | `com.voicememory.mobile` |
| **Android application ID** | `com.voicememory.mobile` (Play is separate) |
| **Marketing version** | `0.2.0` (from `pubspec.yaml`) |
| **Build number** | See `release/focused_beta_status.json` (must match `pubspec.yaml` → `version: 0.2.0+<build>`) |
| **Release manifest** | `release/focused_beta_status.json` — run `npm run release:verify-focused-beta` before upload |
| **Support URL** | https://archiveme.app/contact |
| **Privacy policy (web)** | https://archiveme.app/privacy |
| **Privacy policy (in-app)** | Settings → Privacy (`/privacy`) |
| **Terms (in-app)** | `/terms` |
| **Primary URL scheme** | `archiveme://` |
| **Legacy URL scheme** | `voicememory://` |
| **App Group (widget prep)** | Removed for focused beta (`V1CapabilityRegistry.nativeExtensions = false`) |

Open **`ios/Runner.xcworkspace`** for archive/upload — not `Runner.xcodeproj`.

## Purchases / RevenueCat (paused)

- Native billing code exists, but **purchases are unavailable** until App Store Connect banking and RevenueCat product setup are complete.
- **RevenueCat is paused** on this branch — do not claim users can buy Pro yet.
- Do **not** use subscribe-or-buy purchase CTAs in release notes while billing is incomplete.
- **Restore purchases** is reachable from Settings; it should show honest unavailable/inert copy until RevenueCat is configured.
- **Pro preview** (`/pro-preview`) explains future Pro value only — no purchase CTA.
- No Stripe checkout in the mobile app.

## Reviewer demo path (under 2 minutes)

1. Fresh install → complete onboarding if shown → land on **Record** (`/record`).
2. Save one **typed** moment (Type instead — no microphone required).
3. Save one **voice** moment (microphone permission on first use).
4. Open **Archive** tab → **Archive Home** (`/archive-belief`).
5. Open **Sample Archive** (`/sample-archive`) — example data only, never writes to the real journal.
6. Settings → **Help & reviewer guide** (`/help-reviewer-guide`).
7. Settings → **Support & feedback** (`/support-feedback`).
8. Settings → **See Pro preview** (`/pro-preview`) — interest-only, no purchase.
9. Settings → **Restore purchases** — confirm unavailable/honest copy until billing is ready.

Reviewer notes block (paste into App Store Connect if helpful):

```
• ArchiveMe can be tested without microphone access by using Type instead.
• Sample Archive uses example data only and does not write to the real journal.
• RevenueCat purchases are unavailable until banking setup is complete; the free archive flow remains usable.
• Privacy & data controls are available in Settings.
• Share-safe summary does not include raw private entries.
• Support URL: https://archiveme.app/contact
```

## Microphone & privacy (reviewer copy)

- **Microphone:** used only to record the user's own voice reflections. Permission string: “ArchiveMe needs the microphone to record private voice reflections.”
- **Local archive:** journal entries stay on device unless the user explicitly exports or shares share-safe proof (no raw entries in demo/sample routes).
- **Sample Archive / reviewer routes:** must not display the user's private journal text.

## Screenshot checklist (App Store Connect)

Capture on device or simulator with production API configured:

1. Record — first moment / Type instead visible
2. Archive Home — cautious evidence after 1–3 moments
3. Sample Archive — clearly labeled example data
4. Patterns / evidence touchpoint (if visible in build)
5. Settings — Privacy & data controls (no developer diagnostics)
6. Pro preview — value explanation, no purchase button claiming checkout works

Use ArchiveMe branding only in screenshots.

## TestFlight internal test checklist

- [ ] Build uploaded from Xcode Organizer after `flutter build ios --release`
- [ ] Build number matches `release/focused_beta_status.json` and `pubspec.yaml`
- [ ] Internal tester invited and build installed on physical device
- [ ] Fresh install completes without crash
- [ ] Typed moment saves locally
- [ ] Voice moment saves after mic permission
- [ ] Archive Home loads after saves
- [ ] Sample Archive opens with example data only
- [ ] Help & reviewer guide opens
- [ ] Support & feedback opens; support URL loads externally
- [ ] Pro preview opens without purchase claim
- [ ] Restore purchases shows unavailable/honest messaging
- [ ] No placeholder app icon / launch image warnings in archive log
- [ ] No private journal text visible in sample/reviewer surfaces

## Manual archive checklist (Xcode)

1. Open `ios/Runner.xcworkspace`
2. Confirm signing team and **bundle ID** `com.voicememory.mobile`
3. Product → Archive (Release, Any iOS Device)
4. Window → Organizer → Distribute App → App Store Connect → Upload
5. Wait for processing → TestFlight → add internal testers
6. Install on physical device and run the reviewer demo path above
7. Confirm purchase-unavailable copy is honest on Pro preview and Restore purchases
8. Grep archive/build log for placeholder icon warnings (see validation commands)

## Build commands

Pre-flight Flutter release build (no codesign — CI sanity):

```bash
cd apps/voicememory_mobile
flutter pub get
flutter build ios --release --no-codesign \
  --dart-define=VOICE_MEMORY_API_BASE_URL=https://voice-memory-iota.vercel.app
```

TestFlight / App Store archive inputs:

```bash
flutter build ios --release \
  --dart-define=VOICE_MEMORY_API_BASE_URL=https://voice-memory-iota.vercel.app
```

Then archive in Xcode from `ios/Runner.xcworkspace`.

Do **not** pass `ARCHIVEME_TRIAL_MODE=true` or `VOICE_MEMORY_SCREENSHOT_MODE=true` for TestFlight uploads.

## Final validation commands

From repository root (release packaging is blocked until verification passes):

```bash
npm run release:verify-focused-beta
npm run test:release-focused-beta-status
git diff --exit-code -- generated/release-summary.md
```

Mobile-focused checks:

```bash
cd apps/voicememory_mobile
flutter test \
  test/ios_testflight_submission_readiness_test.dart \
  test/release_identity_consistency_test.dart \
  test/app_store_rc_polish_test.dart \
  test/mobile_production_readiness_test.dart \
  test/consumer_visible_branding_test.dart \
  test/launch_hardening_test.dart

flutter build ios --release --no-codesign 2>&1 | tee /tmp/archiveme_ios_testflight_submission.log
grep -E "App icon is set to the default placeholder|Launch image is set to the default placeholder|App Icon and Launch Image Assets Validation|error:" /tmp/archiveme_ios_testflight_submission.log || true

cd /Users/chiragpatel/Projects/voice-memory
find apps/voicememory_mobile -maxdepth 1 -type f \( -name '*_journal.json' -o -name '*_prefs.json' \) -delete
bash scripts/validate-mobile-clean-working-tree.sh
```

## Related docs

- `docs/TESTFLIGHT_MANUAL_QA.md` — physical-device QA script and release decision checklist
- `docs/APP_REVIEW_NOTES.md` — App Store reviewer notes
- `docs/APP_STORE_COPY.md` — listing copy draft
- `docs/IOS_RELEASE_CHECKLIST.md` — iOS release checklist
- `docs/TESTFLIGHT_BUILD_NOTES.md` — TestFlight build steps
- `LAUNCH_VALIDATION.md` — focused test suite
- `REVENUECAT_LAUNCH_BLOCKERS.md` — why billing stays off
