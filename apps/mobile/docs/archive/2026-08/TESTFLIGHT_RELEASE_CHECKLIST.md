# ArchiveMe — TestFlight release checklist

Use this before every TestFlight upload. For tester instructions after release, see [TESTFLIGHT_TESTER_SCRIPT.md](./TESTFLIGHT_TESTER_SCRIPT.md).

---

## Release identity

| Field | Expected value |
| --- | --- |
| **App name** | ArchiveMe |
| **Bundle ID** | `com.voicememory.mobile` |
| **Support URL** | https://careosapp.co.uk/archiveme-support |
| **Privacy URL** | https://careosapp.co.uk/archiveme-privacy |
| **Xcode workspace** | `apps/mobile/ios/Runner.xcworkspace` (not `.xcodeproj`) |

---

## Pre-upload checks

### Repo and tests

- [ ] On intended release branch; working tree clean or changes reviewed
- [ ] `flutter pub get` succeeds
- [ ] `flutter analyze lib/` — no new errors
- [ ] Core test suite green (at minimum):

```bash
cd apps/mobile
flutter test \
  test/testflight_feedback_test.dart \
  test/settings_screen_test.dart \
  test/early_first_signal_test.dart \
  test/first_archive_state_test.dart \
  test/one_entry_post_save_copy_test.dart \
  test/paywall_restore_test.dart \
  test/restore_purchases_flow_test.dart \
  test/revenuecat_offerings_expectations_test.dart \
  test/revenuecat_release_config_test.dart \
  test/trial_mode_revenuecat_test.dart
```

### Version and build number

- [ ] Open `pubspec.yaml` — format `version: x.y.z+NN` (e.g. `0.2.0+46`)
- [ ] **Marketing version** (`x.y.z`) matches App Store Connect if updating an existing version
- [ ] **Build number** (`+NN`) is **strictly higher** than the last uploaded build for that version
- [ ] Settings → App version on device will show `x.y.z (NN)` after install

Quick check:

```bash
grep '^version:' apps/mobile/pubspec.yaml
```

Optional override at build time: `--build-number=NN` (still bump pubspec for consistency).

### Build defines (must be OFF for TestFlight upload)

- [ ] `ARCHIVEME_TRIAL_MODE` — **unset** or `false`
- [ ] `VOICE_MEMORY_SCREENSHOT_MODE` — **unset** or `false`
- [ ] Production API base URL set (see build command below)

### RevenueCat iOS key

- [ ] `REVENUECAT_IOS_API_KEY` (or fallback `REVENUECAT_API_KEY`) is available for the build environment
- [ ] Key is passed via `--dart-define` at build time — **never committed to the repo**
- [ ] After install, startup log shows RevenueCat configured (not `disabled — no API key`) when billing should be testable
- [ ] If billing is still paused for this cohort: paywall shows **honest unavailable** copy; no paid claims in release notes

Reference: [REVENUECAT_RELEASE_CHECKLIST.md](./REVENUECAT_RELEASE_CHECKLIST.md)

### Legal and support screens (in-app)

- [ ] **Settings → Privacy** opens privacy screen; link loads https://careosapp.co.uk/archiveme-privacy
- [ ] **Settings → Terms of Use** opens terms screen (`/terms`)
- [ ] **Settings → Support & feedback** opens support screen; support page link works
- [ ] **Settings → Testing ArchiveMe? → Send feedback** opens mail draft to `hello@careosapp.co.uk` (or shows calm fallback if no mail app)

### Restore purchases

- [ ] **Settings → Restore purchases** is visible
- [ ] Tap restore — app does not crash; shows success, no-purchase, or unavailable message (never a blank hang)
- [ ] If RevenueCat is configured: restore refreshes entitlement state without leaving stale Pro unlocked incorrectly
- [ ] If RevenueCat is **not** configured: honest “purchases unavailable” copy — acceptable for early TestFlight

### Xcode signing

- [ ] Open `ios/Runner.xcworkspace`
- [ ] Correct Apple Developer **team** selected
- [ ] **Automatically manage signing** on (or valid distribution profiles)
- [ ] Valid **Distribution** certificate for upload
- [ ] `NSMicrophoneUsageDescription` present in Info.plist

### App Store Connect metadata

- [ ] Support URL in App Store Connect matches https://careosapp.co.uk/archiveme-support
- [ ] Privacy policy URL matches https://careosapp.co.uk/archiveme-privacy
- [ ] Export compliance / encryption questions answered if prompted after upload

---

## IPA build command

From repo root:

```bash
cd apps/mobile

flutter clean
flutter pub get

flutter build ipa \
  --dart-define=VOICE_MEMORY_API_BASE_URL=https://voice-memory-iota.vercel.app \
  --dart-define=REVENUECAT_IOS_API_KEY=appl_YOUR_KEY_HERE
```

