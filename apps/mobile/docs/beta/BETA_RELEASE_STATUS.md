# ArchiveMe — Beta release status

**Source of truth:** `release/focused_beta_status.json` and `npm run release:verify-focused-beta`.

Last updated: August 2026

---

## Current state

| Item | Status |
| --- | --- |
| **Release manifest** | `release/focused_beta_status.json` |
| **Verification** | Run `npm run release:verify-focused-beta` — exits non-zero while blocked |
| **Focused release suite** | See manifest gate `focused_analyzer_test_suite` (baseline: 269 passed, 15 failed) |
| **Generated summary** | `generated/release-summary.md` |

Do not trust handwritten “all tests passed” claims in legacy docs — gate statuses come from the manifest only.

---

## Current priority

1. Clear blocking gates in `npm run release:verify-focused-beta`.
2. Upload TestFlight / Play internal build after verification passes.
3. Run [MANUAL_QA_CHECKLIST.md](./MANUAL_QA_CHECKLIST.md) on the uploaded build on a physical device.
4. Invite small tester group with [TESTFLIGHT_NOTES.md](./TESTFLIGHT_NOTES.md) and [THREE_DAY_TEST_SCRIPT.md](./THREE_DAY_TEST_SCRIPT.md).
5. Triage feedback using [FEEDBACK_TRIAGE.md](./FEEDBACK_TRIAGE.md).

---

## Related docs

- [README.md](./README.md) — index
- [TESTFLIGHT_NOTES.md](./TESTFLIGHT_NOTES.md) — tester-facing notes
- [KNOWN_LIMITATIONS.md](./KNOWN_LIMITATIONS.md) — expectation setting
- Repo: `release/README.md`, `docs/release/BASELINE_2026-08-12.md`
