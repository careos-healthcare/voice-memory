# Google Play internal testing checklist

## Before you build

- [ ] Confirm package name: `com.voicememory.mobile`
- [ ] Confirm signing keystore and `key.properties`
- [ ] Increment version code in `pubspec.yaml` / `build.gradle`
- [ ] Confirm **no** screenshot dart-defines in release
- [ ] Confirm RevenueCat Android key for billing builds:
  - `REVENUECAT_ANDROID_API_KEY` or `REVENUECAT_API_KEY`
- [ ] Confirm trial define is **off** for Play Store builds
- [ ] Verify microphone permission copy is plain and accurate

## Build app bundle

```bash
cd apps/voicememory_mobile
flutter build appbundle --release \
  --dart-define=REVENUECAT_ANDROID_API_KEY=your_key_here
```

Output: `build/app/outputs/bundle/release/app-release.aab`

## Upload

- [ ] Play Console → Internal testing → Create release
- [ ] Upload `.aab`
- [ ] Complete store listing (see `PLAY_STORE_COPY.md`)
- [ ] Add internal testers / email list
- [ ] Roll out internal testing track

## Install and smoke test

- [ ] Install from Play internal link on a physical device
- [ ] Microphone permission prompt appears on first record
- [ ] Onboarding → Record flow works
- [ ] Record / save / tomorrow check loop
- [ ] Patterns tab loads
- [ ] Paywall path (Settings → subscription) behaves correctly

## Trial / local mode (separate build)

```bash
flutter run --dart-define=ARCHIVEME_TRIAL_MODE=true
```

- [ ] Skips paywall; starts at Record
- [ ] No login required
- [ ] Missing RevenueCat key does not crash

## Release safety

- [ ] No screenshot mode defines in release bundle
- [ ] No developer routes in consumer navigation
- [ ] Trial Control hidden unless trial define + developer unlock

## Debug launch command (developers only)

```bash
adb shell monkey -p com.voicememory.mobile 1
```

Do not document this for testers; internal use only.
