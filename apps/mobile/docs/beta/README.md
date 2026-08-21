# ArchiveMe — Beta documentation

Living materials for TestFlight testers and internal QA.

---

## Living docs

| Doc | Audience | Purpose |
| --- | --- | --- |
| [BETA_RELEASE_STATUS.md](./BETA_RELEASE_STATUS.md) | Team | Current state, priorities, what not to change |
| [MANUAL_QA_CHECKLIST.md](./MANUAL_QA_CHECKLIST.md) | Internal QA | Pre-invite and post-build checklist |
| [KNOWN_LIMITATIONS.md](./KNOWN_LIMITATIONS.md) | Testers + support | Expectation setting |

---

## Suggested TestFlight “What to Test” blurb

> Save small moments when something stands out. ArchiveMe shows what keeps returning. For this beta, save a few real moments, come back when something stands out, and check whether the app shows what returned, changed, or went quiet.

---

## Archived beta materials

Historical tester scripts, triage playbooks, and TestFlight notes live in
[`../archive/2026-08/`](../archive/2026-08/) (e.g. `TESTFLIGHT_NOTES.md`,
`THREE_DAY_TEST_SCRIPT.md`, `FEEDBACK_TRIAGE.md`).

---

## Release quality bar

- Release gates: `npm run release:verify-focused-beta` (see [BETA_RELEASE_STATUS.md](./BETA_RELEASE_STATUS.md))
- Do **not** add features until first beta feedback is triaged

Feedback email: **Settings → Testing ArchiveMe? → Send feedback** → `hello@archiveme.app`
