# Android release checklist — ArchiveMe

## Identity

- **Application ID:** `com.voicememory.app`
- **App label:** ArchiveMe (`AndroidManifest.xml`)

## Permissions

- `RECORD_AUDIO` — required for reflection recording
- `INTERNET` — API, transcribe, analyze, sync, checkout

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
- Screenshots: Record, Memory, Discover, Pattern review, Account

## Stripe checkout

- Opens external browser / Chrome custom tab via `url_launcher`

## Build

```bash
flutter build appbundle --release \
  --dart-define=VOICE_MEMORY_API_BASE_URL=https://voice-memory-iota.vercel.app
```

Upload `build/app/outputs/bundle/release/app-release.aab`.
