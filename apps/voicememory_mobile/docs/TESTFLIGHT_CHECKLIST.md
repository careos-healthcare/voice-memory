# TestFlight internal testing checklist

## Before you archive

- [ ] Open the correct workspace: `apps/voicememory_mobile/ios/Runner.xcworkspace` (not `.xcodeproj`)
- [ ] Confirm bundle ID matches App Store Connect
- [ ] Confirm signing team and provisioning profiles
- [ ] Increment build number (`CFBundleVersion` / Xcode build)
- [ ] Confirm **no** screenshot dart-defines in release:
  - `VOICE_MEMORY_SCREENSHOT_MODE` must be unset or `false`
- [ ] Confirm RevenueCat API key is set only for builds that should bill:
  - `REVENUECAT_IOS_API_KEY` or `REVENUECAT_API_KEY`
- [ ] Confirm trial define is **off** for App Store builds:
  - `ARCHIVEME_TRIAL_MODE` must be unset or `false`
- [ ] Verify `NSMicrophoneUsageDescription` in Info.plist:
  - "ArchiveMe uses the microphone so you can record moments."

## Archive and upload

- [ ] Product → Archive from Xcode (Release, Any iOS Device)
- [ ] Validate archive
- [ ] Upload to App Store Connect
- [ ] Wait for processing; resolve any compliance prompts

## Internal testers

- [ ] Add internal testers in App Store Connect → TestFlight
- [ ] Send install link; confirm install on a physical device

## Smoke test on device

- [ ] Onboarding: four pages, final CTA **Start with one moment** → Record
- [ ] Record: archive memory demo visible before first save
- [ ] Record: dominant CTA **Record one moment**
- [ ] Save first moment; pattern / tomorrow check flow works
- [ ] Return-day check-in (if testable same day: verify UI at least loads)
- [ ] Patterns tab: empty preview or summary loads without crash
- [ ] Paywall: headline **Keep your pattern memory growing**
- [ ] Settings → subscription path opens (or shows clear config message if RC key missing)

## Trial / local mode (separate build)

Build with `--dart-define=ARCHIVEME_TRIAL_MODE=true` for facilitator sessions only.

- [ ] Skips onboarding gate → lands on Record
- [ ] No paywall / payment required
- [ ] Trial Control reachable only with developer unlock
- [ ] Local export works; no login required
- [ ] Missing RevenueCat key does not crash

## Release safety

- [ ] No debug/dev routes visible without developer unlock (7 taps on version)
- [ ] No screenshot mode UI unless screenshot define is set
- [ ] No internal verification screens in consumer nav

## Build command reference (release, no screenshot)

```bash
cd apps/voicememory_mobile
flutter build ios --release \
  --dart-define=REVENUECAT_IOS_API_KEY=your_key_here
```

## Trial build command reference

```bash
flutter run --dart-define=ARCHIVEME_TRIAL_MODE=true
```
