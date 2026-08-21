# Android release checklist — ArchiveMe

## Identity

- **Application ID:** `com.voicememory.mobile`
- **Namespace:** `com.voicememory.mobile` (`android/app/build.gradle.kts`)
- **App label:** ArchiveMe (`AndroidManifest.xml`)

## Permissions

- `RECORD_AUDIO` — required for reflection recording
- `INTERNET` — API, transcribe, analyze
- `ACCESS_NETWORK_STATE` — connectivity checks (normal permission)
- `USE_BIOMETRIC` — optional app lock / SQLCipher gate
- `com.android.vending.BILLING` — RevenueCat in-app purchases

Audio capture runs in the **foreground only** (the pipeline pauses when the app
backgrounds). No `FOREGROUND_SERVICE_*` permissions are required for recording.
Transitive permissions from unused plugins are stripped in
`AndroidManifest.xml` via `tools:node="remove"`.

## SDK

- **compileSdk / targetSdk:** 36
- **minSdk:** 26 — satisfies native deps: `llama_cpp_dart` (24), SQLCipher /
  `sqflite_sqlcipher` (21), `sherpa_onnx` (21), `flutter_onnxruntime` (21)
- **Release R8:** `isMinifyEnabled` + ProGuard rules in
  `android/app/proguard-rules.pro` (SQLCipher, OkHttp/Retrofit, Gson, ONNX,
  Flutter, RevenueCat)
- **Release signing:** `android/app/build.gradle.kts` loads a real upload
  keystore from `android/key.properties` **or** from the
  `ARCHIVEME_ANDROID_*` environment variables documented in
  `android/key.properties.example`. Release builds **fail fast** when
  credentials are absent. They **never** fall back to the debug keystore.

To configure real signing:

1. Generate an upload keystore if you don't already have one:
   `keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
   (see https://flutter.dev/to/reference-keystore).
2. Copy `android/key.properties.example` to `android/key.properties` (this
   file is gitignored — never commit it) and fill in the real
   `storePassword`, `keyPassword`, `keyAlias`, and `storeFile` path.
   **Or** export the four `ARCHIVEME_ANDROID_*` variables instead.
3. Run the credential-free gate:
   `bash tool/validate_android_release_signing.sh`
4. Build with `flutter build appbundle --release`. Without credentials this
   command must fail with a clear “Release signing is not configured” error.
5. With credentials configured, verify the artifact with
   `jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab`
   or `apksigner verify --print-certs build/app/outputs/apk/release/app-release.apk`
   and confirm the signer is your upload key, not the Flutter debug key.

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
