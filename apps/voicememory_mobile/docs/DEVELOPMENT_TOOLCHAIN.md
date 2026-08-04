# ArchiveMe development toolchain

`pubspec.yaml` is the application-version source of truth. `.fvmrc` is the
Flutter-version source of truth.

## Pinned versions

- Flutter: **3.44.6** (stable, revision `ee80f08bbf`)
- Dart: **3.12.2**
- Java: **17** for CI and Android builds; source/target compatibility is 17
- Gradle: **8.14**
- Android Gradle Plugin: **8.11.1**
- Android compile/target SDK: **36**
- Android SDK platform: **android-36**
- Android Build Tools: **36.1.0**
- CMake: **3.22.1**
- iOS deployment target: **15.5**
- Xcode: **26.1.1** is the verified local version; CI uses the current Xcode
  available on the pinned `macos-15` runner

The verified macOS workstation uses Android Studio JBR 21.0.8 to launch Gradle.
CI deliberately uses Java 17. Both compile app sources to Java 17 bytecode.

## Bootstrap with FVM

```bash
dart pub global activate fvm
fvm install
fvm flutter --version
cd apps/voicememory_mobile
fvm flutter pub get
```

The version output must report Flutter 3.44.6 and Dart 3.12.2. Do not use a
floating `stable` SDK for release work.

If macOS has no system Java, point Gradle at Android Studio's bundled runtime:

```bash
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
```

CI uses Temurin Java 17 and does not depend on Android Studio.

## Android prerequisites

Install Android SDK Platform 36 and Build Tools 36.1.0. The release artifact is
required to contain `targetSdkVersion=36`; source configuration alone is not
release evidence.

Production release APK/AAB tasks require all four values in
`android/key.properties`. Debug builds do not:

```properties
storeFile=upload-keystore.jks
storePassword=...
keyAlias=...
keyPassword=...
```

## Clean verification

Run from `apps/voicememory_mobile`:

```bash
fvm flutter clean
fvm flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test
fvm flutter analyze --fatal-infos --fatal-warnings
fvm flutter test
fvm flutter build apk --debug
fvm flutter build ios --release --no-codesign
```

Run the V1 permission audit after the platform builds:

```bash
bash tool/audit_v1_permissions.sh
```

Release AABs must additionally pass:

```bash
bash tool/verify_android_release_artifact.sh \
  build/app/outputs/bundle/release/app-release.aab
```
