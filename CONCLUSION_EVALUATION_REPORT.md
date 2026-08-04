# Conclusion evaluation report

**Location:** repo root (`/CONCLUSION_EVALUATION_REPORT.md`).
**Harness:** `apps/voicememory_mobile/tool/conclusion_evaluation/`.
**Run date:** 2 August 2026.
**Data provenance: 100% synthetic. 0 human-labelled cases.**

Every number below was measured by actually running the harness against the
production pipeline. Nothing here is estimated, projected or rounded up from a
partial run. Where a metric has no population, it says so rather than reporting
a flattering default.

## 1. What was measured, and what it is worth

The harness runs the real code path — `AuditablePersonalChangeEngine`,
`SemanticConclusionGate`, `ConclusionConfidenceModel`,
`ExplainableConclusionRenderGate`, `ExplainableConclusionValidator` — over 50
synthetic cases. It re-implements none of it.

What that buys: a regression signal and a defect finder. It found four engine
defects, listed in section 7.

What it does not buy: any claim about conclusion quality for real users. The
expectations in `fixtures/` were written by the same author as the inputs, at
the same time, with the engine's behaviour partly in mind. That is a
consistency check, not ground truth. Anyone quoting a number from this document
must quote "synthetic" alongside it.

## 2. Reproducing it

From `apps/voicememory_mobile`:

```bash
dart run tool/conclusion_evaluation/generate_candidates.dart
dart run tool/conclusion_evaluation/score_evaluation.dart
```

Add `--enforce` to the scorer for CI. **It currently exits 1**, because
`conclusionKindPrecision` breaches its enforced bound (section 6).

Artifacts: `build/conclusion_evaluation/candidates.json` and
`build/conclusion_evaluation/scores.json`.

## 3. Fixture inventory

**50 cases**, all synthetic, all `humanLabelStatus: unlabelled`.

| sourceDomain | easy | medium | hard | total |
| --- | --- | --- | --- | --- |
| work | 6 | 4 | 2 | 12 |
| relationships | 3 | 2 | 2 | 7 |
| health | 4 | 2 | 0 | 6 |
| money | 2 | 3 | 1 | 6 |
| askingForHelp | 2 | 1 | 1 | 4 |
| avoidance | 3 | 0 | 1 | 4 |
| completion | 2 | 2 | 0 | 4 |
| overchecking | 2 | 2 | 0 | 4 |
| mixed | 0 | 0 | 3 | 3 |
| **total** | **24** | **16** | **10** | **50** |

Expected kinds: 25 `change`, 15 `neither`, 8 `repeat`, 2 `observation`.

Coverage includes: work, relationships, money, health language with no
diagnosis wording anywhere in any transcript, overchecking, avoidance,
completion, asking for help, conflicting evidence, negation, generic wording,
identical wording, unrelated moments, user-corrected framing, entries below and
just above the 12-character usability floor, and long entries that force quote
truncation.

## 4. Synthetic results — measured

| Metric | Value | N |
| --- | --- | --- |
| relatedPairPrecision | 0.950 | 38/40 |
| relatedPairRecall | 0.927 | 38/41 |
| conclusionKindPrecision | 0.955 | 21/22 |
| changeDirectionAccuracy | 1.000 | 34/34 |
| dimensionAccuracy | 0.885 | 23/26 |
| unsupportedClaimRate | 0.000 | 0/79 |
| wrongDomainRate | 0.000 | 0/5 |
| genericOutputRate | 0.000 | 0/22 |
| suppressionRate | 0.560 | 28/50 |
| exactEvidenceValidity | 1.000 | 22/22 |
| supportedConclusionAcceptance | 0.971 | 34/35 |
| suppressionReasonMatch | 0.867 | 13/15 |
| changeEmissionRate | 0.840 | 21/25 |

Reading notes:

- `unsupportedClaimRate` 0/79 is the strongest result here and the one that
  matters most: across 79 deliberately prohibited statements — wrong domain,
  identity and diagnosis language, causal claims, unsupported directions,
  generic hedges, kind overclaims — the semantic gate accepted none.
  **Caveat:** all 79 were written by the harness author. An adversary who has
  not read the gate's source would probe differently. 0/79 means "these 79
  attacks failed", not "the gate is safe".
- `wrongDomainRate` has a population of only 5. It is too small to carry weight.
- `suppressionRate` 0.560 is informational, not a defect. Half these fixtures
  are designed to produce nothing. What matters is *which* cases were
  suppressed, and four of them should not have been (section 5).
