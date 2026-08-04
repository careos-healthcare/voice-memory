# ArchiveMe — TestFlight Build Notes

These notes cover producing a TestFlight build for the trial. For the local-only
fallback, see `docs/TRIAL_EXECUTION_RUNBOOK.md`.

## 1. Exact build command

Release build for the App Store / TestFlight (sets the production API and keeps
trial/screenshot modes OFF):

```bash
flutter build ipa \
  --dart-define=VOICE_MEMORY_API_BASE_URL=https://voice-memory-iota.vercel.app
```

To produce only the Xcode archive inputs (then archive in Xcode):

```bash
flutter build ios --release \
  --dart-define=VOICE_MEMORY_API_BASE_URL=https://voice-memory-iota.vercel.app
```

> Do NOT pass `ARCHIVEME_TRIAL_MODE=true` or `VOICE_MEMORY_SCREENSHOT_MODE=true`
> for a TestFlight/App Store build. Both default to false and must stay off.

## 2. Open the workspace, not the project
Always open:

```
ios/Runner.xcworkspace
```

NOT `ios/Runner.xcodeproj` (CocoaPods integration lives in the workspace).

## 3. Signing checklist
- Open Runner.xcworkspace → Runner target → Signing & Capabilities.
- Team: select the correct Apple Developer team.
- Automatically manage signing: ON (or supply provisioning profiles).
- Ensure a valid Distribution certificate exists for upload.
- Note: the Podfile sets `CODE_SIGNING_ALLOWED=NO` for Pods (intended); the Runner
  app itself still needs a valid signing identity for device/TestFlight builds.

## 4. Bundle id checklist
- App bundle id (Xcode): `com.voicememory.mobile`.
- Confirm it matches `AppConfig.bundleId` and the App Store Connect app record.
- Focused V1 Release has no App Group, iCloud or embedded extensions.
- Release URL scheme in `Info-Release.plist`: `archiveme://`.
- Deployment target: iOS 15.5 (matches the Podfile and Runner build settings).

## 5. Build number increment
- Version/build come from `pubspec.yaml` (`version: 0.2.0+49` →
  CFBundleShortVersionString 0.2.0, CFBundleVersion 49).
- Increment the build number for every TestFlight upload:
  - bump the `+N` in `pubspec.yaml`;
  - do not leave a CI-only build number that contradicts the source file.

## 6. Upload via Xcode Organizer
1. Product → Archive (Release, "Any iOS Device").
2. Window → Organizer → select the archive → Distribute App → App Store Connect → Upload.
3. Wait for processing in App Store Connect → TestFlight → add testers.

## 7. If RevenueCat / API keys are missing
- Without RevenueCat keys, billing/paywall will be inert. The core loop still works.
- For the trial, prefer local/trial mode where billing is not required.
- Do not hardcode keys in the repo; pass via dart-define or secure config.

## 8. If Firebase is disabled
- Analytics/messaging simply won't send. The app must still launch and run the loop.
- Ensure `GoogleService-Info.plist` is present for a Firebase-enabled build; if it
  is absent, confirm Firebase init fails soft and does not crash launch.

## 9. Known local / trial mode limitations
- Trial mode is local-only: no cloud sync, billing, push, or login.
- Transcription/analysis in the full build requires the backend; trial/screenshot
  modes use on-device sample/seeded data.
- Developer/diagnostic screens are gated and hidden from the participant flow.

## 10. Pre-upload sanity
```bash
flutter analyze lib/
./tool/run_app_store_readiness_check.sh
./tool/run_trial_execution_check.sh
```

## 11. Manual QA on device

After upload, run the physical-device script in [TESTFLIGHT_MANUAL_QA.md](./TESTFLIGHT_MANUAL_QA.md) before inviting external testers.
