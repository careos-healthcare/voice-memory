# Canonical proof admission

This describes the proof-admission pipeline as it exists in
`lib/features/proof_admission/` today. It is a description of the code, not an
aspiration: where a piece of the design is declared but not yet wired into a
shipping path, that is stated under [Known gaps](#known-gaps).

The one sentence version: a provider response is parsed into claims, every
citation is re-verified character-for-character against the user's own stored
transcript, claims that cannot clear their evidence minimum are dropped, the
archive's correction memory narrows what survives, a bounded weighted score
turns the result into a confidence band, a quality receipt records what the
evidence did and did not establish, and only the resulting immutable
`VerifiedProof` may cross into presentation.

## 1. Pipeline stages

Everything below happens inside `CanonicalProofAdmissionService.admit`
(`proof_admission_service.dart`) unless another file is named.

| # | Stage | Type produced | Failure outcome |
| --- | --- | --- | --- |
| 1 | Provider response captured | `RawModelResponse` | — |
| 2 | Parse and structural validation (`_parse`) | `StructuralValidationResult` → `ParsedConclusionCandidate` | `invalidStructure` |
| 3 | Evidence verification (`CanonicalEvidenceVerifier.verify`) | `EvidenceVerificationResult` → `VerifiedEvidenceSnapshot` | `sourceUnavailable`, `wrongArchive`, `invalidEvidence`, `stale`, `insufficientEvidence` |
| 4 | Claim-level semantic admission (`_claimAdmissionFailure`) | `VerifiedProofClaim` | `insufficientEvidence` |
| 5 | Correction-informed admission (`ProofCorrectionAdmissionPolicy.decide`) | `ProofCorrectionDecision` | `correctionSuppressed`, `insufficientEvidence` |
| 6 | Contradiction pressure and confidence scoring (`_confidence`) | `ProofConfidenceBand` | `contradictionTooStrong`, `suppressed` |
| 7 | Quality receipt (`ProofQualityCalculator.build`) | `ProofQualityReceipt` | — |
| 8 | Immutable proof | `VerifiedProof` inside `ProofAdmitted` | — |
| 9 | Presentation mapping | `VerifiedProofViewModel` | — |
| 10 | UI | `PostSaveBeliefInsight`, `ProofDetailSheet` | — |

### 1.1 RawModelResponse

`RawModelResponse` carries only `payload` (the decoded map), `receivedAt`, and
an optional `providerResponseId`. `ApiClient.postAnalyzeRaw` is the only
producer of it from a network response.

### 1.2 Parse and structural validation

`_parse` returns `StructuralValidationResult.invalid(reason)` for any of:

- `payload['reflection']` is not a map — `reflection_missing`.
- `primarySourceEntryId` is absent from the supplied `sourceEntries` —
  `primary_source_missing`.
- an element of the claims list is not an object — `claim_not_object`.
- a claim fails `_parseClaim` — `claim_invalid`. `_parseClaim` requires a
  recognised `kind` token, a `text` string, a `citations` list, and for every
  citation a `sourceEntryId` string, a `quote` string, and a recognised `role`.
  `startUtf16`, `endUtf16`, and `sourceRevision` are optional.
- the claim set is empty, has duplicate `claimId`s, or contains a claim with
  blank text, text longer than 2000 characters, or no citations —
  `claim_structure_invalid`.

Claims are read from `reflection.claims`, falling back to `payload['claims']`.
When neither is a list, a legacy single-claim shape is synthesised: one
`mainObservation` claim whose text is `reflection.concreteObservation` and whose
single support citation quotes `reflection.exactLanguagePattern` against the
primary source at that source's current revision. If either field is blank the
response is rejected as `legacy_response_missing_exact_evidence`. There is no
path that invents a citation for a claim.

The candidate identity is `providerResponseId` when non-blank, otherwise the
first 24 hex characters of the SHA-256 of the canonically encoded reflection
map. `modelConfidence` comes from `reflection['confidence']` and
`deterministicFallback` from `reflection['deterministicFallback'] == true`.

### 1.3 Evidence verification

Claims are then processed one at a time. A `causalRelationship` claim is
discarded before any evidence work is attempted — see
[Hard safety invariants](#3-hard-safety-invariants). Every other claim's
citations go through `CanonicalEvidenceVerifier.verify`, detailed in
[section 2](#2-evidence-verification-rules).

Failure asymmetry is deliberate and lives here: if verification fails for the
`mainObservation` claim, `admit` returns immediately with the verifier's own
outcome. If it fails for any secondary claim, the claim's kind is appended to a
local `missingEvidence` list and the claim is dropped, and admission continues.

### 1.4 Claim-level semantic admission

`_claimAdmissionFailure(kind, evidence)` decides what a set of verified support
snapshots is allowed to assert. It counts distinct `sourceEntryId` values among
snapshots whose role is `support`, and compares that against a per-kind
minimum:

| Claim kind | Distinct supporting sources required |
| --- | --- |
| `mainObservation` | 1 |
| `nextAction` | 1 |
| `repeated` | 2 |
| `directionOfChange` | 2 |
| `frequency` | 3 |
| `trend` | 3 |
| `strength` | 4 |
| `causalRelationship` | 999 (unreachable by construction) |

`directionOfChange` carries two extra checks: there must be at least two
distinct quote strings (`change_quotes_not_distinct`), and the earliest
supporting source date must be strictly before the latest
(`then_must_precede_now`). Equal dates fail.

Failure again splits by kind: on `mainObservation` it rejects the whole
response as `insufficientEvidence`; on a secondary claim it drops that claim.
After the loop, admission requires at least one surviving claim and requires
one of them to be a `mainObservation`, otherwise
`insufficientEvidence: main_observation_not_supported`.

### 1.5 Correction-informed admission

The surviving `mainObservation` text produces two fingerprints (see
[section 7](#7-fingerprints)), and those plus an evidence fingerprint and the
set of contributing source ids form a `ProofCorrectionQuery`. The injected
`ProofCorrectionAdmissionPolicy` answers with a `ProofCorrectionDecision`
carrying up to four things: suppression, a set of disallowed evidence source
ids, a confidence cap, and a preferred wording. The shipping implementation is
`ArchiveCorrectionStore`; the default is `NoProofCorrectionAdmissionPolicy`,
which returns `ProofCorrectionDecision.none`.

A suppressed decision ends admission with `correctionSuppressed`. Otherwise, if
the decision names disallowed evidence, `_withoutDisallowedEvidence` strips
those snapshots and re-runs `_claimAdmissionFailure` on what remains. A claim
left with no evidence fails as `no_remaining_evidence`. If the
`mainObservation` no longer clears its minimum, admission ends with
`insufficientEvidence: remaining_evidence_insufficient_after_correction`. This
is the reason disputed evidence cannot make a proof quietly shrink: it either
still clears the thresholds or it stops being a proof.

The evidence fingerprint (`_evidenceFingerprint`) is the SHA-256 of the
candidate id joined with a sorted list of
`sourceEntryId:transcriptRevision:startUtf16:endUtf16` tuples, so it is stable
across reordering and changes whenever the cited spans change.

### 1.6 Contradiction pressure and confidence scoring

Support and contradiction snapshots are counted across all surviving claims.
When contradictions strictly outnumber supports, admission ends with
`contradictionTooStrong: contradiction_pressure_exceeds_support`.

`_confidence` then builds a `ProofFeatureVector` and asks
`ProofCandidateScorer.score` for a single number, which is banded:

- score ≥ 10 → `high`
- score ≥ 2 → `medium`
- otherwise → `low`

A `low` band is not surfaced: admission ends with
`suppressed: confidence_below_surface_threshold`. The surviving band is then
narrowed by `_cap` against `decision.confidenceCap`, so a cap can only ever
lower it.

### 1.7 Quality receipt and the immutable proof

`ProofQualityCalculator.build` produces the `ProofQualityReceipt` from the
verified evidence and the set of dropped claim kinds, and
`withUserConfirmedWording` attaches the user's preferred label if a correction
supplied one. Details in [section 5](#5-proof-quality).

`VerifiedProof` is then assembled. Two things about it are worth naming:

- `proofId` is `proof-` plus the first 24 hex characters of the evidence
  fingerprint, so identity is derived from cited evidence rather than assigned.
- The reflection is rebuilt rather than passed through. `repeatedSignal`
  survives only if a `repeated` claim was admitted, `tensionOrContradiction`
  only if at least one contradiction snapshot exists, `nextSmallAction` only if
  a `nextAction` claim was admitted, and `avoidedOrVagueArea` and
  `patternObservations` are always cleared. A generated field cannot outlive
  the claim that justified it.

`sourceRevisionFingerprint` is the SHA-256 of the
`sourceEntryId:transcriptRevision:transcriptFingerprint` triples in source-date
order, which is what lets a later display-time check notice that a transcript
moved underneath a stored proof.

### 1.8 Display-time revalidation

`revalidateForDisplay(proof, currentSources, activeArchiveScope,
activeOwnerScope)` re-checks a persisted proof without re-running the model. It
returns `wrongArchive` when the proof's scopes no longer match the active ones
or when a cited source has been archived, excluded by archive policy, or moved
scope; `sourceUnavailable` when a cited source is missing or deleted; and
`stale` when a source's revision or transcript fingerprint changed, or when
`transcript.substring(startUtf16, endUtf16)` no longer equals the stored quote.

`ProofDisplayGate` (`proof_display_gate.dart`) is what actually calls it on the
rendering path. It maps each live `JournalEntry` to a `ProofSourceEntry`,
recomputing `transcriptRevision` with the same `UserContentSafety.privacyHash`
the capture path used, and mapping `isArchived` onto the verifier's `archived`
flag. Because the revision is derived from the transcript rather than tracked
separately, an edit invalidates the proof that quoted the old text without
anything having to observe the edit.

The gate fails closed: `viewFor` returns null on every outcome other than
admitted, and the surface renders nothing rather than a proof it cannot stand
behind. `latestVerified` deliberately does not fall back to an older entry's
proof when the newest one fails, because presenting a previous claim in the
place where the just-saved one belongs would misrepresent what was proved.

The consequence for fixtures is worth stating: a hand-built `VerifiedProof` will
not render unless it is internally consistent with its entry — quote at the
recorded span of that exact transcript, and the revision and fingerprint that
transcript produces. `CanonicalEvidenceVerifier.transcriptFingerprint` is public
so admission, revalidation and tests all derive that value one way.

Hashing is what makes this path expensive, and it happens on both sides of the
gate: once per entry to derive its revision, and again per citation inside
`revalidateForDisplay` to recompute the transcript fingerprint. Both go through
`ProofAdmissionCache` — `sourceEntryFor` and `revisionFor` respectively. The
cache compares the transcript itself before reusing either value, so an edit
always misses; a false hit here would let a stale proof render, which is worse
than any saving it could offer.

Both the cache and the default service are shared statically, because a
per-instance cache would be discarded on the rebuild it exists to make cheaper,
and a service built per call would be handed an empty one every time.
`ProofDisplayGate` and `CanonicalProofAdmissionService` each accept an injected
cache for tests.

### 1.9 Presentation

`VerifiedProofViewModel.fromVerifiedProof` is the only constructor of
presentation data, and it accepts a `VerifiedProof` — not a parser DTO, not a
provider map. It converts every quantitative dimension into a plain-language
line or a null, clips each quote through `UserContentSafety.safeSnippet` at 180
characters, and hands the result to `PostSaveBeliefInsight` (the compact card)
and `ProofDetailSheet` (the detail surface). The statement shown is
`qualityReceipt.userConfirmedWording` when present, otherwise
`reflection.concreteObservation`.

## 2. Evidence verification rules

`CanonicalEvidenceVerifier.verify` is the only place a quote becomes evidence.
It walks the citations of one claim in order and refuses the whole claim on the
first violation.

| Check | Outcome | Reason token |
| --- | --- | --- |
| Cited source id exists in the supplied source map | `sourceUnavailable` | `source_missing` |
| Source `archiveScope` and `ownerScope` both equal the active scopes | `wrongArchive` | `source_scope_mismatch` |
| Source is not `deleted`, not `archived`, and `allowedByArchivePolicy` | `invalidEvidence` | `source_not_eligible` |
| Source `sourceType` is not `generatedPlaceholder` | `invalidEvidence` | `generated_text_is_not_evidence` |
| Trimmed transcript is non-empty and is not `[draft]` and does not start with `[draft] ` | `invalidEvidence` | `transcript_unavailable` |
| Source has `remoteProcessingConsented` | `invalidEvidence` | `remote_processing_consent_missing` |
| Citation carries a non-null `sourceRevision` equal to the source's current `transcriptRevision` | `stale` | `source_revision_mismatch` |
| Quote is non-empty | `invalidEvidence` | `empty_quote` |
| Span resolves (see below) | `invalidEvidence` | `quote_span_invalid_or_ambiguous` |
| Source `createdAt` has year ≥ 1970 and is not more than one day in the future | `invalidEvidence` | `source_date_invalid` |
| At least one snapshot survived the whole claim | `insufficientEvidence` | `no_verified_evidence` |

Repeated citations of the same span are de-duplicated rather than refused: the
key is `sourceEntryId:start:end:role`, and a repeat is skipped silently. The
same span cited under two different roles is therefore kept twice, once per
role.

### UTF-16 span handling and exact-quote matching

`_resolveSpan` has exactly two modes, and neither of them normalises anything.

When the citation supplies both `startUtf16` and `endUtf16`, all four of the
following must hold: `start >= 0`; `end > start`; `end <=
transcript.length` (Dart `String.length`, i.e. UTF-16 code units); and neither
offset splits a surrogate pair. The boundary test (`_isCodePointBoundary`)
inspects the code units either side of the offset and rejects the offset only
when the preceding unit is a high surrogate (`0xD800`–`0xDBFF`) and the
following unit is a low surrogate (`0xDC00`–`0xDFFF`). Offsets at 0 or at
`length` are always boundaries. Finally `transcript.substring(start, end)` must
equal the quote by exact string equality.

When either offset is absent, the quote is searched for as a literal — the
pattern is `RegExp.escape(quote)`, so no regex metacharacter in user text can
be interpreted — and the span is accepted only when there is exactly one match
in the transcript. Zero matches and two-or-more matches both fail as
`quote_span_invalid_or_ambiguous`, so an ambiguous quote is never silently
resolved to its first occurrence.

There is no fuzzy matching, no case folding, no whitespace collapsing, no
line-ending normalisation, and no Unicode normalisation anywhere in span
resolution. The stored `VerifiedEvidenceSnapshot` keeps the resolved offsets
alongside a SHA-256 `transcriptFingerprint` of the whole transcript, which is
what makes the display-time check in §1.8 possible.

## 3. Hard safety invariants

These are expressed as explicit control flow and returns. None of them is a
feature, a weight, or a threshold in a config file, and none of them can be
weakened by editing `config/proof_admission_weights.v1.json`. Structurally,
`ProofCandidate.hardSafetyPassed` is a boolean gate that
`ProofCandidateScorer.rank` uses to exclude a candidate outright, and
`ProofFeatureVector` accepts numeric and boolean structural inputs only — there
is no field on it that could carry any of these decisions.

1. A cited source that is missing, deleted, archived, or excluded by archive
   policy can never produce evidence.
2. A source whose `archiveScope` or `ownerScope` differs from the active scopes
   can never produce evidence, and a stored proof whose own scopes no longer
   match cannot be redisplayed.
3. Generated text is not evidence: `ProofSourceType.generatedPlaceholder` and
   draft-placeholder transcripts are refused outright.
4. Missing remote-processing consent refuses the source.
5. A citation must name the source revision it was made against, and it must
   match the current revision. A null revision fails.
6. Quote admission is exact `substring` equality on UTF-16 offsets; a supplied
   offset that splits a surrogate pair is refused; a quote with no offsets is
   admitted only on exactly one literal match.
7. A source date before 1970 or more than one day in the future refuses the
   source.
8. `causalRelationship` claims are never admissible. The claim is dropped
   before verification runs, and its nominal minimum of 999 distinct sources
   makes the semantic path unreachable as well.
9. `directionOfChange` requires two distinct sources, two distinct quotes, and
   a strictly earlier "then" than "now".
10. A response with no admitted `mainObservation` is never a proof, whether the
    observation failed verification, failed its minimum, or lost its evidence
    to a correction.
11. Contradiction snapshots strictly outnumbering support snapshots rejects the
    proof.
12. A `low` confidence band is never surfaced.
13. An `ignoreForever` correction on a matching framing suppresses admission
    unconditionally — no evidence, however new, overrides it.
14. Contradictions are never trimmed from a receipt to improve how a proof
    looks (`ProofQualityReceipt.contradictions` is populated from every
    contradiction snapshot).

## 4. Soft scoring

Soft scoring decides how confident an already-admitted proof may present as. It
can never admit something verification refused.

### Feature vector

`ProofFeatureVector` (`proof_candidate.dart`) has 23 fields, all numeric or
boolean. Its constructor throws if any of the bounded ratios (`coverage`,
`specificity`, `chronology`, `sourceDiversity`, `citationSourceRatio`,
`corroborationRatio`, `contradiction`, `recency`, `freshness`,
`transcriptSpecificity`, `deterministicFallback`) is non-finite or outside
`[0, 1]`, or if any count is negative; `modelConfidence` is clamped into
`[0, 1]` rather than rejected. `toJson` emits numbers and booleans only, which
is what makes text leakage through the scorer impossible by construction.

How `_confidence` populates each field:

| Field | Value in the admission path |
| --- | --- |
| `coverage` | Constant `1` |
| `specificity` | Sum over snapshots of `min(quoteLength, 160) / 160`, clamped to `[0, 1]` |
| `citationCount` | Number of verified snapshots |
| `sourceCount` | Number of distinct source ids |
| `chronology` | `1` when more than one distinct source, else `0` |
| `sourceDiversity` | Distinct `sourceType` values ÷ distinct sources |
| `citationSourceRatio` | Distinct sources ÷ snapshot count |
| `corroborationRatio` | Support snapshots ÷ snapshot count |
| `contradiction` | Contradiction snapshots ÷ snapshot count |
| `recency` | `1 − (daysSinceLatestSource / 365)`, with age clamped to `[0, 365]` |
| `freshness` | `1` when the latest source is 30 days old or less, else `0.5` |
| `transcriptSpecificity` | Sum over snapshots of `wordCount / 24`, clamped to `[0, 1]` |
| `userConfirmed` | `positiveHistory > 0` |
| `correctionHistoryCount` | `positiveHistory + negativeHistory` |
| `acceptedCorrectionRatio` | `positiveHistory ÷ (positive + negative)`, or `0` when there is no history |
| `positiveCorrectionHistory` | `ProofCorrectionAdmissionPolicy.positiveHistory` on the framing fingerprint |
| `negativeCorrectionHistory` | `negativeHistory` on the framing fingerprint |
| `wordingRejectionHistory` | `wordingRejectionHistory` on the wording fingerprint |
| `evidenceRejectionHistory` | `evidenceRejectionHistory` on the evidence fingerprint |
| `oneEntryPenalty` | `distinctSources == 1` |
| `stalePenalty` | Constant `false` |
| `modelConfidence` | `reflection['confidence']`, or `0` when absent |
| `deterministicFallback` | `1` when the response was a deterministic fallback, else `0` |

### Weights config and the generated adapter

`config/proof_admission_weights.v1.json` is the source of truth. Its current
contents:

| Feature | Weight | Feature | Weight |
| --- | --- | --- | --- |
| `coverage` | 2.0 | `transcriptSpecificity` | 1.5 |
| `specificity` | 2.5 | `userConfirmed` | 2.0 |
| `citationCount` | 0.35 | `correctionHistoryCount` | 0.2 |
| `sourceCount` | 0.75 | `acceptedCorrectionRatio` | 0.75 |
| `chronology` | 1.25 | `positiveCorrectionHistory` | 0.35 |
| `sourceDiversity` | 1.5 | `negativeCorrectionHistory` | −0.75 |
| `citationSourceRatio` | 1.0 | `wordingRejectionHistory` | −0.45 |
| `corroborationRatio` | 1.5 | `evidenceRejectionHistory` | −1.0 |
| `contradiction` | −3.5 | `oneEntryPenalty` | −2.0 |
| `recency` | 0.75 | `stalePenalty` | −1.5 |
| `freshness` | 0.75 | `modelConfidence` | 0.5 |
|  |  | `deterministicFallback` | −0.5 |

`modelConfidenceCap` is `0.85`, and `ProofCandidateScorer.score` clamps the
model's self-reported confidence to that cap before weighting it, so a
confident model cannot talk its way past the evidence.

`ProofAdmissionConfig.fromJson` is strict in both directions. The top-level key
set must be exactly `{schema, version, modelConfidenceCap, weights}`; `schema`
must equal `voice_memory.proof_admission_weights`; `version` must equal `1`;
`modelConfidenceCap` must be a finite number in `[0, 1]`; and the weights map
must contain exactly the 23 `requiredWeightKeys`, each a finite number in
`[-5, 5]`. A missing key, an unknown key, a non-finite value, or an
out-of-range weight is a `FormatException` — there are no defaults to fall back
on.

`tool/generate_proof_admission_weights.dart` validates the JSON through that
same constructor, re-encodes it canonically, and writes
`lib/features/proof_admission/generated/proof_admission_weights.g.dart`, which
holds the JSON as a raw string plus a `generatedProofAdmissionConfig` that
parses it at load. Run with `--check` it fails when the generated file is stale
instead of rewriting it, which is what makes config drift a build failure
rather than a runtime surprise. `ProofCandidateScorer` defaults to that
generated config.

### Deterministic tie-breaking

`ProofCandidateScorer.rank` excludes any candidate whose `hardSafetyPassed` is
false — safety-failed candidates are never merely down-weighted — throws on
duplicate `stableId`s, and sorts the rest through `_compare` in this order:

1. Higher `weightedScore`.
2. `isValid` true before false.
3. Higher `sourceCount`.
4. Lower `contradiction`.
5. Higher `specificity`.
6. Higher `recency + freshness`.
7. Lexicographically smaller `stableId`.

The final step means the ordering is total: identical inputs always produce
identical output, with no dependence on iteration or arrival order.

## 5. Proof quality

`ProofQualityCalculator` (`proof_quality.dart`) computes every dimension from
verified evidence only. It never reads the model's own wording, so a trend the
model asserted but the dated evidence does not support resolves to
`insufficientEvidence` rather than to the asserted direction.

Two shared helpers underpin the rest:

- `_distinctMoments` collapses evidence to one snapshot per `sourceEntryId`,
  keeping the earliest `sourceDate`, and sorts by date then source id. A moment
  counts once no matter how many times it was cited, and the ordering is
  deterministic.
- `_comparableWindows` splits those moments at the midpoint of their own span
  so both halves cover the same amount of elapsed time. It returns null — and
  therefore forces an `insufficientEvidence` answer — when there are fewer
  than `minimumMomentsForTrend` (3) moments, when the span is zero or negative,
  or when either half comes out empty.

Thresholds live in `ProofQualityThresholds`: `minimumMomentsForRepeat` 2,
`minimumMomentsForTrend` 3, `minimumWordsForSpecificQuote` 4, `staleAfterDays`
90, `strengthMarginWords` 1. These govern what may be *claimed about* evidence
that already passed verification, which is why they are ordinary constants
rather than part of the weighted configuration.

### Dimensions

| Field | How it is computed | Unestablished state |
| --- | --- | --- |
| `proofType` | `unresolved` if any contradiction exists; else `change` if a `directionOfChange` claim was admitted; else `repeatedSignal` if a `repeated` claim was admitted; else `currentObservation` | — (always set) |
| `confidenceBand` | Passed in from admission, after any correction cap | — |
| `frequency` | `ProofFrequency(distinctMoments: moments.length, windowStart: first date, windowEnd: last date)` | `ProofFrequency.none()` when there are no supporting moments: count 0, both window bounds null |
| `trend` | `mixed` when `contradictions × 2 ≥ moments`; else compares the count of moments in the later window against the earlier one: more → `increasing`, fewer → `decreasing`, equal → `stable` | `ProofTrend.insufficientEvidence` when the windows are not comparable |
| `strengthOverTime` | `mixed` under the same contradiction rule; else compares the average quote word count of the later window against the earlier one, requiring a move of more than `strengthMarginWords` (1) to read as `stronger` or `weaker`, otherwise `unchanged` | `ProofStrengthOverTime.insufficientEvidence` when the windows are not comparable |
| `supportingEvidence` | Every snapshot with role `support` | Empty list |
| `counterexamples` | Every snapshot with role `counterexample` | Empty list |
| `contradictions` | Every snapshot with role `contradiction`, never trimmed | Empty list |
| `missingEvidence` | Deterministic reasons, see below | Empty list |
| `firstOccurrence` | `sourceDate` of the earliest distinct supporting moment | `null` when there are no supporting moments |
| `lastOccurrence` | `sourceDate` of the latest distinct supporting moment | `null` when there are no supporting moments |
| `thenEvidence` / `nowEvidence` | First and last distinct supporting moment of the `directionOfChange` claim specifically | Both `null` unless that claim exists and has at least two distinct supporting moments |
| `unsupportedClaims` | The claim kinds admission dropped, sorted by enum name | Empty list |
| `userConfirmedWording` | Set only by `withUserConfirmedWording` from a `wrongWording` correction's replacement label; blank input is ignored | `null` |
| `generatedAt` | The admission clock's `now` | — |
| `verifierVersion` / `scorerVersion` / `configVersion` / `schemaVersion` | 1 / 1 / 1 / 2 | — |

The `mixed` rule is worth stating plainly: `contradictions × 2 ≥ moments` means
that once contradictions reach half the number of supporting moments, no trend
or strength direction is reported at all.

Note that trend and strength are computed independently of whether the model
claimed a `trend` or `strength` claim, and that a `frequency`, `trend`, or
`strength` claim can be dropped by §1.4 while the receipt still reports the
corresponding dimension from whatever evidence the surviving claims carry.

### Missing-evidence reasons

`MissingEvidenceReason` is a closed set, each member computed structurally and
each mapping to exactly one plain-language line in
`VerifiedProofViewModel.missingEvidenceLineFor`. None of them asks for generic
"more journaling".

| Reason | Emitted when | Line shown |
| --- | --- | --- |
| `needsAnotherDistinctSource` | Fewer than 2 distinct supporting moments | "Needs another separate moment before this can be called a repeat." |
| `needsMoreSpecificQuote` | At least one moment exists and the shortest quote has fewer than 4 words | "The words behind this are short, so a more specific moment would help." |
| `needsNewerEvidence` | At least one moment exists and the latest is more than 90 days before `now` | "The most recent moment behind this is old." |
| `needsContradictionResolution` | Any contradiction snapshot exists | "Something you said contradicts this, and it is not resolved." |
| `needsValidThenSource` | A `directionOfChange` claim was admitted but then/now evidence could not be derived | "Needs an earlier moment to compare against." |
| `needsValidNowSource` | Same condition; the two are always emitted together | "Needs a recent moment to compare against." |

### Explicit absence

The receipt does not default an unestablished dimension to a flattering value.
Absent occurrences are `null`; unestablished trend and strength carry an
explicit `insufficientEvidence` member; and `ProofFrequency.none()` reports zero
moments with null window bounds rather than an invented window.
`ProofFrequency.established` is `distinctMoments >= 2`, so a single moment can
never present as repetition, and `windowDays` is null whenever either bound is.

The view model turns each of those into a null line
(`frequencyLineFor` returns null when frequency is not established;
`trendLineFor` and `strengthLineFor` return null on `insufficientEvidence`), and
`ProofDetailSheet` omits the whole section rather than rendering an empty
heading.

`ProofQualityReceipt.fromJson` also restores schema-1 receipts into these
explicit states rather than guessing: unknown or missing trend and strength
become `insufficientEvidence`, a non-map `frequency` becomes
`ProofFrequency.none()`, non-list evidence fields become empty lists, an
unknown `proofType` becomes `currentObservation`, and a missing `generatedAt`
becomes the Unix epoch. An old receipt therefore cannot claim a trend that was
never computed from dated evidence.

## 6. Correction taxonomy

`ArchiveCorrectionChoice` has six members, and `ArchiveCorrectionStore.decide`
is where each one takes effect. `ArchiveCorrection` itself stores structural
metadata only — fingerprints, source ids, a closed-set choice, an optional
closed-set qualifier, timestamps, and a source-surface string. There is no
free-text note field.

`decide` first narrows to non-superseded records in the same `archiveScope`,
then keeps those matching the query on *any* of the three fingerprints
(`targetProofFingerprint == proofFingerprint`, or equal
`semanticFramingFingerprint`, or equal `wordingFingerprint`). With no match it
returns `ProofCorrectionDecision.none`. It then applies the choices in a fixed
order.

| Choice | Behaviour in `decide` |
| --- | --- |
| `ignoreForever` | Checked first. On a framing match, returns suppression with reason `ignore_forever` immediately. The materially-new-evidence escape is deliberately not applied. |
| `wrong` | Checked second. On a framing match with no materially new evidence, returns suppression with reason `framing_rejected_as_wrong`. New evidence lets the framing be re-proposed. |
| `wrongEvidence` | On a framing match, adds `disputedEvidenceRefs` to the disallowed set — or `affectedEvidenceRefs` when the user disputed the whole citation set rather than naming parts. Disallowed sources are then stripped and the claim minimums re-checked (§1.5). |
| `wrongWording` | Keyed on wording rather than framing, unlike the branches above, because it is about the sentence rather than the relationship. Eligible records are ordered before a label is taken: an exact `wordingFingerprint` match beats one reached only through the shared framing, the more recent `updatedAt` beats the older, and `correctionId` breaks any remaining tie — so the label does not depend on the order corrections were stored in. A record with no replacement offered suppresses with reason `wording_rejected`, but only on an exact `wordingFingerprint` match: the relationship survives, this exact sentence does not. |
| `partlyRight` | On a framing match with no materially new evidence, sets `confidenceCap` to `medium`. The relationship may fit, but it cannot present as settled. |
| `exactlyRight` | No effect on the decision. It contributes to `positiveHistory`, which raises the soft score through `userConfirmed`, `positiveCorrectionHistory`, and `acceptedCorrectionRatio`. |

Three details are load-bearing:

**Framing matching.** `_framingMatches` is true when the correction's
`semanticFramingFingerprint` equals the query's, or when the correction's
`targetProofFingerprint` equals the query's evidence fingerprint. `wrong`,
`partlyRight`, `wrongEvidence`, and `ignoreForever` all require it; the
`wrongWording` suppression path deliberately does not, requiring an exact
wording match instead.

**Materially new evidence.** `_hasMateriallyNewEvidence` is purely structural:
it returns false when the correction recorded no `affectedEvidenceRefs` at all,
and otherwise true only when the candidate rests on at least one source id the
rejected version did not use. Time passing is never materially new evidence.
This rule gates `wrong` and `partlyRight` and is intentionally not consulted for
`ignoreForever`.

**Ignore-forever is not supersedable.** `recordForProof` supersedes the
existing active correction for the same `archiveScope` and `targetProofId`
before writing a new one — but it explicitly skips records whose choice is
`ignoreForever`. Tapping a positive choice on a later card therefore cannot
undo an ignore. The only reversal is `undoIgnoreForever(archiveScope,
semanticFramingFingerprint)`, which marks the matching ignore rows superseded
(rather than deleting them, so the history stays auditable and exportable) and
returns how many it reversed. In the UI, `ignoreForever` is also the one choice
that cannot be committed by a single tap: `VerifiedProofCorrectionControls`
requires an explicit confirmation dialog first, and `wrongEvidence` opens a
picker so the user names which quotes are wrong.

**Legacy Hide never becomes an ignore.** In
`ArchiveCorrectionStore.migrateLegacyArchiveFeedback`, ids from the legacy
`hidden` list map to `wrong`; ids with a non-zero legacy `notQuite` count map
to `partlyRight`; anything else in the legacy blob maps to `exactlyRight`. A
legacy Hide meant "not this card" and never carried consent for archive-wide
semantic suppression. The mapping table in `archive_correction_migration.dart`
enforces the same thing structurally: it is typed with the private
`_MigratableChoice` enum, which has no `ignoreForever` member at all, so no
migration can produce an archive-wide ignore.

The four history counters (`positiveHistory`, `negativeHistory`,
`wordingRejectionHistory`, `evidenceRejectionHistory`) that feed soft scoring
take the archive scope as a parameter and skip superseded records, matching
`decide`. The scope is passed by the admission service from its own
`activeArchiveScope` rather than read from ambient state, so praise recorded in
one archive cannot raise the confidence of a proof in another, and a suppression
the customer has lifted stops influencing scoring.

`clearAll` wipes canonical correction memory, and
`LocalPrivacyDataControls` calls it alongside the journal so a privacy wipe
cannot leave structural feedback behind.

## 7. Fingerprints

`ProofFingerprints` (`proof_fingerprints.dart`) produces two SHA-256 digests
from the admitted `mainObservation` text. Corrections are matched on these
rather than on raw text, so no comparison of user content leaves the device and
no model is ever asked whether its own output matches something the user
already rejected.

Both start from the same tokenisation: lower-case the statement, replace every
character that is not a Unicode letter, digit, whitespace, or apostrophe with a
space, and split on whitespace.

**`semanticFraming(statement, proofType)`** is deliberately lossy. The tokens
are put through a crude suffix fold (`ing`, `ed`, `es`, `s` are stripped, but
only when the word is longer than the suffix plus two characters, so short
words are left alone), filtered against a 47-word filler list, de-duplicated,
and sorted alphabetically before being digested as
`framing_v1|<proofType>|<words>`. Word order, casing, punctuation, inflection,
repetition, and filler words are all discarded. That is the point: trivial
paraphrases of a rejected statement collapse onto the same value and stay
suppressed, rather than the same rejected idea returning in a new sentence. The
`proofType` is mixed in — from `_provisionalProofType`, computed before
correction memory runs — so a rejected observation and a rejected repeat about
the same subject stay distinguishable. The filler list is kept small and
explicit on purpose; a larger one would start folding genuinely different
statements together.

**`wording(statement)`** is deliberately precise: it digests
`wording_v1|<tokens in original order>` with no stemming, no filler removal, and
no de-duplication. It changes whenever the sentence changes at all, which is
what lets "Wrong wording" reject a phrasing without rejecting the relationship
behind it.

Neither fingerprint is ever emitted to analytics. `fingerprint` appears in both
`ProofAnalyticsGuard.forbiddenExactKeys` and
`ProofAnalyticsGuard.forbiddenKeySubstrings`, and no fingerprint key appears on
the allowlist, so any attribute whose normalised key contains `fingerprint` is
dropped by the guard's first gate regardless of what a caller intended. They
exist only as local persistence and matching data.

## 8. Legacy migration

`ArchiveCorrectionMigration` is a pure, versioned, idempotent mapping from four
legacy feedback systems into canonical `ArchiveCorrection` records. It reads
legacy JSON and returns a correction or null; it never deletes, rewrites, or
mutates the legacy data, so legacy records stay available for audit and
rollback. `migrationVersion` is currently 2 (version 1 was the ad-hoc
per-surface mapping that preceded the table).

The legacy value is read from whichever field each system used
(`type`/`feedbackType`/`choice` for archive feedback, `choice`/`feedback` for
insight feedback, `feedbackState`/`feedback`/`choice` for proof quality,
`action`/`choice` for signal feedback) and normalised by lower-casing and
stripping every non-alphanumeric character, so `too_vague`, `tooVague`, and
`Too Vague` all match one row. `LegacyFeedbackSystem` records the origin in
`sourceSurface` (`legacy_archive_feedback`, `legacy_insight_feedback`,
`legacy_proof_quality`, `legacy_signal_feedback`) so a stored correction can
always be traced back.

| Row | Legacy values | Canonical choice | Qualifier |
| --- | --- | --- | --- |
| 1 | `accurate`, `fits`, `feelsRight`, `useful` | `exactlyRight` | — |
| 2 | `wrongAngle`, `anotherAngle` | `wrong`, downgraded to `wrongWording` only on an explicit wording-only marker | — |
| 3 | `tooGeneric`, `tooVague` | `wrongWording` | `scopeTooBroad` |
| 4 | `notQuite` | `partlyRight`, upgraded to `wrong` on stronger rejection evidence | — |
| 5 | `tooEarly` | `partlyRight` | `tooEarly` |
| 6 | `hide`, `hidden`, `hideThis` | `wrong`, artifact-scoped | — |
| 7 | `notRelated`, `wrongThread`, `notRelevant` | `wrongEvidence` | — |
| 8 | `notMe` | `wrong` | — |
| 9 | `notUseful` | `partlyRight` | — |
| 10 | `saveAsWatchTheme`, `background`, `watchLightly` | none — `null` | — |

Row 10 is recognised rather than unlisted, so deferral and save actions are
provably skipped instead of being guessed into a correction. Any value not in
the table also returns null: unrecognised legacy input is never guessed at.

The two refinements in rows 2 and 4 read closed-set structural markers only,
never legacy free text:

- **Row 2 downgrade** (`_wordingOnlyDowngrade`) fires on
  `wordingOnly: true`, `rejectionScope` of `wording`/`wording_only`, `reason` of
  `wrongWording`/`wording`, or `correctionAction` of
  `renamePattern`/`rewordOnly`. Absent an explicit marker the rejection stays a
  full `wrong`, so nothing is silently softened.
- **Row 4 upgrade** (`_strongerRejectionUpgrade`) fires on `hidden`,
  `rejected`, or `dismissed` being true; on `escalatedTo` or `followUpChoice`
  being one of `notMe`, `wrongAngle`, `hide`, `hidden`; or on `notQuiteCount`,
  `rejectionCount`, or `negativeCount` reaching
  `strongerRejectionRepeatThreshold` (2).

Migrated ids are deterministic: `correctionIdFor` digests the source surface,
archive scope, target proof id, and the legacy row's identity (`id`,
`feedbackId`, `recordId`, `legacyId`, or the seed's `legacyRecordId`, falling
back to `value:<normalised legacy value>` for blobs that stored one row per
proof). `migrationVersion` is deliberately excluded from that digest so a later
table version still recognises rows migrated by an earlier one. `migrateAll`
and `isAlreadyMigrated` use those ids to dedupe against existing corrections and
against earlier rows in the same batch. `createdAt` comes from the legacy
`createdAt`/`answeredAt`/`recordedAt` when parseable, otherwise from the seed.

`ArchiveCorrectionMigrationSeed` carries structural identifiers only — archive
scope, proof id, three fingerprints, affected evidence refs, a timestamp, and an
optional legacy row id. It has no field for legacy free text, and the migration
never reads text out of a legacy record.

## 9. Privacy boundaries

`ProofAnalyticsGuard.sanitize` runs inside `ProductAnalytics.track` before
anything else touches the payload, so it is not something a caller can forget.
Every attribute must clear three independent gates, and the guard never throws:
any internal failure drops the attribute.

1. **Forbidden rules, checked first and always winning.** The key is normalised
   to letters and digits only (so `entry_id`, `entryId`, and `Entry Id` all
   become `entryid`) and refused if it is a forbidden exact key or contains a
   forbidden substring. `structuralExemptions` currently holds one key,
   `prompt_type`, which bypasses the substring rule only — the exact-key rule
   still wins and the value gate still runs.
2. **Allowlist.** Unknown keys are refused by default, so a new
   content-bearing attribute cannot leak simply by not being listed yet.
3. **Value shape.** A value may only be a bool, a finite num (NaN and infinity
   are dropped), or a string matching `^[a-z0-9_]{1,40}$`. This is the gate that
   stops free text being smuggled through an otherwise legitimate key.

A payload is additionally capped at `maxAttributes` (25), below Firebase's own
limit, with the overflow dropped.

The proof-admission additions to the allowlist are exactly these eleven keys:

| Key | Carries |
| --- | --- |
| `admission_result` | The `ProofAdmissionOutcome` name as a snake-case token |
| `rejection_reason` | The internal reason token, snake-cased and truncated to 40 characters |
| `confidence_band` | `low`, `medium`, or `high` |
| `source_count_band` | `none`, `one`, `few`, `several`, `many` |
| `contradiction_count_band` | Same banding |
| `correction_choice` | An `ArchiveCorrectionChoice` name |
| `migration_version` | Integer |
| `scorer_version` | Integer |
| `verifier_version` | Integer |
| `config_version` | Integer |
| `duration_band` | `under_50ms`, `under_250ms`, `under_1s`, `under_5s`, `over_5s` |

The rest of `allowedKeys` is the `ActivationFunnelAnalytics` baseline — copied
rather than imported, so the guard has no dependency on feature code and cannot
be widened by an edit elsewhere — plus four structural keys used by existing
non-funnel events (`surface`, `kind`, `cohort_day`, `reflection_count`).

`ProofAdmissionAnalytics.payload` is a pure function precisely so the emitted
shape can be asserted in tests rather than inferred from what a provider
happened to receive. Counts are banded so a value can never single out one
archive, and durations are banded because a precise timing is a function of the
content that produced it.

### The never-list

These are refused as exact keys: `transcript(s)`, `quote(s)`,
`conclusion(s)`, `observation(s)`, `interpretation(s)`, `wording`, `note(s)`,
`prompt(s)`, `question(s)`, `theme(s)`, `topic(s)`, `label(s)`, `title(s)`,
`entryid`, `archiveid`, `proofid`, `evidenceid`, `fingerprint`, `score(s)`,
`rawscore`, `path`, `filepath`, `filename`, `stacktrace`, `errormessage`,
`recovery`, `key`, `apikey`, `secret`, `token`.

These are refused as substrings anywhere in the normalised key: `transcript`,
`quote`, `conclusion`, `observation`, `interpretation`, `wording`, `note`,
`prompt`, `question`, `theme`, `topic`, `label`, `title`, `entryid`,
`archiveid`, `proofid`, `evidenceid`, `fingerprint`, `stacktrace`,
`errormessage`, `filename`, `filepath`, `recovery`, `secret`, `token`,
`apikey`.

`score`, `path`, and `key` are exact-only on purpose: as substrings they would
also kill legitimate structural keys such as `score_band` and `scorer_version`,
and anything else containing them is already refused by the allowlist gate.

So, concretely, analytics never carries transcripts, quotes, statements,
conclusions, observations, user wording, preferred labels, correction notes,
themes, topics, titles, entry ids, archive ids, proof ids, evidence ids, any
fingerprint, any raw score, file paths, stack traces, or error messages. It
carries closed-set tokens, banded counts, banded durations, version integers,
and booleans.

Refusals themselves cannot become a leak. `AnalyticsGuardDrop` retains the
event name, the key, the reason, and the value's runtime *type* — never the
value. Stored drops are capped at 200 entries with `droppedCount` holding the
true total.

`ArchiveCorrection.preferredWording` is the user's own words about their own
archive: it stays archive-scoped, never reaches analytics or logs, and is never
treated as evidence for anything. Legacy plaintext correction notes are
deliberately not copied into canonical correction memory.

## 10. Visible versus internal scoring

The scoring machinery is internal. What a user sees is a band word and plain
prose.

- **No percentages, no numeric score.** `VerifiedProofViewModel` converts every
  quantitative dimension to a string or a null before any widget sees it. The
  weighted score computed in `_confidence` is consumed on the spot to pick a
  band and is never stored on `VerifiedProof` or the receipt.
- **Confidence is a band word only.** `confidenceLabelFor` yields exactly "Low
  confidence", "Medium confidence", or "High confidence" — and since a `low`
  band is not admitted, the shipping surfaces show one of the upper two.
- **No numeric importance score and no ranking dashboard.** Nothing surfaces a
  position, a rank, a percentile, or a comparative ordering of proofs.
  `ProofCandidateScorer.rank` exists as a pure function but nothing in `lib/`
  calls it (see [Known gaps](#known-gaps)).
- **Counts stay counts.** `frequencyLineFor` reports "Seen in N verified moments
  over D days" — or just "Seen in N verified moments" when the window is
  degenerate — and never a rate. Sparse logging must not be turned into an
  implied daily frequency, which is why `ProofFrequency` stores a count plus its
  window instead of a computed rate.
- **The UI cannot disagree with the receipt.** `ProofDetailSheet` only prints
  lines the view model already produced, and omits a heading entirely when its
  body is empty. `PostSaveBeliefInsight` deliberately does not recompute
  confidence or count references itself.
- **Trend and strength are described, not quantified.** They render as sentences
  like "This is coming up more often than it was." with no magnitude attached.

## 11. Call-site map

### Paths that call `CanonicalProofAdmissionService`

There is exactly one construction site in `lib/`:
`CapturePipelineService` (`lib/services/capture_pipeline_service.dart`), which
builds the service with `ArchiveCorrectionStore.instance` as its correction
policy. It calls `admit` from two places:

- `_postAndAdmit`, the shared helper behind the voice, typed, live-voice, typed
  fallback, and retry capture paths. It posts through
  `ApiClient.postAnalyzeRaw`, admits the response against a single
  `ProofSourceEntry` built from the transcript just captured (scopes
  `local_archive_v1` / `local_owner_v1`, revision from
  `UserContentSafety.privacyHash`), emits the
  `proof_admission_result` analytics event through
  `ProofAdmissionAnalytics.payload`, and throws a `FormatException` naming the
  outcome and reason when the response is not admitted. Callers fall back to a
  transcript-only local save.
- `saveRecoveredVaultEntry`, for a server-recovered offline live-audio vault
  entry, which admits the recovered reflection the same way.

An admitted proof is written to `JournalEntry.verifiedProof`, and
`JournalEntry.toJson`/`fromJson` round-trip it as versioned JSON. When a stored
proof exists, `JournalEntry.fromJson` prefers `verifiedProof.reflection` over
the entry's own stored reflection JSON, so the durable receipt wins over any
older generated text. Journal metadata transformations such as
`timeline_entry_display.dart` preserve `verifiedProof` when rebuilding an entry.

### Surfaces that accept only the admitted boundary

| Surface | Accepts |
| --- | --- |
| `PostSaveBeliefInsight` | Revalidates through `ProofDisplayGate` and renders only a `VerifiedProofViewModel`; renders nothing when the gate withdraws the proof |
| `ProofDetailSheet` | `VerifiedProofViewModel` only — its sole data dependency |
| `VerifiedProofCorrectionControls` | `VerifiedProof` only; derives its evidence picker from `VerifiedProofViewModel` |

Raw response maps and `ParsedConclusionCandidate` are application-layer DTOs.
Widgets must not import them. `JournalEntry.verifiedProof` is the durable
customer-proof boundary: a legacy entry without that receipt may still show its
user-authored transcript, but generated reflection fields must not be
resurfaced until revalidated.

## Known gaps

These are accurate statements about what is *not* wired, so the document does
not read as a claim that it is.

- **The stale note is unreachable.** Staleness withdraws a proof rather than
  annotating it, so no path sets `VerifiedProofViewModel.stale` to true and
  `ProofDetailSheet.staleNote` never appears. The flag and its rendering remain
  for a surface that wants to say "this was withdrawn, and why" instead of
  falling silent.
- **The undo surface has no screen.** `LocalPrivacyDataControls`
  exposes `ignoredObservations` and `stopIgnoring`, and
  `ArchiveCorrectionStore.undoIgnoreForever` is covered by tests, but no
  settings screen calls them yet — so the confirmation copy in
  `VerifiedProofCorrectionControls` promises an undo the customer cannot
  currently reach. Those two methods are also untestable today: importing
  `LocalPrivacyDataControls` pulls in `AppServices` and from there the part of
  `lib/` that does not compile.
- **Candidate ranking is unused.** `ProofCandidateScorer.rank` and its
  tie-breaking chain have no caller in `lib/`. Admission scores exactly one
  candidate per response through `score`, so the deterministic ordering is
  tested but not yet exercised in production.
- **Two feature inputs are hardwired.** In `_confidence`, `coverage` is always
  `1` and `stalePenalty` is always `false`, so their configured weights (`2.0`
  and `-1.5`) contribute a constant and nothing, respectively.
- **The recovered-vault path emits no admission analytics.** Only
  `_postAndAdmit` logs `proof_admission_result`; `saveRecoveredVaultEntry` does
  not.
- **Archive-policy and consent flags are always defaulted at the call site.**
  `CapturePipelineService` constructs its `ProofSourceEntry` without passing
  `deleted`, `archived`, `allowedByArchivePolicy`, or
  `remoteProcessingConsented`, so those verifier checks currently run against
  their defaults rather than against live archive-exclusion or consent state.
- **Only one legacy system is migrated at startup.**
  `ArchiveCorrectionStore.migrateLegacyArchiveFeedback` (called from
  `archive_me_startup.dart` after `configure` and `ensureLoaded`) now routes the
  `archive_insight_feedback` blob through `ArchiveCorrectionMigration.migrateAll`
  rather than its own inline mapping, so there is one reviewable table. The
  other three entry points — `fromInsightFeedbackJson`, `fromProofQualityJson`
  and `fromSignalFeedbackJson` — are implemented and tested but have no caller,
  because those stores' blobs are not read at startup yet. Skipping is by target
  proof id rather than correction id, so rows migrated by the earlier inline
  mapping are recognised and not duplicated.
- **A second correction abstraction is unused.**
  `ArchiveCorrectionRepository`, its `InMemoryArchiveCorrectionRepository`, and
  `ArchiveCorrectionPolicyLookup` / `ArchiveCorrectionPolicy` exist alongside
  `ArchiveCorrectionStore` but have no caller in `lib/`. The shipping policy
  implementation is `ArchiveCorrectionStore`, and it is the one that implements
  `ProofCorrectionAdmissionPolicy`.
- **`ArchiveCorrectionStore.decide` is synchronous and assumes loaded state.**
  It reads `_records` directly without awaiting `ensureLoaded`, so correction
  memory only influences admission when startup has already loaded it.
- **Archive/account switching is not called on a real switch.**
  `ArchiveCorrectionStore.switchArchive` drops the in-memory records and
  reloads, but nothing in `lib/` invokes it, because the app currently has a
  single hardcoded `local_archive_v1` scope. Isolation does not depend on it:
  both `decide` and the four history counters filter by archive scope on every
  lookup.

### Interpretation paths that do not route through admission

The comparison surface is the closest one and still separate.
`PatternComparisonExecutor`
(`lib/features/comparison_engine/domain/services/pattern_comparison_executor.dart`)
does verify quotes before display — `_verifyExactComparisonEvidence` requires
exactly one literal match of the past quote across visible historical moments
and exactly one match of the current quote in the current moment, requires the
two moments to be distinct and chronological, and requires the quotes to
differ — but it does so with its own `RegExp.escape` matcher rather than
`CanonicalEvidenceVerifier`, produces a `PatternEvidenceViewState` rather than a
`VerifiedProof`, and has no correction memory, quality receipt, or confidence
band. `PostSaveComparisonController` consumes provider text on that path.

Beyond it, `lib/features/` contains a large number of independent
interpretation engines that generate user-visible statements without passing
through proof admission at all. A representative, non-exhaustive list found by
searching for engine and analyser classes under `lib/features`:

- Insight generation: `ArchiveInsightsEngine`, `ContradictionInsightEngine`,
  `BlindSpotInsightEngine`, `BeliefEvolutionInsightEngine`,
  `PredictionInsightEngine`, `BeliefEvidenceEngine`, `PostSaveInsightEngine`,
  `InsightStrengthEngine`, `MostImportantInsightEngine`.
- Pattern and belief interpretation: `PatternMemoryEngine`,
  `PatternHypothesisEngine`, `PatternProgressEngine`, `HabitProofEngine`,
  `ThenNowEngine`, `BeliefUnderReviewEngine`, `ArchiveWasWrongEngine`,
  `BeliefDistanceEngine`, `IdentityEngine`.
- Comparison and contradiction: `ComparisonEngine`,
  `LocalTextComparisonEngine`, `ContradictionDetectionService`,
  `DiscoverContradictionEngine`, `ReturnComparisonEngine`.
- Discovery and synthesis: `DiscoverYourselfEngine`, `DiscoverBeliefEngine`,
  `DiscoverBlindSpotEngine`, `DiscoverChapterEngine`, `DailyDiscoveryEngine`,
  `SurpriseEngine`, `LifeChapterEngine`, and the `ArchiveSynthesisConclusion`
  models.
- Quality and framing: `InterpretationQualityEngine`,
  `InterpretationQualitySignalEngine`, `MomentQualityEngine`,
  `MemoryAuthorityFramingEngine`.

None of these produce a `VerifiedProof`, and none is covered by the hard
invariants in section 3. Routing a surface through admission means giving it a
`VerifiedProof` or a `VerifiedProofViewModel`; anything else is outside this
boundary.

## Verification

Focused tests for this feature live in `test/proof_admission/`:
`proof_admission_test.dart`, `proof_quality_test.dart`,
`proof_candidate_scoring_test.dart`, `proof_analytics_guard_test.dart`,
`proof_admission_analytics_test.dart`, `proof_architecture_guard_test.dart`,
`proof_detail_sheet_test.dart`, `archive_correction_test.dart`,
`archive_correction_migration_test.dart`,
`archive_correction_repository_test.dart`, `correction_semantics_test.dart`, and
`verified_proof_correction_controls_test.dart`.

Config drift is a separate gate: `dart run
tool/generate_proof_admission_weights.dart --check` fails when the generated
adapter no longer matches `config/proof_admission_weights.v1.json`.
