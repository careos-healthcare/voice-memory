# Quick Text Capture — Test Plan

Minimal QA for typed capture as archive evidence (not journaling).

## Preconditions

- Fresh install or cleared `journal_entries.json` for empty-state checks.
- Device/emulator with network for full analyze path; optional offline pass.

## Manual checks

### 1. Save text thought

1. Open **Record** tab → tap **Type Instead**.
2. Confirm title **What's on your mind?** and single multiline field (no tags, markdown, attachments).
3. Enter a thought (≥ 24 characters for evidence eligibility).
4. Tap **Save Thought** — button disabled when field is empty.
5. Expect return to previous screen without crash; debug log `analytics:quick_text_capture_saved`.

### 2. Archive receives entry

1. Open **Archive** (and **Journal** / **Timeline** if available).
2. Confirm new entry appears with typed transcript text.
3. Entry should not be labeled as a separate “note” type — same presentation as voice reflections.

### 3. Belief engine processes entry

1. With ≥ 5 eligible reflections (transcript ≥ 24 chars each), open Archive V1 view.
2. Confirm belief hero, confidence, and evidence count include the text capture.
3. Add another text capture; confirm archive updates after refresh.

### 4. Evidence trail displays entry

1. From Archive V1, open **Evidence trail** (belief hero tap).
2. Confirm text capture appears in the list with correct excerpt/date.
3. Tap entry → detail shows full transcript.

### 5. No crashes

- Background app during save.
- Airplane mode save (offline draft + sync note).
- Back gesture with text entered → `quick_text_capture_abandoned` once (debug log).

### 6. Empty state works

1. Zero reflections: Archive shows **No recordings yet** with **Record Thought** and **Type Instead**.
2. Record tab (mic ready): same dual actions; voice remains primary (filled), type is outlined.
3. Discover progress card (0 recordings): both actions on gradient card.

## Analytics (debug build)

| Event | When |
|-------|------|
| `quick_text_capture_started` | Screen opens |
| `quick_text_capture_saved` | Successful save (`char_count`) |
| `quick_text_capture_abandoned` | Leave with non-empty text, not saved |

## Automated

```bash
cd apps/voicememory_mobile && flutter test test/capture_pipeline_text_test.dart
```

## Regression

- Voice **Record Thought** flow unchanged.
- Contradictions / blind spots / discover do not branch on `localAudioPath`.