**Notes**

- Omit `REVENUECAT_IOS_API_KEY` only if this build intentionally ships with billing disabled (document in What to Test).
- Do **not** pass `ARCHIVEME_TRIAL_MODE=true` or `VOICE_MEMORY_SCREENSHOT_MODE=true`.
- Output: `build/ios/ipa/*.ipa` — or archive via Xcode after `flutter build ios --release` with the same dart-defines.

**Archive via Xcode (alternative)**

```bash
flutter build ios --release \
  --dart-define=VOICE_MEMORY_API_BASE_URL=https://voice-memory-iota.vercel.app \
  --dart-define=REVENUECAT_IOS_API_KEY=appl_YOUR_KEY_HERE
```

Then: Xcode → Product → **Archive** (Release, Any iOS Device) → Organizer → **Validate** → **Upload**.

---

## TestFlight internal testing setup

- [ ] Upload completes in App Store Connect → **TestFlight** → build processing finished
- [ ] Add **internal testers** (App Store Connect → Users and Access / TestFlight groups)
- [ ] Paste tester message from [BETA_TESTER_MESSAGE.md](./BETA_TESTER_MESSAGE.md) or link [TESTFLIGHT_TESTER_SCRIPT.md](./TESTFLIGHT_TESTER_SCRIPT.md)
- [ ] **What to Test** describes: save moments, Patterns early proof, feedback via Settings — no false Pro/purchase claims if billing paused
- [ ] Install on a **physical iPhone** (not simulator-only sign-off)

---

## Smoke test after install

Run on device within 30 minutes of install. Mark Pass/Fail.

| Step | Check |
| --- | --- |
| 1 | App launches as **ArchiveMe** (not VoiceMemory) |
| 2 | Onboarding completes or skips; lands on **Record** |
| 3 | Save one moment (voice or **Type instead**) — no crash |
| 4 | **Patterns** tab loads — empty, first-saved, or early proof state |
| 5 | **Settings** — Privacy, Terms, Support & feedback, Restore purchases, Send feedback row visible |
| 6 | Restore purchases tap — clear outcome (see above) |
| 7 | Paywall/subscription path — opens without crash; copy honest if billing unavailable |
| 8 | No developer/diagnostic screens without unlock (7 taps on version) |

Extended QA: [TESTFLIGHT_MANUAL_QA.md](./TESTFLIGHT_MANUAL_QA.md)

---

## Known acceptable warnings (do not block upload)

These are expected in CI, local builds, or TestFlight when configured as noted:

| Warning / behavior | Why it is OK |
| --- | --- |
| **`flutter pub outdated` / packages have newer versions** | Informational only unless a security advisory applies — do not block TestFlight for version lag alone |
| **`RevenueCat: disabled — no API key`** in **unit/widget tests** | Tests run without dart-define keys by design |
| **`RevenueCat: disabled — no API key`** in a **billing-off TestFlight build** | Acceptable if cohort is told purchases are unavailable; not acceptable for paid-launch validation builds |
| **Firebase not configured / analytics disabled** | App must still launch; analytics silently skipped when `GoogleService-Info.plist` missing or Firebase init fails soft |
| **`ApiClient: backend not configured`** in tests | Test sandbox without network |
| **Restore shows “purchases unavailable”** | Expected until App Store Connect + RevenueCat products are fully wired |

**Not acceptable**

- Crash on launch, save, or Settings
- Screenshot mode or trial mode accidentally enabled on upload build
- False “Pro active” or purchase success when store is unavailable
- Support/privacy URLs broken in App Store Connect or in-app

---

## Related docs

- [TESTFLIGHT_SUBMISSION_CHECKLIST.md](./TESTFLIGHT_SUBMISSION_CHECKLIST.md)
- [TESTFLIGHT_BUILD_NOTES.md](./TESTFLIGHT_BUILD_NOTES.md)
- [TESTFLIGHT_MANUAL_QA.md](./TESTFLIGHT_MANUAL_QA.md)
- [TESTFLIGHT_TESTER_SCRIPT.md](./TESTFLIGHT_TESTER_SCRIPT.md)
- [SECURITY_AUDIT_NOTES.md](./SECURITY_AUDIT_NOTES.md)
- [REVENUECAT_RELEASE_CHECKLIST.md](./REVENUECAT_RELEASE_CHECKLIST.md)

---

## Sign-off

| Role | Name | Date | Build `x.y.z+NN` |
| --- | --- | --- | --- |
| Built & uploaded | | | |
| Smoke test (device) | | | |
| Internal testers invited | | | |
