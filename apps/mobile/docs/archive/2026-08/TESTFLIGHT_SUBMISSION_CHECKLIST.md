# ArchiveMe — TestFlight Submission Checklist

Pre-upload checklist for capacity-yes TestFlight builds. Run before archiving in Xcode.

## Identity

- [ ] **App name:** ArchiveMe (display name in Info.plist)
- [ ] **Bundle ID:** `com.voicememory.mobile`
- [ ] **Support URL:** https://careosapp.co.uk/archiveme-support (App Store Connect + in-app)
- [ ] **URL scheme:** `archiveme://`

## Xcode workspace (required)

Open:

```
apps/mobile/ios/Runner.xcworkspace
```

Use the **workspace**, not the bare project file. CocoaPods integration requires the workspace.

- [ ] Signing team and provisioning profiles valid
- [ ] **Build number incremented** if a previous build with the same version was already uploaded (`pubspec.yaml` → `version: x.y.z+NN`)

## RevenueCat / payments (paused)

- [ ] RevenueCat and payment copy remain **unavailable / paused** for this beta
- [ ] No paid claims in release notes, tester message, or What to Test
- [ ] Restore Purchases shows honest unavailable copy if tapped
- [ ] Do **not** pass purchase CTAs in tester-facing copy

## Build safety

- [ ] `VOICE_MEMORY_SCREENSHOT_MODE` unset or `false` for upload builds
- [ ] `ARCHIVEME_TRIAL_MODE` unset or `false` for TestFlight upload (trial builds are separate)
- [ ] `NSMicrophoneUsageDescription` present: microphone for recording moments
- [ ] No debug/dev routes visible without developer unlock

## Archive and upload

1. Product → **Archive** (Release, Any iOS Device)
2. **Validate** archive in Organizer
3. **Upload** to App Store Connect
4. Wait for processing; resolve compliance prompts

## TestFlight setup

- [ ] Add internal testers in App Store Connect → TestFlight
- [ ] Paste [BETA_TESTER_MESSAGE.md](./BETA_TESTER_MESSAGE.md) into tester invite or email
- [ ] What to Test: capacity-yes wedge — save 3 yes moments, review yes loop, report fit

## Reviewer / test account path (if needed)

- [ ] App Review Notes reference Sample Archive and Help & reviewer guide (no login required for core loop)
- [ ] Mic permission prompt appears on first record attempt
- [ ] Fresh install smoke test on physical device after TestFlight processing

## Post-upload QA

Run [TESTFLIGHT_MANUAL_QA.md](./TESTFLIGHT_MANUAL_QA.md) on a physical device after install.

## Build command reference

```bash
cd apps/mobile
flutter build ios --release --no-codesign
```

Add RevenueCat dart-define only when paid launch is ready — not for this beta cohort.
