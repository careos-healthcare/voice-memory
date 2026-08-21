# Running ArchiveMe on iOS

Workflow for running the iOS app and capturing App Store screenshots on the
iPhone simulator.

## Project folder

Open / run from the mobile app folder:

```
~/Projects/voice-memory-clean/apps/mobile
```

> **Use the workspace, not the project.** When opening in Xcode, open
> `ios/Runner.xcworkspace` — **never** `ios/Runner.xcodeproj`. CocoaPods wires
> dependencies through the workspace; the bare project will fail to build.

## Screenshot mode (iPhone simulator)

Run with screenshot mode enabled so surfaces render with sample data and the
session check passes without a local backend:

```bash
flutter run -d FD4ABE51-C41F-4A82-9139-616701C87C30 \
  --dart-define=VOICE_MEMORY_SCREENSHOT_MODE=true
```

`FD4ABE51-C41F-4A82-9139-616701C87C30` is the default iPhone simulator udid.
List your own with `flutter devices` or `xcrun simctl list devices`.

Or use the helper script (same default device):

```bash
./tool/run_ios_screenshot.sh
./tool/run_ios_screenshot.sh -- --dart-define=VOICE_MEMORY_SCREENSHOT_KEY_MOMENTS=true
```

## Useful screenshot flags

Add these as extra `--dart-define` flags alongside
`VOICE_MEMORY_SCREENSHOT_MODE=true`:

| Flag | Effect |
| --- | --- |
| `VOICE_MEMORY_SCREENSHOT_KEY_MOMENTS=true` | Show the Key Moments timeline with sample days |
| `VOICE_MEMORY_SCREENSHOT_PATTERN_MAP=true` | Show one filled-in Pattern Map |
| `VOICE_MEMORY_SCREENSHOT_INPUT_QUALITY=vague` | Render the "Early read" / vague-input variant |
| `VOICE_MEMORY_SCREENSHOT_LANGUAGE=es\|fr\|hi\|gu` | Render localized copy (Spanish, French, Hindi, Gujarati) |

Example combining flags:

```bash
flutter run -d FD4ABE51-C41F-4A82-9139-616701C87C30 \
  --dart-define=VOICE_MEMORY_SCREENSHOT_MODE=true \
  --dart-define=VOICE_MEMORY_SCREENSHOT_PATTERN_MAP=true \
  --dart-define=VOICE_MEMORY_SCREENSHOT_LANGUAGE=es
```

## Hot restart

To apply changes while `flutter run` is active, press uppercase **`R`** (hot
restart) in the terminal running `flutter run`. Lowercase `r` is hot reload.

> The uppercase `R` only works **inside an active `flutter run` session**. It
> does nothing in a separate shell — type it into the terminal that is currently
> running the app.

## Troubleshooting

- **No simulator found:** open one with `open -a Simulator`, or boot a specific
  device: `xcrun simctl boot 'iPhone 15 Pro'`, then re-check `flutter devices`.
- **Pods / build errors:** from `ios/`, run `pod install`, and make sure you are
  opening `Runner.xcworkspace`.
- **Stale screenshot state:** fully quit the app in the simulator and re-run so
  the new dart-defines take effect (defines are compile-time, not hot-reloadable).
