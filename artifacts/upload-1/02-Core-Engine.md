# ArchiveMe — Part 2: The Core Engine

This is the part of the system that actually differentiates the product: turning saved moments into claims that are *provable* and *correctable*.

---

## 1. Capture → protected storage → choice

The ordering here is the whole privacy design. **Audio is sealed and committed before the user is asked anything.** An earlier version destroyed the recording if the user declined online transcription; that is now structurally impossible, because the choice operates on already-persisted data.

```dart
/// A recording that is already sealed in the encrypted vault and committed to
/// the journal. Every disposition operates on this, never on raw plaintext.
final class ProtectedCapture {
  final String entryId;
  final String vaultReference;
  final int durationSeconds;
}

enum PostCaptureDisposition {
  transcribeOnDevice,   // 'On this device'
  transcribeOnline,     // 'Online'
  saveAudioOnly,        // 'Save without transcript'
  deleteRecording,      // 'Delete'
}
```

The user-facing copy states the guarantee plainly:

```dart
abstract final class PostCaptureCopy {
  static const title = 'Turn this recording into text?';
  static const body =
      'The audio is already saved in your encrypted vault on this device. '
      'Nothing leaves the device unless you choose Online.';
  static const onDeviceDetail =
      'The local model reads the audio on this device. No upload.';
  static const onlineDetail =
      'The audio is uploaded to our server and sent to OpenAI to produce a '
      'transcript. You are asked to agree first.';
  static const remoteDeclinedNote =
      'The recording stayed on this device. Nothing was uploaded.';
}
```

Invariants: no network call precedes disclosure; a save succeeds fully with transcription *and* interpretation declined; declining interpretation never blocks the archive; an existing entry can request analysis later.

**Microphone permission** is only *checked* when the Record screen appears and only *requested* after an explicit tap on Record.

---

## 2. Comparison dimensions

Two moments are never compared as raw strings. Each is reduced to the dimensions its own words support, and only dimensions observed in **both** may be compared. A dimension neither moment mentions is *absent*, not assumed equal.

```dart
enum ChangeDimension {
  situation,
  action,
  behaviouralResponse,
  emotionalState,
  emotionalIntensity,
  certainty,
  frequency,
  duration,
  stoppingOrCompletionBehaviour,
  copingResponse,
  outcome,
}
```

Labels are deliberately plain, never clinical or trait-like:

```dart
String get label => switch (this) {
  ChangeDimension.situation => 'the situation',
  ChangeDimension.action => 'what you did',
  ChangeDimension.behaviouralResponse => 'how you responded',
  ChangeDimension.emotionalState => 'how you felt',
  ChangeDimension.emotionalIntensity => 'how strongly you felt it',
  ChangeDimension.certainty => 'how certain you sounded',
  ChangeDimension.frequency => 'how often it happened',
  ChangeDimension.duration => 'how long it lasted',
  ChangeDimension.stoppingOrCompletionBehaviour => 'stopping or finishing',
  ChangeDimension.copingResponse => 'how you handled it',
  ChangeDimension.outcome => 'how it turned out',
};
```

An observation records the exact words that produced it, plus a position on an ordered scale when the dimension is graded:

```dart
class DimensionObservation {
  final ChangeDimension dimension;
  /// The exact lowercase words from the moment that produced this reading.
  final Set<String> markers;
  /// Position on the dimension's ordered scale, when graded. Null if categorical.
  final int? ordinal;
  bool get isGraded => ordinal != null;
}

enum DimensionDirection { increased, decreased, replaced, unchanged }

class DimensionMovement {
  final ChangeDimension dimension;
  final DimensionObservation before;
  final DimensionObservation after;
  final DimensionDirection direction;
  bool get isChange => direction != DimensionDirection.unchanged;
  /// e.g. "how certain you sounded: more"
  String get summary => '${dimension.label}: ${direction.label}';
}
```

`ChangeDimensionReader` handles diminishers: a graded marker consistently preceded by a word like "less" is demoted, so *"less certain"* does not read as high certainty.

