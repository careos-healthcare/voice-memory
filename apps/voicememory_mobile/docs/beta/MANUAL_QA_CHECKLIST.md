# ArchiveMe — Manual QA checklist (TestFlight beta)

Use this before inviting external testers or after each TestFlight build. Check boxes; note device model and iOS version on failures.

**Build context:** local-first beta, no feature changes during upload wait.  
**Do not file** proof-threshold or evidence-gate bugs as “fix now” unless they cause crashes or data loss — see [FEEDBACK_TRIAGE.md](./FEEDBACK_TRIAGE.md).

---

## Install and first run

- [ ] **Fresh install** — delete prior build, install from TestFlight  
- [ ] App launches without crash  
- [ ] Onboarding skippable or completable  
- [ ] Record screen loads with one clear primary CTA  
- [ ] No duplicate primary CTAs on Record  

---

## Capture

- [ ] **First typed save** — Type instead → save → post-save receipt visible  
- [ ] **First voice save** — mic permission flow → save → transcript or clear fallback  
- [ ] **Degraded transcript fallback** — if transcription fails, user sees honest fallback (not fake “saved privately” as main content) + option to type what they said  
- [ ] Empty/tiny audio rejected without fake success toast  

---

## Evidence loop (use 2–3 related typed entries for speed)

- [ ] **2 related entries** — early repeat / watch signal may appear (cautious copy)  
- [ ] **3 related entries** — **first proof** may appear  
- [ ] **Truth follow-up** — yes / sort of / no saves and dismisses appropriately  
- [ ] Copy uses **may** language — no diagnosis or therapy claims  

---

## Patterns and review

- [ ] **Pattern correction** — correction options reachable when gated  
- [ ] **Pattern detail** — opens, shows evidence snippets, no fake advice  
- [ ] **Quiet signal** — may appear after watch + unrelated saves; dismiss/keep watching works  
- [ ] **What Changed v2** — prompt may appear on return; choices save  
- [ ] **Review inbox** — lists review items or clear empty state  

---

## Beta surfaces

- [ ] **Beta mission** — visible when enabled; dismiss/completion safe  
- [ ] **Beta feedback** — Settings → Testing ArchiveMe? → Send feedback opens mail  
- [ ] **Private report preview** — renders without leaking other users’ data (local only)  

---

## Settings and billing (visibility only — do not change product logic)

- [ ] **Settings** — account, privacy, support links load  
- [ ] **Restore purchases** button **visible** and **safe** (no crash; clear if unavailable on TestFlight)  
- [ ] Pro / paywall copy does not claim active subscription on TestFlight  

---

## Copy and trust

- [ ] **No fake advice/diagnosis copy** — scan Record, post-save, Patterns for clinical or “you should heal” language  
- [ ] **No duplicate CTAs** on Record, post-save, or pattern cards  
- [ ] Banned first-impression terms absent at entry count 0–1 (no “journal”, streak guilt, progress homework)  

---

## Persistence and controls

- [ ] **App restart keeps data** — force-quit → reopen → entries remain  
- [ ] **Delete/exclude controls work** — exclude entry or delete does not corrupt archive  
- [ ] Local backup/restore path sanity (if exposed in Settings)  

---

## Sign-off

| Field | Value |
| --- | --- |
| Tester | |
| Date | |
| Build (TestFlight #) | |
| Device | |
| iOS version | |
| Pass / fail | |
| Blockers | |

Related: [THREE_DAY_TEST_SCRIPT.md](./THREE_DAY_TEST_SCRIPT.md) · [KNOWN_LIMITATIONS.md](./KNOWN_LIMITATIONS.md)
