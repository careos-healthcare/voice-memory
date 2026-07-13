# Beta decision system

Lightweight release aid for choosing the next development branch from real tester behaviour.

**This is not a user-facing product expansion.** It is a measurement and prioritization tool for founders and beta operators.

## Core V1 sentence

> Record one real moment. Return when it happens again. ArchiveMe shows what repeated, changed, faded, or corrected. Pro keeps the longer trail.

## Rule

Build only the **highest-priority failing branch**. Do not build Ask Archive, monthly reports, loop packs, extra wedges, Android, or B2B until V1 beta proof passes.

## 5-person test script

Run with 5 testers before changing product surface:

1. Send invite with no positioning beyond the core V1 sentence.
2. Watch silently for the first 2 minutes — do not coach.
3. Ask the seven questions below.
4. Log signals in `BetaTesterOutcome` via **Testing ArchiveMe → Log tester outcome** (saved locally on device).
5. Run `BetaDecisionEngine.build(outcomes: ...)` for the cohort recommendation.
6. Ship **one** fix matching the primary recommendation. Re-test with 5 more people.

## 20-person beta threshold

Before any expansion build (history/export/report utilities, return challenge, new wedges):

- Complete at least one 5-person round
- Reach **20 logged tester outcomes** OR explicit founder sign-off
- Pass expansion gate: **3+ testers cared about proof** OR **2+ explicitly asked for history/export/report**

Until then, measurement and copy fixes only.

## Interview questions (exact)

1. What do you think this app does?
2. What would you record here?
3. Did "Save one real moment" make sense?
4. Did "1 Save → 2 Compare → 3 First thread" help?
5. Would you come back when the same thing happens again?
6. What felt confusing?
7. Would you pay to keep the longer proof trail if it showed you something true?

## Signal mapping (quick reference)

| Observation | Signal |
|-------------|--------|
| Cannot explain ArchiveMe after 2 min | missing `understoodPromise` |
| Calls it journal / chatbot / therapy / task manager | `misunderstoodAsGenericJournal` / `misunderstoodAsChatbot` / `misunderstoodAsTherapy` |
| Understands but never taps Record/Type | missing `tappedRecord` |
| Does not know what to write | `confusedWhatToWrite` |
| Hesitates at mic permission | `hesitatedAtCapture` |
| Saves first moment | `savedFirstMoment` |
| No day-2 return | missing `returnedDay2` |
| Wants reminder | `askedForReminder` |
| Reaches 3 moments or first thread | `reachedThreeMoments` / `sawFirstProof` |
| Proof correct but not meaningful | missing `proofFeltMeaningful` |
| Would keep using, won't pay | missing `willingToPayForLongerTrail` |
| Asks for older proof / export / monthly report | `askedForHistory` / `askedForExport` / `askedForReport` |

## Decision tree (priority order)

### A. Users do not understand the app

**Recommendation:** Fix Record/onboarding copy only.

**Signals:**
- User cannot explain what ArchiveMe does after 2 minutes
- User thinks it is a generic journal, chatbot, therapy app, or task manager
- User cannot explain why they would save a moment here

### B. Users understand but do not record

**Recommendation:** Fix capture friction.

**Signals:**
- User understands the promise
- User does not tap Record or Type
- User says they do not know what to write
- User hesitates at voice permission
- User looks for a simpler typed entry

### C. Users record once but do not return

**Recommendation:** Build three-day proof challenge or return reminder.

**Signals:**
- User saves first moment
- User does not come back day 2
- User says they forgot
- User says they need a reason to return
- User wants a gentle reminder

### D. Users reach proof but do not care

**Recommendation:** Fix proof card emotional clarity.

**Signals:**
- User reaches 3 real moments or first thread
- User says the proof is technically correct but not meaningful
- User does not feel an aha moment
- User says "so what?"

### E. Users care but will not pay

**Recommendation:** Fix Pro packaging.

**Signals:**
- User says the archive noticed something true
- User says they would keep using it
- User says they would not pay
- User does not understand "longer trail"

### F. Users ask for history/export/report

**Recommendation:** Expand Pro utility.

**Signals:**
- User asks to see older proof
- User asks for export
- User asks for monthly report
- User asks for archive history
- User asks to search when something happened before

**Expansion gate:** Only recommend F when at least 3 testers cared about proof **or** 2 testers explicitly asked for history/export/report. If users ask for reports before proof feels meaningful, hold — do not build expansion yet.

## Implementation

- Model: `lib/features/beta_decision/beta_decision_model.dart`
- Engine: `lib/features/beta_decision/beta_decision_engine.dart`
- Copy: `lib/features/beta_decision/beta_decision_copy.dart`
- Tests: `test/beta_decision_engine_test.dart`
- Internal surface: `BetaTesterOutcomeLogCard` + `BetaNextBuildDecisionCard` on `/testing-archiveme` (beta mission gate only)

## Blocked until V1 beta proof passes

See `docs/V1_EXPANSION_GATES.md` — do not ship Ask Archive, private monthly reports, loop packs, full three-day challenge UI, new top-level tabs, Android expansion, or B2B as live consumer surfaces.