---

## 3. Evidence citation

Every claim points at an exact span of the user's own text.

```dart
class TranscriptEvidenceCitation {
  final String entryId;
  final String quote;
  final int startUtf16;
  final int endUtf16;
  final TranscriptEvidenceRole role;      // supporting | contradicting | related
  final int? audioTimestampMs;
  final String? audioVaultReference;
  final DateTime? sourceCapturedAt;
  final EvidenceSourceType sourceType;    // voice | text | unknown
  final EvidenceTemporalRole temporalRole;// single | then | now
  final double confidenceScore;

  bool get hasPlayableAudio =>
      audioTimestampMs != null &&
      audioTimestampMs! >= 0 &&
      audioVaultReference?.trim().isNotEmpty == true;
}
```

`audioTimestampMs` stays `null` when no genuinely aligned timestamp exists. A fabricated zero would make the UI offer playback that jumps to the wrong place.

---

## 4. The two-gate trust path

**Nothing reaches the UI unless both gates pass.**

### Gate 1 — Exact-evidence validator
`ExplainableConclusionValidator` proves the quote physically exists at the cited offsets in the canonical transcript. `ExplainableConclusionRenderGate.visible(...)` returns a `ValidatedExplainableConclusion?` — non-null only when valid. It also rejects quotes that are entirely stop words, and enforces a minimum usable quote length.

### Gate 2 — Semantic conclusion gate
Proves the conclusion *follows from* the quote.

```dart
/// The semantic half of the V1 trust path.
///
/// The exact-evidence validator proves a quote exists. This gate proves the
/// conclusion follows from it. Both must pass before anything reaches the UI,
/// and an unresolved reading produces no conclusion rather than a hedged one.
abstract final class SemanticConclusionGate {
  static const minimumDerivedConfidence = 45;

  static SemanticConclusionAssessment assess({
    required ExplainableConclusion conclusion,
    required Map<String, String> canonicalTranscripts,
    Set<String> deletedEntryIds = const {},
  });
}
```

The rejection taxonomy is the specification of what "unsupported" means:

```dart
enum SemanticConclusionRejection {
  unrelatedSources,                 // not about the same subject or thread
  noComparableDimension,            // nothing in both moments is comparable
  changeWithoutMovedDimension,      // change claimed, nothing actually moved
  repeatWithoutConsistentDimensions,// repeat claimed, but a dimension moved
  conflictingDimensionEvidence,     // dimensions point opposite ways
  unsupportedClaimLanguage,         // asserts words the evidence never supports
  unsupportedDirectionClaim,        // asserts a direction not shown
  unsupportedCausalClaim,           // asserts cause where there is only sequence
  identityOrTraitClaim,             // a trait/diagnosis reading
  genericFraming,                   // says nothing specific to these moments
  generatedTextCitedAsEvidence,     // model output cited as the user's words
  deletedSource,                    // a cited moment no longer exists
  singleSourcePatternOrChange,      // one moment cannot establish a pattern
  sameEntryThenAndNow,              // Then and Now are the same moment
  belowConfidenceFloor,
}

class SemanticConclusionAssessment {
  final ChangeDimensions dimensions;
  final List<SemanticConclusionRejection> rejections;
  final ConclusionConfidenceSignals signals;

  /// True only when the conclusion text follows from the cited words.
  bool get isEntailed => rejections.isEmpty;
}
```

`generatedTextCitedAsEvidence` and `identityOrTraitClaim` are the two that most directly protect the product's honesty: the system may never quote itself back as proof, and may never turn an observation into a statement about who someone *is*.

---

## 5. Derived confidence

Confidence is computed from objective signals, never hardcoded. The user never sees a percentage — only a band.

