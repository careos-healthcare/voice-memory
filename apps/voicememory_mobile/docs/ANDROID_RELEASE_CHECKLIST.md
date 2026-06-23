# Android release checklist — ArchiveMe

## Identity

- **Application ID:** `com.voicememory.app`
- **App label:** ArchiveMe (`AndroidManifest.xml`)

## Permissions

- `RECORD_AUDIO` — required for reflection recording
- `INTERNET` — API, transcribe, analyze

## SDK

- **minSdk:** 24 (see `android/app/build.gradle.kts`)
- **Release signing:** replace debug signing in `buildTypes.release` before Play production

```kotlin
// TODO: signingConfigs { create("release") { ... } }
// release { signingConfig = signingConfigs.getByName("release") }
```

## Play Console

- Data safety: audio recordings, email, device ID; no sale of data
- Internal testing track first
- Screenshots: Record, Archive (Patterns), Account, Sample Archive

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
```

Add RevenueCat dart-define when billing setup is complete.

Upload `build/app/outputs/bundle/release/app-release.aab`.

See also: `LAUNCH_VALIDATION.md`, `REVENUECAT_LAUNCH_BLOCKERS.md`.
