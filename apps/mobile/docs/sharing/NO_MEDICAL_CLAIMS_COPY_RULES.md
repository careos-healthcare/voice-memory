# No medical claims — copy rules

ArchiveMe helps people notice **patterns in moments they saved**. It must never present itself as care, assessment, or clinical documentation.

## Allowed consumer copy

| String | Use |
| --- | --- |
| Share only what you choose. | Consent / control |
| A private report may help you explain a pattern to someone you trust. | Future sharing adjacency |
| ArchiveMe does not diagnose, treat, or replace professional support. | Disclaimer |
| You stay in control of what is included. | Consent / control |
| Future sharing should be explicit, private, and reversible. | Future feature framing |

Additional safe patterns:

- "someone you trust"
- "saved moments", "evidence", "pattern"
- "may", "planned", "future" for unshipped features

## Banned strings (never in product copy)

| Banned | Why |
| --- | --- |
| therapy | Clinical adjacency |
| therapist dashboard | Implies live clinical product |
| clinical report | Medical document framing |
| diagnosis | Regulatory / trust |
| treatment | Regulatory / trust |
| mental health assessment | Assessment claim |
| medical record | HIPAA-adjacent framing |
| care plan | Care delivery claim |
| doctor-ready diagnosis | Combined medical claim |

## Enforcement

- Canonical lists: `SafeSharingCopy.bannedTerms` and `SafeSharingCopy.allVisibleStrings()` in Dart
- Tests: `test/safe_sharing_copy_test.dart`
- Cross-check: `RevenueValueCopy.bannedMedicalTerms` for revenue surfaces

## Review checklist (before any sharing UI ships)

- [ ] No banned term in any visible string
- [ ] Future features labeled future/planned
- [ ] User preview step before any send
- [ ] Disclaimer visible near share action
- [ ] No "automatically shared" language
