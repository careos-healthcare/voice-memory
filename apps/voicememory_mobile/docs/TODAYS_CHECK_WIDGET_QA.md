# Today\u2019s Check Widget — Manual QA

ArchiveMe keeps one useful check ready on the home screen.

## Android manual QA

1. Build and install debug APK:
   ```bash
   flutter build apk --debug
   ```
2. Open ArchiveMe and complete first loop if needed.
3. Set a tomorrow check or view Today\u2019s check on Record/Patterns.
4. Long-press home screen → Widgets → find **Today\u2019s check from ArchiveMe**.
5. Add the widget to the home screen.
6. Confirm widget shows:
   - title (e.g. Today\u2019s check)
   - one-line body
   - optional check question (when due)
   - action label (e.g. Answer check / Open)
7. Tap widget → app opens (Record tab when route is `/record`).
8. Complete or change the check in app → widget updates after objective card shows.
9. Trial reset (Trial Control screen) → widget clears or shows safe default copy.
10. Airplane mode → widget shows last cached snapshot; no crash.

## iOS manual QA

See also [`IOS_WIDGETKIT_SETUP.md`](IOS_WIDGETKIT_SETUP.md) for one-time Xcode target setup.

1. Enable App Group **`group.com.voicememory.app`** in Apple Developer portal.
2. Open `ios/Runner.xcworkspace` and confirm TodayCheckWidget extension target exists.
3. Enable App Groups on Runner + widget extension (same group id).
4. Build to device:
   ```bash
   flutter build ios --debug --no-codesign
   ```
   Or archive from Xcode with valid signing.
5. Install on device → long-press home screen → **Today\u2019s check**.
6. Open ArchiveMe → create or view next check on Record/Patterns.
7. Confirm widget updates (title, body, optional check question, action label).
8. Tap widget → app opens to Record (`archiveme://record` → `/record`).
9. Complete or change check → widget updates after objective card shows.
10. Trial reset → widget shows safe default:
    - title: Today\u2019s check
    - body: Open ArchiveMe to continue.
    - action: Open

### iOS troubleshooting

| Symptom | Likely cause |
|---|---|
| Widget not in gallery | Widget extension target missing or not embedded |
| Default copy only | App Group not shared between Runner and extension |
| Widget stale after check change | Timeline refresh delay; reopen app or wait ~1 min |
| Tap opens app but wrong screen | URL scheme or pending route not captured |
| TestFlight widget delayed | Normal iOS caching; reinstall widget after update |

## Privacy checks

- No reflection transcript on widget.
- No long private text — only capped title/body/check question.
- Only one action visible.

## Known limits

- Single small widget layout only (no medium/large variants yet).
- `objectiveWidgetOpenedCount` not tracked until native tap telemetry is wired.
- Route-specific launch depends on `consumePendingWidgetRoute` + app router.
- iOS widget extension target must be added once in Xcode (see setup doc).

## TODO

- Optional widget tap analytics (`objectiveWidgetOpenedCount`)
