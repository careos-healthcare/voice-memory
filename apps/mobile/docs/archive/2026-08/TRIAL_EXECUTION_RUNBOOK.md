# ArchiveMe — Trial Execution Runbook (5-user trial)

## Trial goal
Measure whether real users complete the core loop:

> first moment → tomorrow check → return next day → loop closed → useful result

We are testing the **loop**, not the polish. Success = people come back on Day 1
and feel the returned result was useful.

## What we are NOT testing
- Visual design preferences
- Feature requests
- Long-term retention (that is the later 20-user beta)

---

## Participant setup
- 5 participants, each on their own device (TestFlight) or a facilitator device
  running local/trial mode.
- One participant = one clean trial state (reset between participants).

Build options:

```bash
# Local-only trial mode (no login / billing / push required)
flutter run --dart-define=ARCHIVEME_TRIAL_MODE=true

# TestFlight: see docs/TESTFLIGHT_BUILD_NOTES.md
```

---

## Exact facilitator script

### Day 0 (first session, ~3 minutes)
Say, verbatim-ish:

> "This app helps you notice what keeps showing up in your days. I'd like you to
> record one short moment about today — just one sentence. Then it'll give you one
> small thing to check tomorrow. I won't guide you; do what feels natural."

Then stay quiet. Let them drive.

After they finish:

> "Come back tomorrow and the app will ask you one quick question about today."

### Day 1 (return, ~2 minutes)
> "Open the app and do whatever it asks."

Watch whether the due check is obvious, whether they answer quickly, and whether
they record the follow-up moment.

### Day 3 (follow-up, ~3 minutes)
> "Was the thing the app showed you useful, sort of useful, or not useful? Why?"

Capture the quote. Ask what was confusing, if anything.

### What to say
- "Do what feels natural."
- "There are no wrong answers."
- "Say one sentence about today."

### What NOT to say
- Don't explain "patterns", "the loop", or how it works.
- Don't tell them what to record.
- Don't defend the app or talk them out of confusion.
- Don't use internal words: archive, belief, intelligence, evidence, signal,
  prediction, contradiction, discovery, engine, analysis.

---

## How to reset between participants
Use the trial control screen reset, or run the reset path which clears first-loop,
return-day friction, tomorrow check-in, watch-for, pattern memory, progress, next
action, habit proof, weekly recap, reminders, and trial metrics.

Verified by automated test: `test/trial_reset_full_clear_test.dart`.

Steps:
1. Open Settings → developer/trial surfaces (trial build) → Trial control.
2. Tap "Reset for new participant".
3. Confirm the app returns to "Start with one moment".

## How to export the trial summary
1. Open the Trial control screen.
2. Use the export action to copy the markdown summary
   (`TrialSummaryExporter` output) — includes first-loop stage, return-day funnel,
   reminder counts, and rating diagnostics.
3. Paste into the participant's observation note.

## How to record observations
Use `docs/TRIAL_OBSERVATION_TEMPLATE.md` — one copy per participant.

---

## Pass / fail thresholds (across 5 participants)

| Metric | Threshold |
|--------|-----------|
| Open app | 5 / 5 |
| Save first moment | 4 / 5 |
| Choose tomorrow check | 3 / 5 |
| Return next day | 3 / 5 |
| Close loop | 3 / 5 |
| Rate result useful OR sort-of useful | 3 / 5 |
| "Confusing" | under 25% |
| "Did not care" | under 25% |
| "Not useful" | under 30% |

If thresholds are met, see `docs/TRIAL_DECISION_RULES.md` for the next step.

## Before you start (sanity)
Run the execution check:

```bash
./tool/run_trial_execution_check.sh
```
