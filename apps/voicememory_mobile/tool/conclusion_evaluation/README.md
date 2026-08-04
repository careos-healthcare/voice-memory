# Conclusion evaluation harness

Measures whether ArchiveMe's conclusions actually follow from the evidence they
cite. It runs the real production pipeline — nothing here re-implements the
engine — over a synthetic fixture set and scores the results.

**All data in `fixtures/` is synthetic. There are no human labels yet
(`human_labels/` is empty). No number produced here supports a product claim.**

## Running it

From `apps/voicememory_mobile`:

```bash
dart run tool/conclusion_evaluation/generate_candidates.dart
dart run tool/conclusion_evaluation/score_evaluation.dart
```

Artifacts land in `build/conclusion_evaluation/` (`candidates.json`,
`scores.json`).

Useful flags:

| Flag | Script | Default |
| --- | --- | --- |
| `--fixtures=<dir>` | generate | `tool/conclusion_evaluation/fixtures` |
| `--out=<file>` | generate | `build/conclusion_evaluation/candidates.json` |
| `--in=<file>` | score | `build/conclusion_evaluation/candidates.json` |
| `--out=<file>` | score | `build/conclusion_evaluation/scores.json` |
| `--thresholds=<file>` | score | `tool/conclusion_evaluation/thresholds.json` |
| `--enforce` | score | off — exits 1 when an enforced threshold is breached |

For CI, add `--enforce`. Without it the scorer always exits 0 and only reports.

## What the runner does per case

1. Builds `JournalEntry` values from the fixture and calls
   `AuditablePersonalChangeEngine.areRelated` for the pairing decision.
2. Calls `AuditablePersonalChangeEngine.buildEarlyComparison` for the emission
   decision. This is the same call the product makes, so a conclusion recorded
   as emitted has already cleared both the semantic gate and the render gate.
3. Records the comparison dimensions. When the engine emitted a conclusion the
   dimensions come from the engine (`RankedAuditableConclusion.dimensions`);
   when it stayed silent they come from `ChangeDimensionReader.compare` over the
   trimmed transcripts, and `dimensionSource` says which.
4. Probes the fixture's `supportedConclusion` through
   `SemanticConclusionGate.assess` and `ExplainableConclusionRenderGate.visible`.
   Cases that should conclude nothing are probed with a neutral statement built
   only from framing vocabulary, so any rejection belongs to the evidence rather
   than to the wording.
5. Probes every `prohibitedConclusions` entry the same way. A `overclaim`
   violation is probed as `change`, since claiming a stronger kind than the
   evidence supports is exactly what the case is testing; every other violation
   is probed as the case's own kind.
6. Re-verifies each emitted citation against the canonical transcript by exact
   substring comparison, independently of the validator.

## Metrics

Precision beats recall throughout. Refusing to conclude costs recall, which is
acceptable; asserting something the evidence does not support costs precision,
which is not. Only precision-shaped metrics are enforced.

| Metric | Population | Meaning |
| --- | --- | --- |
| `relatedPairPrecision` | pairs the engine related | how many a reader would agree about |
| `relatedPairRecall` | genuinely related pairs | how many the engine was willing to compare |
| `conclusionKindPrecision` | emitted conclusions | how many claim a kind the evidence supports |
| `changeDirectionAccuracy` | dimensions in both label and engine | how many moved the same way |
| `dimensionAccuracy` | change-labelled or emitted pairs | exact-set match on which dimensions moved |
| `unsupportedClaimRate` | all prohibited probes | how many the gate let through (lower better) |
| `wrongDomainRate` | cross-domain probes | how many the gate let through (lower better) |
| `genericOutputRate` | emitted conclusions | how many say nothing specific (lower better) |
| `suppressionRate` | all cases | how often nothing was produced — informational |
| `exactEvidenceValidity` | emitted conclusions | every citation resolves to the span it claims |
| `supportedConclusionAcceptance` | supportable cases | genuinely supported statements the gate accepted |
| `suppressionReasonMatch` | cases that must stay silent | refused for the expected reason |
| `changeEmissionRate` | change-labelled cases | informational recall figure |

A metric with an empty population reports `n/a` and is never treated as a pass.

## `relatedExpected` is a human judgement, not a prediction

`relatedExpected` records whether a careful reader would say the two moments are
about the same subject. It deliberately does **not** predict what the engine
does. A pair can be genuinely related and still be correctly refused a
conclusion — conflicting evidence, for example. Those cases count against
recall, never against precision, which is the intended trade.

## Thresholds

`thresholds.json` is provisional and split into `enforced` and `advisory`. It is
a regression guard on synthetic data, not evidence for anything. Do not raise a
bound because the current run happens to clear it.

## Fixtures

`fixtures/` holds synthetic cases only; the shape is `schema.json`. Adding a
case means adding a record to one of the domain files. `caseId` must be unique
across all files; the loader throws on duplicates and on missing fields.

`human_labels/` holds human-labelled data only and is currently empty. See its
README. Never move a synthetic fixture into it, and never describe a fixture
expectation as human-validated.

## Reading a failure

`score_evaluation.dart` prints every failing case with a plain-language reason.
A run that reports no failures on a fixture set this small is far more likely to
mean the fixtures are too easy than that the engine is correct.
