# Start Here Recording Flow V1

Reduces blank-page anxiety with tappable prompts above the record CTA.

## UI

**Section title:** `Start Here`

**Options (full-width tappable rows):**

1. What happened today?
2. What's bothering you?
3. What are you excited about?
4. What are you thinking about right now?

**After first archive milestone:** section is replaced by:

`Continue building your archive.`

## Tap behavior

| Surface | On tap |
|---------|--------|
| **Record** (`/record`) | Sets selected prompt (shown while recording), **starts voice recording** when mic is ready |
| **Quick text** (`/quick-capture`) | **Prefills** the text field with the prompt |
| **Type instead** (from Record) | Opens quick capture with the last selected Start Here prompt via route `extra` |
| **Empty archive / search empty** | Navigates to `/record?prompt=…&autostart=1` |

## Visibility logic

Implemented in `StartHereVisibility` (delegates to `ExamplePromptVisibility`):

| Condition | Start Here shown? |
|-----------|-------------------|
| `recordingCount >= patternReviewReflectionTarget` (default **5**) | No |
| `ArchiveValueProgress.readyForPatternReview` (first archive milestone) | No |
| Otherwise | Yes |

First archive milestone = same as pattern-review unlock (`AppConfig.patternReviewReflectionTarget` eligible reflections with evidence).

## Analytics

| Event | When | Parameters |
|-------|------|------------|
| `start_here_shown` | Section renders with prompts visible | `surface` |
| `start_here_selected` | User taps an option | `prompt_text`, `surface`, `capture_mode` (`voice` \| `text`) |

## Files

| Piece | Path |
|-------|------|
| Copy | `lib/record/start_here_catalog.dart` |
| Visibility | `lib/record/start_here_visibility.dart` |
| Analytics | `lib/record/start_here_analytics.dart` |
| Widget | `lib/widgets/record/start_here_recording_section.dart` |
| Empty-state loader | `lib/widgets/record/start_here_loader.dart` |

## Screenshots

```bash
cd apps/voicememory_mobile
./tool/run_ui_screenshot_audit.sh
# Or on device: Record tab with <5 reflections, mic ready
```

Suggested captures:

- `record_start_here_ready.png` — Start Here + Record / Type CTAs
- `record_start_here_recording.png` — selected prompt visible while recording
- `record_start_here_continue.png` — after milestone, continue message only

Update `integration_test/production_ui_verify_test.dart` to snapshot Start Here when applicable.

## Tests

```bash
cd apps/voicememory_mobile
flutter test test/start_here_recording_test.dart
```
