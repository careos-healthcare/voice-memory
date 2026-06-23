# Running ArchiveMe on Android

Quick, reliable workflow for building, installing, and launching the Android
debug build on a physical device or emulator.

## Package name

The launchable Android application id is:

```
com.voicememory.mobile
```

> **Important:** Always use `com.voicememory.mobile` — the canonical application id.
> Do not use the retired `.app` suffix id in scripts or adb commands.

The id is defined in `android/app/build.gradle.kts`:

```kotlin
namespace = "com.voicememory.mobile"
applicationId = "com.voicememory.mobile"
```

## 1. List devices

```bash
flutter devices
```

Note the device id in the output (the value after the device name, e.g.
`emulator-5554` or a serial like `1A2B3C4D`).

## 2. Build, install, and launch (recommended)

Use the helper script. It builds the debug APK, installs it with the
non-streaming workaround, and launches the correct package:

```bash
tool/run_android_debug.sh                 # auto-pick the only connected device
tool/run_android_debug.sh emulator-5554   # or target a specific device id
```

## 3. Manual steps (if you prefer)

### Build the debug APK

```bash
flutter build apk --debug
```

### Install (non-streaming workaround)

Some devices/emulators fail with a streaming-install error
(`adb: failed to install ... Unknown failure`). Installing with
`--no-streaming` avoids it:

```bash
adb -s DEVICE_ID install -r -d --no-streaming \
  build/app/outputs/flutter-apk/app-debug.apk
```

- `-r` reinstall, keeping data
- `-d` allow version downgrade
- `--no-streaming` push the full APK instead of streaming it

### Launch with monkey

`flutter run` is convenient, but to launch an already-installed build directly
use `monkey` (no main-activity name needed):

```bash
adb -s DEVICE_ID shell monkey -p com.voicememory.mobile 1
```

## Run directly with `flutter run`

### Emulator

```bash
# Start an emulator (list available AVDs first)
flutter emulators
flutter emulators --launch <emulator_id>

# Then run on it
flutter run -d emulator-5554
```

### Physical device

```bash
# Confirm the phone is authorized and visible
adb devices

# Run on it (USB debugging enabled, screen unlocked)
flutter run -d DEVICE_ID
```

## Troubleshooting

- **Nothing launches after `monkey`:** you almost certainly used the wrong
  package. It must be `com.voicememory.mobile`.
- **`adb: more than one device/emulator`:** pass `-s DEVICE_ID` (from
  `flutter devices` / `adb devices`).
- **Streaming install failure:** use `--no-streaming` as shown above.
- **`adb: no devices/emulators found`:**
  - Confirm USB debugging is enabled and the cable supports data.
  - Run `adb kill-server && adb start-server`, then `adb devices`.
  - Accept the "Allow USB debugging?" prompt on the phone.
  - For an emulator, launch one via `flutter emulators --launch <id>` first.
- **Huawei install issues:** Huawei/Honor devices are strict about sideloading.
  - On the device: Settings → System & updates → Developer options → enable
    **USB debugging** and **"Install via USB"** (may require a Huawei ID and a
    SIM; toggling it can take a minute and may auto-disable — re-enable it).
  - Set the USB mode to **Transfer files (MTP)**, not "Charge only".
  - Many Huawei devices reject streaming installs — always use
    `--no-streaming` (the helper script and the command above already do).
  - If install still fails, uninstall first:
    `adb -s DEVICE_ID uninstall com.voicememory.mobile`, then reinstall.
  - HMS-only devices (no Google Play) still run debug APKs fine via `adb`.
