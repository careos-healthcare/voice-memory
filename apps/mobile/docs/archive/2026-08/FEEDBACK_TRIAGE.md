# ArchiveMe — Beta feedback triage

How to sort TestFlight feedback while waiting for wider beta. **Do not add product features** during the upload wait — log, triage, fix only blockers.

Feedback channel: **Settings → Testing ArchiveMe? → Send feedback** → `hello@careosapp.co.uk`

---

## Must fix before wider beta

Fix before inviting more testers or public beta.

| Category | Examples |
| --- | --- |
| **Data loss** | Entries disappear after restart, save claimed success but entry missing |
| **Crash / hang** | Launch crash, infinite spinner on save, force-quit required |
| **Capture broken** | Cannot save typed entry; voice save always fails with no fallback |
| **Misleading success** | Empty audio saved as full reflection; fake “transcript” with no content |
| **Trust / safety copy** | Diagnosis, therapy, cure, or medical advice in user-facing UI |
| **Restore / billing crash** | Restore purchases or paywall tap crashes app |
| **Layout blockers** | Overflow hides primary CTA; cannot complete save or answer truth check |

**Action:** reproduce → file issue → fix in focused PR → re-run release suite.

---

## Confusing but acceptable

Log and improve copy or onboarding later; not a blocker for current TestFlight slice.

| Category | Examples |
| --- | --- |
| **Timing expectations** | “Nothing happened after one entry” — point to [THREE_DAY_TEST_SCRIPT.md](./THREE_DAY_TEST_SCRIPT.md) |
| **Gate surprises** | Proof did not appear until third related entry — expected per [KNOWN_LIMITATIONS.md](./KNOWN_LIMITATIONS.md) |
| **Empty states** | Patterns empty at count 0–1 — may be correct |
| **TestFlight billing** | Pro purchase unavailable — explain TestFlight/store setup |
| **Wording preference** | “Felt vague but not wrong” — quote card title for copy iteration |
| **Missing notification** | Reminder not received — known limitation if push off |

**Action:** reply with script/limitations doc; add to copy backlog.

---

## Later

Valid feedback for post-beta roadmap; **do not build during upload wait**.

| Category | Examples |
| --- | --- |
| **Cloud sync** | Sync across devices, account backup |
| **Notifications** | Rich push, reminder scheduling improvements |
| **Android parity** | Feature gaps vs iOS |
| **Export formats** | PDF layout, share cards |
| **Widget polish** | Today check widget enhancements |
| **Onboarding length** | Shorten or personalize first session |
| **Pattern rename UX** | nicer rename flow, not blocking |

**Action:** tag `later` in issue tracker; reference in weekly review.

---

## Do not build yet

Ideas that conflict with current beta scope or protected areas.

| Category | Examples |
| --- | --- |
| **Proof / evidence changes** | Lower thresholds, bypass gates, show proof at 1 entry |
| **New AI surfaces** | Chat expansion, auto-advice, generative coaching |
| **Billing experiments** | New paywall triggers, price tests, RevenueCat refactors |
| **Journal product pivot** | Streaks, daily prompts, mood scores, wellness dashboards |
| **Clinical positioning** | Mental health scores, diagnosis language, outcome claims |
| **Backend scope creep** | New APIs before beta stabilizes |

**Action:** thank tester; explain beta focus; link [BETA_RELEASE_STATUS.md](./BETA_RELEASE_STATUS.md).

---

## Triage workflow (5 minutes per report)

1. **Severity:** crash/data loss → must fix; else continue.  
2. **Repro steps:** entry count, voice vs typed, quoted UI copy.  
3. **Bucket:** must fix / confusing / later / do not build.  
4. **Reply template:** acknowledge + link to 3-day script or known limitations.  
5. **No feature PRs** until TestFlight build is uploaded and first tester wave completes.
