# ArchiveMe mobile — 5-user activation trial

## Purpose

We are testing whether a person records once, accepts a specific tomorrow watch-for, returns next day, and finds the result useful.

**Trial question:** Will users record once, accept a specific watch-for, return tomorrow, and find the result useful?

## Setup

From the mobile app directory:

```bash
cd apps/voicememory_mobile
./tool/run_trial_mode.sh
```

Optional device id:

```bash
./tool/run_trial_mode.sh FD4ABE...
```

This runs with `--dart-define=ARCHIVEME_TRIAL_MODE=true` (local-only, Record-first, onboarding skipped).

## Reset checklist (between participants)

1. Open **Developer diagnostics** (facilitator device only; developer gate unlocked).
2. Open **Trial control** (`/trial-control`).
3. Tap **Reset for new participant**.
4. Enter and save **Participant ID** (e.g. `P1`, `P2`).

Hand the device to the participant after reset.

## Facilitator script

**Say:**

> Use this like a private reflection app. Record one ordinary moment from today. Tomorrow, open it again and answer whether the thing it asks about showed up.

**Do not say:**

- “AI”
- “archive”
- “belief”
- “therapy”
- “journaling app”
- “this will understand you”

## Pass / fail thresholds (5 participants)

### Promising cohort

- **4/5** save first reflection
- **3/5** accept tomorrow watch-for
- **2/5** return next day
- **2/5** rate useful or sort of useful

### Weak cohort

- Fewer than **3/5** save first reflection
- Fewer than **2/5** accept watch-for
- **0–1/5** return next day

Per-participant hook verdict (`promising` / `weak` / `unclear`) is computed in **Trial control** export. Friction verdict flags permission, record, or hook issues for debugging.

## Export

After ~3 days (or end of session):

1. **Trial control** → refresh summary.
2. **Copy JSON** or **Copy Markdown** for the cohort spreadsheet.
3. Use the notes section in Markdown for qualitative notes.

## Notes template

```
Participant:
What confused them:
Did they accept watch-for:
Did they return:
Useful rating:
Raw quote:
```

## Trial control metrics

**Hook metrics:** first reflection, pattern shown/accepted/corrected, watch-for shown/accepted, return capture, next-day return, comparison, usefulness, reflection milestones.

**Friction metrics:** app opened, record CTA tapped, recording started/saved, mic denied, save completed, closed before watch-for accepted.

**Friction verdicts:** `clean`, `permissionIssue`, `recordFriction`, `hookIssue`, `unclear`.