```dart
int get value {
  if (!citationsValid || distinctSourceCount == 0) return 0;
  if (conflictingEvidence) return 0;
  var score = _base;
  score += switch (distinctSourceCount) { 1 => 10, 2 => 22, 3 => 30, _ => 34 };
  if (threadAligned) score += 8;
  if (userConfirmedThread) score += 6;
  if (chronologyOrdered) score += 6;
  if (comparableDimensionCount > 0) {
    score += (comparableDimensionCount.clamp(0, 3) * 4);
    score += (agreeingDimensionCount.clamp(0, 3) * 3);
  }
  score += (specificityScore.clamp(0, 1) * 12).round();
  if (ambiguous) score -= 14;
  if (userCorrectedFraming) score -= 10;
  return score.clamp(0, 95);
}
```

The score is capped at 95 — the system never claims certainty. Bands shown to the user:

```dart
enum EvidenceConfidenceBand {
  earlyObservation,        // 'Early observation'
  someSupportingEvidence,  // 'Some supporting evidence'
  repeatedAcrossMoments,   // 'Repeated across several moments'
  stronglySupported,       // 'Strongly supported by your archive'
}
```

User feedback affects *ranking*, not evidential confidence — a correction must not be able to manufacture evidence that does not exist.

---

## 6. ChangeThread — the ledger

Findings are organised into stable, user-correctable threads over time.

```dart
/// How a thread stands right now, in the reader's language.
///
/// There is no "corrected" status: a correction is something the user did to
/// a thread, not a finding about their life.
enum ChangeThreadStatus {
  firstObserved,  // 'First observed'
  repeated,       // 'Came up again'
  changed,        // 'Something changed'
  weakened,       // 'Eased off'
  strengthened,   // 'Grew stronger'
  unresolved,     // 'Not settled'
}

enum ChangeThreadCorrectionState {
  none,
  renamed,            // 'Renamed by you'
  split,              // 'Split by you'
  merged,             // 'Merged by you'
  framingSuppressed,  // 'Hidden by you'
  correctedByUser,    // 'Corrected by you'
}
```

That separation — status describes the evidence, correction state describes the user's authorship — is what makes the ledger honest rather than defensive.

### One dated finding

```dart
class ChangeEvent {
  final String eventId;
  final String threadId;
  final ExplainableInsightKind conclusionKind;   // observation | pattern | change
  final ChangeThreadStatus status;
  final List<ChangeDimension> changedDimensions;
  final List<TranscriptEvidenceCitation> exactEvidence; // asserted non-empty
  final DateTime occurredAt;
  final EvidenceConfidenceBand confidenceBand;
  final String uncertainty;
  final String alternativeExplanation;
  /// Reader-facing sentence taken verbatim from the validated conclusion.
  final String statement;
  final ChangeThreadCorrectionState correctionState;

  TranscriptEvidenceCitation get thenEvidence => exactEvidence.firstWhere(
    (i) => i.temporalRole == EvidenceTemporalRole.then,
    orElse: () => exactEvidence.first);

  TranscriptEvidenceCitation get nowEvidence => exactEvidence.lastWhere(
    (i) => i.temporalRole == EvidenceTemporalRole.now,
    orElse: () => exactEvidence.last);
}
```

`assert(exactEvidence.isNotEmpty)` means an unevidenced event cannot be constructed at all.

### Thread and projection

`ChangeThread` carries `threadId`, `archiveId`, `userEditableLabel`, `subjectRepresentation`, `firstObservedAt`, `latestObservedAt`, `currentStatus`, `evidenceEventIds`, `correctionState`, `visibilityState`, `policyVersion`, and `labelIsUserConfirmed`.

`labelIsUserConfirmed` is load-bearing: a label ArchiveMe inferred must never be presented on a commercial surface as though the user approved it. Only a user rename sets it true.

Corrections are an **append-only log** (rename, split, merge, suppress) replayed over the projection, so history is never rewritten:

```dart
ChangeThreadRepository.refresh();                 // re-derive + replay + persist
ChangeThreadRepository.correct(ChangeThreadCorrection); // append, then refresh
```

`ChangeThreadProjection` exposes visible threads (recent-first), ungrouped events, and `byId()`.
