# Android release checklist — ArchiveMe

## Identity

- **Application ID:** `com.voicememory.mobile`
- **Namespace:** `com.voicememory.mobile` (`android/app/build.gradle.kts`)
- **App label:** ArchiveMe (`AndroidManifest.xml`)

## Permissions

- `RECORD_AUDIO` — required for reflection recording
- `INTERNET` — API, transcribe, analyze

## SDK

- **minSdk:** 24 (see `android/app/build.gradle.kts`)
- **Release signing:** `android/app/build.gradle.kts` loads a real upload
  keystore from `android/key.properties` when present, and signs `release`
  builds with it. Without that file it falls back to the debug key **and
  prints a loud warning in the Gradle build log** — that fallback build
  cannot be uploaded to the Play Store.

To configure real signing:

1. Generate an upload keystore if you don't already have one:
   `keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
   (see https://flutter.dev/to/reference-keystore).
2. Copy `android/key.properties.example` to `android/key.properties` (this
   file is gitignored — never commit it) and fill in the real
   `storePassword`, `keyPassword`, `keyAlias`, and `storeFile` path.
3. Build with `flutter build appbundle --release` and confirm the Gradle
   output does **not** print the debug-signing warning above.
4. Verify with `jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab`
   that the signer is your upload key, not the Flutter debug key.

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
