# Focused V1 return experience QA

Run on a clean install and again with an existing archive.

## First moment

- Onboarding shows one promise and Record/Type choices.
- Saving shows Saved before the editable transcript.
- At most one “Possible read” appears after the transcript.
- Its exact quote, full local date, source type, evidence count, uncertainty,
  alternative, source action, and four correction controls are visible.
- Invalid or absent evidence shows the explicit no-conclusion state and one
  useful next question.
- Only one next action is present. No graph, analyst, blind-spot,
  contradiction, milestone, or card-pile action appears.
- Editing the transcript invalidates stale quote offsets and never leaves a
  mismatched receipt visible.

## Second moment and Changes

- Two unrelated moments show no comparison.
- Two related, distinct moments may show one Possible repeat or Possible
  change.
- Then precedes Now; entry IDs and exact quotes differ; both full dates and
  source actions are correct.
- Changes opens with “See what changed” and the required supporting line.
- Timeline order is chronological and the detail receipt matches the source
  moments.
- Accurate, Wrong angle, Too generic, and Hide survive app restart.

## Commercial behavior

- First valid observation and first valid comparison are available before any
  paywall.
- Original moments, transcripts, corrections, evidence sources, and existing
  generated results remain readable when free, expired, offline, or after a
  restore failure.
- New ongoing generation follows the central Pro/usage decision and uses only
  localized store prices.

## Privacy and accessibility

- Remote transcription disclosure appears immediately before first remote use.
- No plaintext recording remains after vault persistence or failure cleanup.
- Analytics inspection contains no transcript, quote, conclusion, correction,
  entry ID, date, filename, or audio.
- Repeat the flow in light and dark mode.
- Repeat at 200% text scale without clipping or horizontal overflow.
- VoiceOver/TalkBack reads Saved → Transcript → interpretation → evidence →
  uncertainty → correction → next action.
- Then/Now, quote boundaries, full dates, source types, audio timestamps, and
  control states are announced without relying on color.