- `changeDirectionAccuracy` 34/34 is real but easy: the direction reader is
  ordinal and deterministic, and no fixture stresses it with mixed-scale
  wording beyond the two conflicting-evidence cases.

## 5. Human-labelled results

**None. There are none.**

`tool/conclusion_evaluation/human_labels/` is empty and contains only a README
describing the format a labelling session must use. `scored.humanLabelledCount`
is `0` and a test asserts it stays that way until real labels arrive.

No blind human has judged any conclusion this engine produces. The single most
valuable next step for this work is a blind labelling pass, not more fixtures.

## 6. Unlabelled cases

All 50. Every fixture is `unlabelled` by definition, because no human has
labelled anything. There is no partially-labelled subset and no
"validated" tier.

## 7. Current failures

11 of 50 cases fail at least one check. Grouped by cause.

### 7.1 Genuine engine defects (report only — nothing under `lib/` was changed)

**Defect A — a stemmed subject makes a supported change invisible.**
Cases: `complete_003_duration_increase`, `complete_004_outcome_shift`.

`AuditablePersonalChangeEngine._subjectOf` picks the most specific shared
subject marker, but `ChangeDimensionReader.subjectMarkers` returns *stemmed*
tokens. For "I finished the report…" the marker is `finish`, so the statement
reads "Finish — how long it lasted looks different…". `SemanticConclusionGate`
stems too, so it passes. `ExplainableConclusionValidator._hasMinimumTopicAlignment`
does **not** stem — its `_normalizedTopicToken` only maps `answer*` and
`check*` — so the statement shares no token with "finished", and the render gate
blocks with `insufficientTopicAlignment`. A well-supported change is dropped
silently. Confirmed directly: semantic rejections `[]`, render block reasons
`[insufficientTopicAlignment]`.

Affects every pair whose most specific shared marker is a stemmed form:
`finished→finish`, `stopped→stop`, `started→start`, `paused→pause`,
`planned→plan`, `replied→reply`, `meetings→meeting`, `messages→message`,
`deadlines→deadline`.

**Defect B — frequency decreases can never be shown.**
Case: `overcheck_002_frequency_down`.

The rendered statement for any frequency movement contains the dimension label
"how often it happened". `SemanticConclusionGate._increaseWords` contains
`often`, so `_claimedDirection` reads every frequency statement as claiming an
*increase*. When the frequency actually decreased and no cited quote contains an
increase word, the gate raises `unsupportedDirectionClaim` and the conclusion is
dropped. Confirmed by probing the two directions with the identical statement
template: increase → `[]`, decrease → `[unsupportedDirectionClaim]`.

The engine can therefore surface "you did this more often" but never "you did
this less often" — the direction users are most likely to want.

**Defect C — thread-only alignment is a dead path.**
Case: `help_004_thread_only_alignment`.

When two moments share an `archiveThreadId` but no subject words, `_subjectOf`
falls back to `captureContextTag`. Those words are not in the evidence, so
`SemanticConclusionGate` raises `unsupportedClaimLanguage` and the candidate is
dropped. `_alignedPair` accepts the pair, `areRelated` returns true, and the
conclusion can still never be shown. Confirmed: with `entryThreadIds` supplied,
semantic rejections are exactly `[unsupportedClaimLanguage]`.

**Defect D — model-generated text can be cited as the user's own words.**
Case: `edge_002_model_generated_evidence`.

`AuditablePersonalChangeEngine.buildEarlyComparison` calls
`AuditableConclusionTrustPolicy.rankBest` without passing `generatedTextEntryIds`
or `deletedEntryIds`. Deletion happens to be caught upstream by the `_usable`
filter reading `isDeleted`; generated text is not caught anywhere. The gate
supports `generatedTextCitedAsEvidence` and correctly raises it when the harness
supplies the set directly — the production call site simply never supplies it.
This is the one failure with a trust consequence rather than a coverage
consequence, and it is the sole cause of `conclusionKindPrecision` 0.955.

### 7.2 Design limits the harness exposes (not obviously bugs)

**Shared-verb false positives.** `edge_006_false_positive_shared_verb`
("checked the weather before my run" vs "checked my email before the meeting")
and `edge_007_false_positive_cross_domain_worry` ("worried about the rent" vs
"worried about the deadline"). A single shared stemmed content word is enough
for `_alignedPair` to declare a shared subject, so `areRelated` returns true for
pairs no reader would call the same thread. Both are ultimately suppressed —
but by `changeWithoutMovedDimension`, not `unrelatedSources`. The right answer
for the wrong reason, which is why `suppressionReasonMatch` is 13/15. These two
cases are the entire cost of `relatedPairPrecision` 0.950, and they mean that
metric sits **exactly** on its bound with no margin.

