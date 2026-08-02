# Archive Growth Loop V1 — Validation

## 1. What happens after recording #1?

- **Archive Journey Day 1** unlocks on the archive home banner and `/archive-journey`.
- User sees one **observation** from their first reflection (`concreteObservation`, tension, or repeated signal).
- **Archive Maturity** stays **Seed**; **Archive Confidence** shows a low score with “The archive is still gathering evidence.”

## 2. What happens after recording #3?

- **Day 3** journey step unlocks (by count or elapsed days).
- First **recurring pattern** reward, e.g. “You have mentioned \"work\" 3 times.”
- Maturity still **Seed** until 10 recordings; confidence may rise slightly with more evidence.

## 3. What happens after recording #7?

- **Day 7** unlocks; if V1 is available, **change feed** or **surprises** drive the reward (e.g. theme decreasing).
- Without V1 baseline, fallback: “Your archive now spans a week of reflections.”
- User may see **shareable discoveries** if patterns/contradictions exist (`/archive-share`).

## 4. Why would someone return next month?

- **Monthly review email** (signed-in + synthesis cached) summarizes strongest theory, biggest change, and surprise with a link back.
- **Archive Maturity** progression (Growing → Established → …) shows tangible depth.
- **Archive Confidence** explanation shifts to “enough evidence to detect recurring patterns” as the archive strengthens.
- Existing **change feed**, **theory**, and **GPT-5 monthly synthesis** (Pro) compound — growth loop surfaces them, does not replace them.

## 5. Why would someone share ArchiveMe?

- **Archive Share Cards** export PNG moments: belief shift, contradiction, pattern, surprise, milestone.
- Cards use trust framing (“The archive noticed”) and **ArchiveMe** footer — credible, not gamified.
- Wording is derived from real archive engines (then/now, contradictions, themes), not generic social templates.

## Success criteria checklist

| Persona | Expected experience |
|---------|---------------------|
| Fresh install | Day 1 observation on first recording |
| 10+ recordings | **Growing** maturity + next milestone (“N until Established”) |
| 50+ recordings | **Established**+ maturity on home, paywall, account |
| Has discoveries | Share PNG from `/archive-share` |
| Inactive 30d + signed in | Monthly email from synthesis cache via internal send API |

## Test commands

```bash
cd apps/voicememory_mobile && flutter test test/archive_growth_test.dart
```

Internal email dry-run (founder token):

```bash
curl -X POST https://<host>/api/internal/archive-monthly-review \
  -H "x-vm-debug-token: $VM_DEBUG_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"email":"you@example.com","archiveUrl":"https://archiveme.app/archive","dryRun":true,"review":{...}}'
```
