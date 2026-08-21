# ArchiveMe — Screenshot Capture Plan

All captures use **screenshot mode**, which seeds deterministic on-device sample
state. Screenshot mode is off unless `VOICE_MEMORY_SCREENSHOT_MODE=true` is passed.

Booted simulator used during development: `iPhone 17 Pro`
(`FD4ABE51-C41F-4A82-9139-616701C87C30`). Substitute your own device id.

## Master flag
```bash
--dart-define=VOICE_MEMORY_SCREENSHOT_MODE=true
```

## Stage flags (combine with the master flag)
| Stage / screen | Flag |
|----------------|------|
| Record view selector | `VOICE_MEMORY_SCREENSHOT_RECORD_VIEW=return_day|post_save|first_session|check_in_due` |
| First-loop stage | `VOICE_MEMORY_SCREENSHOT_FIRST_LOOP_STAGE=start|saved|choosing|ready` |
| Return-day stage | `VOICE_MEMORY_SCREENSHOT_RETURN_DAY_STAGE=due|answered|closed` |
| Journey step (0–3) | `VOICE_MEMORY_SCREENSHOT_JOURNEY_STEP=0|1|2|3` |
| Return capture answer | `VOICE_MEMORY_SCREENSHOT_RETURN_CAPTURE=same|lighter|heavier|changed` |
| Check-in option | `VOICE_MEMORY_SCREENSHOT_CHECK_IN_OPTION=same|lighter|heavier|changed` |

## Capture list

Run pattern (adjust `-d <device-id>`):

```bash
DEVICE=FD4ABE51-C41F-4A82-9139-616701C87C30
SS="--dart-define=VOICE_MEMORY_SCREENSHOT_MODE=true"
```

1. First loop — start
```bash
flutter run -d $DEVICE $SS \
  --dart-define=VOICE_MEMORY_SCREENSHOT_FIRST_LOOP_STAGE=start
```

2. First save / choosing tomorrow's check
```bash
flutter run -d $DEVICE $SS \
  --dart-define=VOICE_MEMORY_SCREENSHOT_FIRST_LOOP_STAGE=choosing
```

3. Loop ready (tomorrow's check is set)
```bash
flutter run -d $DEVICE $SS \
  --dart-define=VOICE_MEMORY_SCREENSHOT_FIRST_LOOP_STAGE=ready
```

4. Return day — due check at top
```bash
flutter run -d $DEVICE $SS \
  --dart-define=VOICE_MEMORY_SCREENSHOT_RECORD_VIEW=check_in_due \
  --dart-define=VOICE_MEMORY_SCREENSHOT_RETURN_DAY_STAGE=due
```

5. Return day — answered (record-one-moment CTA) and closed (loop closed)
```bash
flutter run -d $DEVICE $SS --dart-define=VOICE_MEMORY_SCREENSHOT_RETURN_DAY_STAGE=answered
flutter run -d $DEVICE $SS --dart-define=VOICE_MEMORY_SCREENSHOT_RETURN_DAY_STAGE=closed
```

6. Post-save progress (full payoff stack)
```bash
flutter run -d $DEVICE $SS \
  --dart-define=VOICE_MEMORY_SCREENSHOT_RECORD_VIEW=post_save
```

7. Patterns — weekly recap / share (open the Patterns tab in screenshot mode)
```bash
flutter run -d $DEVICE $SS \
  --dart-define=VOICE_MEMORY_SCREENSHOT_RECORD_VIEW=first_session
```

To grab the frame from a booted simulator:
```bash
xcrun simctl io booted screenshot ~/Desktop/archiveme_<name>.png
```

## Required App Store screenshot sizes (placeholders — confirm at upload)
- 6.9" iPhone (e.g. 16/17 Pro Max): 1320 × 2868 px  — REQUIRED
- 6.5" iPhone: 1242 × 2688 px (or 1284 × 2778) — REQUIRED if 6.9" not provided
- 6.7" iPhone: 1290 × 2796 px — optional/recommended
- 13" iPad Pro: 2064 × 2752 px (or 2048 × 2732) — REQUIRED only if iPad supported

Provide 3–10 screenshots per required size. Recommended order:
1, 3, 4, 6, 7 (start → loop ready → return day → progress → weekly recap).
