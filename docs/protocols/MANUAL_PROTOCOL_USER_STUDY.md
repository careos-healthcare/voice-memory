# Manual protocol — 25-user test

Part of [`MANUAL_TEST_PROTOCOLS.md`](MANUAL_TEST_PROTOCOLS.md). Not executed.

---

## 1. 25-user test

```text
Result:        NOT EXECUTED
Run by:        NOT EXECUTED
Date:          NOT EXECUTED
Build SHA:     NOT EXECUTED
App version:   NOT EXECUTED
Participants:  NOT EXECUTED
Evidence:      NOT EXECUTED
Per-step:      NOT EXECUTED
```

**No participant has been recruited, enrolled, or observed. There is no user
data, no completion rate, and no satisfaction figure anywhere in this
repository. Any number quoted as coming from this protocol is fabricated.**

### Purpose

Find out whether twenty-five people who are not the author can install the app,
capture a moment, understand what came back, and come back a second day —
without anyone sitting next to them.

### What the app collects, and what it does not

Participation runs through the study mode in
`apps/voicememory_mobile/lib/features/study_mode/`. It is opt-in, it is
revocable from the same screen, and it collects counts only. The export a
participant sends back contains signal totals, a distinct-day count, structured
feedback (topic, a 1–5 ease rating, one blocker token), a count of private
notes, the consent policy version, and the build SHA. It contains no recording,
no saved words, and no note text: the builder in `study_export.dart` rejects any
value containing a space before it returns.

Notes a participant types stay on their own device. If you want them, you must
ask the participant to read them to you or send them deliberately. Do not treat
the absence of notes in an export as the absence of notes.

### Preconditions

1. Twenty-five participants recruited, none of whom built the app, and none of
   whom have seen it before. Record how they were recruited — a sample drawn
   from friends is a finding about friends.
2. A study build installed through TestFlight (protocol 14) or Play Internal
   testing (protocol 15). Both of those protocols are themselves
   `NOT EXECUTED`; this one cannot start before they pass.
3. The build compiled with `STUDY_BUILD_SHA` set. A participant export reporting
   `"identified": 0` cannot be attributed to a revision and does not count.
4. A participant code per person, matching `^[A-Z0-9][A-Z0-9-]{1,11}$` — for
   example `P-01` through `P-25`. Codes are assigned by the run owner and are
   not names, emails, or initials.
5. A written recruitment message stating that participation is optional, that
   only counts are collected, and that leaving deletes what was collected.

### Steps

1. Send each participant their code and the install link. Send nothing else: no
   tutorial, no explanation of what the app is for, no walkthrough. If a
   participant needs a private explanation to get started, record that as a
   failure of step 3, not as a setup detail.
2. Participant installs and opens the app. Do not watch, screen-share, or
   prompt. The run owner records only that the install happened.
3. Participant reaches the first capture screen unaided. The run owner records
   whether they did, from the participant's own account of it. **Pass criterion
   for this step: at least 20 of 25 reach capture without asking a question.**
4. Participant is shown the study consent screen and either joins or declines.
   The screen must present all five statements from
   `StudyConsentPolicy.statements` before consent is taken; a participant who
   acknowledges fewer cannot be enrolled, and the mode enforces this by throwing
   `StudyEnrolmentRefusal.statementsNotAcknowledged`. Declining is a valid
   outcome and must be recorded, not retried.
5. Participant uses the app for seven consecutive days with no reminder from the
   run owner other than the app's own behaviour.
6. On day 7, each enrolled participant submits at least one structured feedback
   answer in the app: a topic, an ease rating of 1–5, and one blocker.
7. On day 7, each enrolled participant sends their study export. Record the
   `participant.ref` from each export — it is a stable one-way handle that lets
   you match repeat submissions from the same person without holding anything
   that identifies them.
8. Run a 15-minute call with each participant who did not return after day 1,
   and record the reason in their words. Do not aggregate these into a
   percentage; there are too few to support one.
9. Any participant who asks to leave does so from the same screen they joined
   from. Confirm their counts, feedback, and notes are gone from their device
   and that they can still use the app normally. Refusing or delaying a
   withdrawal fails the whole protocol.
10. Collate the twenty-five exports. Verify every export names the same build
    SHA. A mixed-build cohort is not one result and must be reported as two.

### Pass criteria

All of the following, measured from the exports and the day-7 calls:

- 25 participants enrolled, or a recorded reason for every shortfall.
- ≥ 20 of 25 reach capture unaided (step 3).
- ≥ 20 of 25 record at least one `capture_completed` signal on day 1.
- ≥ 10 of 25 record an `active_day_count` of 2 or more.
- ≥ 20 of 25 submit a structured feedback answer.
- Median ease rating ≥ 3.
- Zero participants report a privacy concern as their blocker
  (`privacy_concern`). One is a failure, not a rounding error.
- Every export reports `"identified": 1` and the same `build.sha`.
- Every export reports `consent.policy_version` equal to
  `study_consent_v1_2026_08_01`.

### Fail criteria

Any one of these fails the protocol outright:

- Any participant's export contains a word they spoke or typed into the app.
- Any participant reports being unable to leave the study.
- Any participant sees another participant's or another account's data.
- Counts arrive from a participant who never granted consent.
- Fewer than 20 participants complete day 1.
- The run owner coached, reminded, or prompted a participant in a way not listed
  in the steps above.

### Evidence required

Twenty-five export files, the recruitment message as sent, the day-7 call notes,
and the build SHA. Without all four, the result stays `NOT EXECUTED`.