**Dimension gap on avoided→checked.** `money_001_avoided_to_checked`. "Avoided"
is a `behaviouralResponse` and "checked" is an `action`. A dimension observed in
only one moment is excluded by design, so the behaviour change is invisible and
only the emotional shift is read. The engine still emits a defensible
conclusion; it is just a narrower one than a reader would write.

**Situation reads as `replaced` in thread-only pairs.** `help_004`. With no
shared markers, `situation` is compared as two disjoint marker sets and comes
back `replaced`, adding a dimension a reader would not call changed. Only
observable on thread-aligned pairs.

### 7.3 Recall costs that are working as intended

`avoid_003_conflicting_intensity_and_certainty`, `work_004_conflicting_evidence`
(conflicting evidence suppresses the pair) and `work_005_identical_wording`
(identical text is refused) count as related-pair recall misses because
`relatedExpected` records what a *reader* would say, not what the engine does.
These are correct refusals. They are recorded as recall costs precisely so that
the trade stays visible instead of being defined away.

## 8. Thresholds not yet supported by evidence

**All of them.** Every bound in `thresholds.json` is a provisional engineering
guard-rail chosen by inspection of one synthetic run. None is derived from human
labels, user outcomes, or any external benchmark.

Specific warnings:

| Bound | Status |
| --- | --- |
| `minRelatedPairPrecision: 0.95` | Currently met at exactly 0.950 (38/40). Zero margin — one more false positive breaks CI. Not evidence that 0.95 is the right level. |
| `minConclusionKindPrecision: 1.0` | **Currently breached** (0.955). Left at 1.0 deliberately: showing a conclusion of the wrong kind is a trust failure, so the bound reflects the intent and the run reports the gap. Do not lower it to make CI green — fix Defect D. |
| `maxUnsupportedClaimRate: 0.0` | Met on 79 author-written probes. Says nothing about probes the author did not think of. |
| `maxWrongDomainRate: 0.0` | Population of 5. Statistically meaningless. |
| `minChangeDirectionAccuracy: 0.9` | Met at 1.000 on 34 comparisons drawn from a deterministic ordinal reader. Nearly free. |
| `minDimensionAccuracy: 0.6` | Advisory. Set below the observed 0.885 without justification for either number. |
| `minRelatedPairRecall: 0.3` | Deliberately far below the observed 0.927, encoding precision-over-recall. Not a target. |
| `minSupportedConclusionAcceptance: 0.8` | Advisory. Observed 0.971 across 35 author-written statements. |
| `minSuppressionReasonMatch: 0.6` | Advisory. Observed 0.867. |
| `suppressionRate`, `changeEmissionRate` | Intentionally unbounded. Suppression is a product lever; a threshold would create pressure to conclude. |

No production or marketing claim may be set from these numbers. Precision
claims in particular need blind human labels before they mean anything.

## 9. Verification performed

- Harness executed end-to-end from `apps/voicememory_mobile`; both scripts run
  and write artifacts. `--enforce` correctly exits 1 on the current breach.
- `dart format` applied to all three Dart files added by this work.
- `flutter analyze --no-fatal-infos`: 14 issues, **none in any file added or
  changed here**. The 5 errors are pre-existing in
  `lib/features/study_mode/study_mode_service.dart` (missing
  `local_archiveidentity.dart` and `study_buildidentity.dart`), which this work
  did not touch.
- `flutter test test/semantic_conclusion_gate_test.dart` — 14 groups/tests, all
  passed. `test/auditable_personal_change_test.dart` also passed. Nothing broken.
- `flutter test test/conclusion_evaluation_harness_test.dart` — 13 tests, all
  passed.
- No file under `apps/voicememory_mobile/lib/` was modified. The four defects
  above are reported, not fixed.

## 10. What would make these numbers mean something

1. Fix Defect D. It is the only failure here with a direct user-trust cost.
2. Run a blind human labelling pass on the existing 50 synthetic cases, by
   someone who has not seen the expected answers, and report human-labelled
   metrics separately from synthetic ones.
3. Grow the adversarial prohibited-statement set with statements written by
   someone who has not read `semantic_conclusion_gate.dart`. 0/79 against
   self-authored probes is the weakest strong-looking number in this report.
4. Only then consider setting any threshold from measurement rather than
   judgement.
