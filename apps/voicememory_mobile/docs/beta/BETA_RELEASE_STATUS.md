# ArchiveMe — Beta release status

Snapshot while waiting for Transporter / TestFlight processing. **Documentation and triage only — no new product features.**

Last updated: July 2026

---

## Current state

| Item | Status |
| --- | --- |
| **Release test suite** | Passing |
| **Latest suite run** | **+413 all tests passed** |
| **Cross-test state leakage** | Addressed via `AppServices.resetForTest()` + `test/flutter_test_config.dart` |
| **TestFlight build** | Upload in progress / waiting on Transporter |
| **External testers** | Hold until build processed + manual QA sign-off |

---

## Current priority

1. **Upload TestFlight build** — no build number bump or signing changes in doc-only work.  
2. **Run [MANUAL_QA_CHECKLIST.md](./MANUAL_QA_CHECKLIST.md)** on the uploaded build on a physical device.  
3. **Invite small tester group** with [TESTFLIGHT_NOTES.md](./TESTFLIGHT_NOTES.md) and [THREE_DAY_TEST_SCRIPT.md](./THREE_DAY_TEST_SCRIPT.md).  
4. **Triage feedback** using [FEEDBACK_TRIAGE.md](./FEEDBACK_TRIAGE.md).

---

## Do not do during upload wait

- Add product features or new surfaces  
- Change proof thresholds or evidence gates  
- Change billing, RevenueCat, or restore purchases behavior  
- Change signing, build numbers, IPA, or App Store config  
- Change backend APIs, cloud sync, notifications, or journal storage  
- Run `flutter build` / IPA generation as part of doc tasks  

---

## Protected areas (unchanged)

These remain out of scope for beta-wait polish:

- Proof thresholds and evidence gates  
- Billing / RevenueCat / restore purchases  
- Signing and build numbers  
- IPA / App Store Connect config  
- Backend APIs and cloud sync  
- Push notifications  
- AI chat  
- Journal storage and product logic  

---

## After first tester wave

1. Collect 3-day script results (minimum 3 testers).  
2. Promote **must fix** items from [FEEDBACK_TRIAGE.md](./FEEDBACK_TRIAGE.md).  
3. Re-run release suite before next TestFlight upload.  
4. Only then consider copy fixes or small UX patches — still no threshold/billing changes without explicit decision.

---

## Related docs

- [README.md](./README.md) — index  
- [TESTFLIGHT_NOTES.md](./TESTFLIGHT_NOTES.md) — tester-facing notes  
- [KNOWN_LIMITATIONS.md](./KNOWN_LIMITATIONS.md) — expectation setting  
- Repo: `docs/TESTFLIGHT_CHECKLIST.md`, `docs/TESTFLIGHT_BUILD_NOTES.md` — build/upload runbooks
