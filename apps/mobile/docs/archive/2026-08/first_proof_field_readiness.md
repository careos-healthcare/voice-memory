# First proof field readiness v1

> Canonical doc: `docs/architecture/first_proof_field_readiness.md` · Code: `lib/features/first_proof_field_readiness/`


Measure whether first proof succeeds with real testers **without loosening proof thresholds**. Beta-readiness measurement and repair routing only.

## Decisions

| Decision | Meaning |
| --- | --- |
| `insufficientCapture` | Tester has not saved 3 usable moments |
| `repairAnchorSafety` | Proof surfaced without a safe anchor |
| `repairProofClarity` | Proof too vague or why-it-appeared unclear |
| `repairProofRelevance` | Proof felt not relevant |
| `repairProofStrength` | `watch_only` appeared instead of useful/strong proof |
| `repairSaveNextGuidance` | Tester did not understand what to save next |
| `repairWhyAppeared` | Tester did not understand why proof appeared |
| `fieldReady` | First proof passes for this tester |
| `needsManualReview` | Mixed or incomplete signals |

## Signals (10)

1. User saved 3 usable moments
2. Strong proof appeared
3. `watch_only` appeared instead
4. No safe anchor
5. Proof accepted
6. Proof corrected
7. Proof too vague
8. Proof not relevant
9. User understood why it appeared
10. User understood what to save next

## Key rules

- **Do not loosen anchors**
- **Do not expand proof volume**
- **Do not change thresholds** (`minProofEntryCount` stays 3)
- Route repairs to existing capture, explanation, and relevance modules only

## Decision order

Earliest blocker wins:

1. Insufficient capture (< 3 usable moments)
2. No safe anchor
3. Proof too vague
4. Proof not relevant
5. `watch_only` instead of useful/strong proof
6. Did not understand what to save next
7. Did not understand why it appeared
8. All pass → `fieldReady`

## Repo signal bridge

`FirstProofFieldReadiness.fromRepoSignals()` verifies protected threshold constants in:

- `archive_evidence_quality_gate.dart` (`minProofEntryCount = 3`)
- `beta_readiness_engine.dart` (guards against threshold drift)

## Code modules

- Engine: `lib/features/first_proof_field_readiness/first_proof_field_readiness.dart`
- Copy: `lib/features/first_proof_field_readiness/first_proof_field_readiness_copy.dart`
- Tests: `test/first_proof_field_readiness_test.dart`

## Run tests

```bash
cd apps/mobile
flutter test test/first_proof_field_readiness_test.dart
```
