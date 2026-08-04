# Canonical proof admission

The shipping mobile application has one boundary for provider-generated proof:

`ApiClient.postAnalyzeRaw` → `CanonicalProofAdmissionService` → exact evidence
verification → claim admission → configured confidence scoring → immutable
`VerifiedProof` → encrypted journal persistence → `VerifiedProofViewModel` or a
widget that accepts `VerifiedProof`.

Raw response maps and `ParsedConclusionCandidate` are application-layer DTOs.
Widgets must not import them. `JournalEntry.verifiedProof` is the durable
customer-proof boundary. A legacy entry without that receipt may still show its
user-authored transcript, but generated reflection fields must not be
resurfaced until revalidated.

## Active call-site map

- Voice, typed, live voice, typed fallback, retry, and recovered-vault capture:
  `CapturePipelineService` calls `postAnalyzeRaw`, admits the response, and
  persists only the admitted reflection plus receipt. Rejection falls back to
  the existing local transcript-only save.
- Comparison: `PostSaveComparisonController` receives provider text, while
  `PatternComparisonExecutor` verifies both quotes against distinct canonical
  moments and chronology before constructing `PatternEvidenceViewState`.
  Deterministic local fallback uses the same verifier.
- Persistence: `JournalEntry.toJson/fromJson` stores the versioned proof and
  receipt. Journal metadata transformations preserve `verifiedProof`.
- Post-save UI: `PostSaveBeliefInsight` ignores entries without verified proof.
  `VerifiedProofCorrectionControls` accepts only `VerifiedProof`.
- Evidence UI: source excerpts use the user-authored transcript. A generated
  reflection is not substituted when a transcript is unavailable.

## Hard invariants

Hard failures are explicit and are never weights: missing/deleted/archived
source, owner/archive mismatch, generated placeholder evidence, missing remote
consent, stale revision, invalid UTF-16 boundary, inexact or ambiguous quote,
same-source comparison, invalid chronology, prohibited causal claim, and an
ignore-forever correction.

Final quote admission uses Dart UTF-16 offsets and exact `substring` equality.
When no offsets are supplied, a range is derived only for exactly one match.
No fuzzy matching or line-ending normalization occurs at final admission.

Secondary repetition, change, frequency, trend, strength, causal, and next
action claims are independently checked. Unsupported secondary claims are
removed and recorded in `ProofQualityReceipt.missingEvidence`; failure of the
main observation rejects the result.

## Soft ranking

`config/proof_admission_weights.v1.json` is the bundled source of truth.
`tool/generate_proof_admission_weights.dart` validates it and generates the
Dart adapter. The configuration cannot change hard safety. Values are bounded,
all keys are mandatory, model confidence is capped, and ties use validity,
source count, contradiction pressure, specificity, evidence newness, then a
stable candidate identifier.

Branch classification:

- A — hard safety: evidence and stale/scope checks in admission.
- B — product eligibility: minimum distinct sources and chronological windows.
- C — soft preference: `ProofFeatureVector` and `ProofCandidateScorer`.
- D — presentation: `VerifiedProofViewModel`.
- E — legacy: old archive/insight feedback remains readable and migrates to
  canonical structural corrections; it is not a new admission path.

## Corrections and privacy

`ArchiveCorrection` is versioned and archive-scoped. Choices are Exactly right,
Partly right, Wrong, Wrong wording, Wrong evidence, and Ignore forever.
`ArchiveCorrectionStore` persists structural fingerprints and source IDs only.
It has no plaintext-note API. Existing plaintext legacy notes are not copied
into canonical correction memory or sent to analytics/models.

Startup loads canonical corrections and migrates structural legacy feedback.
Ignore forever is a hard admission suppression; other choices contribute only
to bounded scoring features and never alter underlying evidence counts.

Transcript fingerprints and evidence fingerprints remain local persistence
data. They are not analytics fields. Proof correction telemetry must contain
only a fixed outcome/category and surface identifier.

## Verification

Focused tests cover exact and ambiguous quotes, Unicode/surrogate offsets,
source scope/deletion/archive state, revision staleness, claim minimums,
unsupported-claim removal, durable receipt round trips, correction migration
and archive isolation, config drift/validation, deterministic ranking, privacy
shape, and bounded admission cost.
