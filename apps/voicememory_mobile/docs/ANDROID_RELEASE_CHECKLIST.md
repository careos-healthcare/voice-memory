# Android release checklist — ArchiveMe

## Identity

- **Application ID:** `com.voicememory.mobile`
- **Namespace:** `com.voicememory.mobile` (`android/app/build.gradle.kts`)
- **App label:** ArchiveMe (`AndroidManifest.xml`)

## Permissions

- `RECORD_AUDIO` — required for reflection recording
- `INTERNET` — API, transcribe, analyze
- `USE_BIOMETRIC` — optional private-lock authentication

## SDK

- **compileSdk:** 36
- **targetSdk:** 36
- **minSdk:** 26
- **Version/build source:** `pubspec.yaml`
- **Release signing:** fail-closed; production release APK/AAB tasks reject
  missing, partial or invalid `android/key.properties`

```bash
cp android/key.properties.example android/key.properties
# Replace every placeholder and provide android/app/upload-keystore.jks.
./android/gradlew -p android app:verifyProductionReleaseSigning
```

## Play Console

- Data safety: audio recordings, email, device ID; no sale of data
- Internal testing track first
- Screenshots: Record post-save receipt, Archive originals, chronological
  Changes, and Account

## Focused return QA

- [ ] First save shows Saved → editable transcript → at most one validated
  observation → exact evidence → correction controls → one next action
- [ ] Second related save can show a distinct Then/Now comparison in Changes
- [ ] Both evidence sources open, including audio timestamps when available
- [ ] Existing Changes items remain readable without active Pro
- [ ] No graph, analyst, blind-spot, reminder, streak, or paywall card appears
  in the post-save stack

## Purchases (RevenueCat — not ready until setup complete)

- Native IAP via RevenueCat — **not** external Stripe browser checkout
- Purchases unavailable until Play Console + RevenueCat products are configured
- Release build must include `REVENUECAT_ANDROID_API_KEY` when ready
- Entitlement id: **`pro`**
- Complete sandbox purchase + restore evidence before paid launch

## Build

```bash
flutter build appbundle --release \
  --dart-define=VOICE_MEMORY_API_BASE_URL=https://voice-memory-iota.vercel.app
bash tool/audit_v1_permissions.sh
bash tool/verify_android_release_artifact.sh \
  build/app/outputs/bundle/release/app-release.aab
```

Add RevenueCat dart-define when billing setup is complete.

Only upload `build/app/outputs/bundle/release/app-release.aab` after both audits
pass. The protected manual workflow builds and verifies the artifact but does
not publish it to Google Play.

See also: `LAUNCH_VALIDATION.md`, `REVENUECAT_LAUNCH_BLOCKERS.md`.
