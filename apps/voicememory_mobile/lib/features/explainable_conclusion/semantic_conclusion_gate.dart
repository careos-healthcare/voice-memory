import 'change_dimensions.dart';
import 'conclusion_confidence_model.dart';
import 'explainable_conclusion.dart';

/// Why a candidate conclusion does not follow from its own evidence.
enum SemanticConclusionRejection {
  /// The cited moments are not about the same subject or thread.
  unrelatedSources,

  /// Nothing in both moments is directly comparable.
  noComparableDimension,

  /// A change is claimed but no comparable dimension actually moved.
  changeWithoutMovedDimension,

  /// A repeat is claimed but a comparable dimension moved.
  repeatWithoutConsistentDimensions,

  /// Comparable dimensions point in opposite directions.
  conflictingDimensionEvidence,

  /// The statement asserts words the cited evidence never supports.
  unsupportedClaimLanguage,

  /// The statement asserts a direction the evidence does not show.
  unsupportedDirectionClaim,

  /// The statement asserts cause where the evidence only shows sequence.
  unsupportedCausalClaim,

  /// A trait, identity or diagnosis reading rather than an evidenced one.
  identityOrTraitClaim,

  /// The statement says nothing specific to these moments.
  genericFraming,

  /// Model-generated text was cited as if it were the user's own words.
  generatedTextCitedAsEvidence,

  /// A cited moment no longer exists.
  deletedSource,

  /// Only one saved moment supports a pattern or change.
  singleSourcePatternOrChange,

  /// Then and Now resolve to the same saved moment.
  sameEntryThenAndNow,

  /// Confidence signals do not reach a showable reading.
  belowConfidenceFloor,
}

class SemanticConclusionAssessment {
  const SemanticConclusionAssessment({
    required this.dimensions,
    required this.rejections,
    required this.signals,
  });

  final ChangeDimensions dimensions;
  final List<SemanticConclusionRejection> rejections;
  final ConclusionConfidenceSignals signals;

  /// True only when the conclusion text follows from the cited words.
  bool get isEntailed => rejections.isEmpty;
}

/// The semantic half of the V1 trust path.
///
/// The exact-evidence validator proves a quote exists. This gate proves the
/// conclusion follows from it. Both must pass before anything reaches the UI,
/// and an unresolved reading produces no conclusion rather than a hedged one.
abstract final class SemanticConclusionGate {
  /// A showable conclusion must clear this derived floor.
  static const minimumDerivedConfidence = 45;

  static SemanticConclusionAssessment assess({
    required ExplainableConclusion conclusion,
    required Map<String, String> canonicalTranscripts,
    Set<String> deletedEntryIds = const {},
    Set<String> generatedTextEntryIds = const {},
    Map<String, String?> entryThreadIds = const {},
    Set<String> userConfirmedThreadIds = const {},
    bool userCorrectedFraming = false,
  }) {
    final rejections = <SemanticConclusionRejection>{};
    final supporting = conclusion.evidence
        .where((item) => item.role == TranscriptEvidenceRole.supporting)
        .toList(growable: false);
    final sourceIds = supporting.map((item) => item.entryId).toSet();

    // Every citation is scanned, not just the supporting ones. A contradicting
    // or related quote is rendered to the reader exactly like a supporting one,
    // so a deleted or app-authored source is just as damaging in those roles.
    if (conclusion.evidence.any(
      (item) => deletedEntryIds.contains(item.entryId),
    )) {
      rejections.add(SemanticConclusionRejection.deletedSource);
    }
    if (conclusion.evidence.any(
      (item) => generatedTextEntryIds.contains(item.entryId),
    )) {
      rejections.add(SemanticConclusionRejection.generatedTextCitedAsEvidence);
    }

    final isComparative = conclusion.kind != ExplainableInsightKind.observation;
    if (isComparative && sourceIds.length < 2) {
      rejections.add(SemanticConclusionRejection.singleSourcePatternOrChange);
    }

    final ordered = _chronological(supporting);
    final before = ordered.firstOrNull;
    final after = ordered.lastOrNull;
    if (isComparative &&
        before != null &&
        after != null &&
        before.entryId == after.entryId) {
      rejections.add(SemanticConclusionRejection.sameEntryThenAndNow);
    }

    final dimensions = isComparative && before != null && after != null
        ? ChangeDimensionReader.compare(
            before: before.quote,
            after: after.quote,
          )
        : const ChangeDimensions.empty();

    final threadIds = sourceIds
        .map((id) => entryThreadIds[id])
        .whereType<String>()
        .where((id) => id.trim().isNotEmpty)
        .toSet();
    final explicitThreadAlignment =
        threadIds.length == 1 && sourceIds.length > 1;
    final threadAligned =
        !isComparative ||
        explicitThreadAlignment ||
        dimensions.sharedSubjectMarkers.isNotEmpty;

    if (isComparative && !threadAligned) {
      rejections.add(SemanticConclusionRejection.unrelatedSources);
    }
    if (isComparative && !dimensions.hasComparableDimension) {
      rejections.add(SemanticConclusionRejection.noComparableDimension);
    }
    if (isComparative && dimensions.isConflicting) {
      rejections.add(SemanticConclusionRejection.conflictingDimensionEvidence);
    }
    if (conclusion.kind == ExplainableInsightKind.change &&
        dimensions.hasComparableDimension &&
        !dimensions.supportsChange) {
      rejections.add(SemanticConclusionRejection.changeWithoutMovedDimension);
    }
    if (conclusion.kind == ExplainableInsightKind.pattern &&
        dimensions.hasComparableDimension &&
        !dimensions.supportsRepeat) {
      rejections.add(
        SemanticConclusionRejection.repeatWithoutConsistentDimensions,
      );
    }

    final statement = conclusion.statement;
    if (_identityOrTrait.hasMatch(statement)) {
      rejections.add(SemanticConclusionRejection.identityOrTraitClaim);
    }
    if (_generic.hasMatch(statement.trim())) {
      rejections.add(SemanticConclusionRejection.genericFraming);
    }

    final evidenceTokens = {
      for (final citation in supporting) ..._contentTokens(citation.quote),
    };
    final permitted = <String>{
      ...evidenceTokens,
      ..._framingVocabulary,
      for (final movement in dimensions.movements)
        ..._contentTokens(movement.dimension.label),
    };
    final unsupported = _contentTokens(statement).difference(permitted);
    if (unsupported.isNotEmpty) {
      rejections.add(SemanticConclusionRejection.unsupportedClaimLanguage);
    }

    if (_causalClaim.hasMatch(statement) &&
        !supporting.any((item) => _causalClaim.hasMatch(item.quote))) {
      rejections.add(SemanticConclusionRejection.unsupportedCausalClaim);
    }

    final claimedDirection = _claimedDirection(statement);
    if (claimedDirection != null &&
        !dimensions.changed.any(
          (movement) => movement.direction == claimedDirection,
        ) &&
        !supporting.any(
          (item) => _claimedDirection(item.quote) == claimedDirection,
        )) {
      rejections.add(SemanticConclusionRejection.unsupportedDirectionClaim);
    }

    final signals = ConclusionConfidenceModel.forComparison(
      dimensions: dimensions,
      quotes: supporting.map((item) => item.quote),
      distinctSourceCount: sourceIds.length,
      citationsValid: supporting.every(
        (item) => canonicalTranscripts.containsKey(item.entryId),
      ),
      chronologyOrdered:
          !isComparative ||
          (before?.sourceCapturedAt != null &&
              after?.sourceCapturedAt != null &&
              before!.sourceCapturedAt!.isBefore(after!.sourceCapturedAt!)),
      threadAligned: threadAligned,
      isComparative: isComparative,
      userConfirmedThread: threadIds.any(userConfirmedThreadIds.contains),
      userCorrectedFraming: userCorrectedFraming,
    );
    if (signals.value < minimumDerivedConfidence) {
      rejections.add(SemanticConclusionRejection.belowConfidenceFloor);
    }

    return SemanticConclusionAssessment(
      dimensions: dimensions,
      rejections: List.unmodifiable(rejections),
      signals: signals,
    );
  }

  static List<TranscriptEvidenceCitation> _chronological(
    List<TranscriptEvidenceCitation> supporting,
  ) {
    final dated =
        supporting.where((item) => item.sourceCapturedAt != null).toList()
          ..sort((a, b) => a.sourceCapturedAt!.compareTo(b.sourceCapturedAt!));
    return dated.isEmpty ? supporting : dated;
  }

  static DimensionDirection? _claimedDirection(String value) {
    final tokens = _allTokens(value);
    final increased = tokens.intersection(_increaseWords).isNotEmpty;
    final decreased = tokens.intersection(_decreaseWords).isNotEmpty;
    if (increased && !decreased) return DimensionDirection.increased;
    if (decreased && !increased) return DimensionDirection.decreased;
    return null;
  }

  static final RegExp _word = RegExp(r"[a-z0-9']+");

  static final RegExp _identityOrTrait = RegExp(
    r'\b(?:you are|you\x27re|your personality|personality trait|'
    r'diagnos(?:is|ed)|disorder|deep truth|who you really are|'
    r'you always|you never|type of person|kind of person)\b',
    caseSensitive: false,
  );

  static final RegExp _generic = RegExp(
    r'^(?:this (?:may|might|could) (?:be|mean)|something (?:may|might)|'
    r'you may be experiencing|there (?:may|might) be|a possible pattern|'
    r'things (?:may|might))',
    caseSensitive: false,
  );

  static final RegExp _causalClaim = RegExp(
    r'\b(?:because|caused|causes|causing|made you|makes you|led to|leads to|'
    r'due to|results? in|resulted in|so that\x27s why)\b',
    caseSensitive: false,
  );

  static const _increaseWords = {
    'more',
    'increased',
    'stronger',
    'longer',
    'higher',
    // 'often' is deliberately absent. On its own it states frequency, not a
    // direction — "less often" is a decrease. It also appears in the frequency
    // dimension's own label ("how often it happened"), so treating it as an
    // increase made the engine read a claim out of its own wording and reject
    // every frequency decrease. The direction is carried by more/less.
    'frequently',
    'repeatedly',
    'grew',
    'rose',
    'escalated',
    'certain',
    'sure',
  };

  static const _decreaseWords = {
    'less',
    'reduced',
    'weaker',
    'shorter',
    'lower',
    'rarely',
    'eased',
    'faded',
    'calmer',
    'settled',
    'shrank',
    'dropped',
  };

  /// Words a conclusion may use to frame a reading without asserting new
  /// content. Everything else in a statement must come from the evidence.
  static const _framingVocabulary = {
    'across',
    'again',
    'appears',
    'between',
    'changed',
    'change',
    'comparable',
    'compared',
    'comparison',
    'consistent',
    'continues',
    'described',
    'describes',
    'different',
    'differs',
    'earlier',
    'evidence',
    'happened',
    'held',
    'later',
    'looks',
    'mention',
    'mentioned',
    'mentions',
    'moment',
    'moments',
    'moved',
    'newer',
    'noted',
    'observation',
    'recorded',
    'pattern',
    'possible',
    'recurring',
    'remained',
    'repeat',
    'repeated',
    'repeating',
    'saved',
    'shifted',
    'showed',
    'shows',
    'similar',
    'sounds',
    'stayed',
    'steady',
    'supported',
    'these',
    'unchanged',
    'wording',
    'words',
  };

  static const _stopWords = {
    'about',
    'after',
    'again',
    'also',
    'been',
    'before',
    'being',
    'could',
    'does',
    'doing',
    'each',
    'even',
    'from',
    'have',
    'here',
    'into',
    'just',
    'like',
    'much',
    'must',
    'only',
    'over',
    'same',
    'some',
    'such',
    'than',
    'that',
    'their',
    'them',
    'then',
    'there',
    'these',
    'they',
    'this',
    'those',
    'through',
    'very',
    'were',
    'what',
    'when',
    'where',
    'which',
    'while',
    'with',
    'would',
    'your',
  };

  static Set<String> _allTokens(String value) => _word
      .allMatches(value.toLowerCase())
      .map((match) => match.group(0)!)
      .toSet();

  static Set<String> _contentTokens(String value) => _allTokens(value)
      .where((token) => token.length >= 4 && !_stopWords.contains(token))
      .map(_stem)
      .toSet();

  static String _stem(String token) => switch (token) {
    'answered' ||
    'answering' ||
    'answers' ||
    'responded' ||
    'responding' ||
    'response' ||
    'responses' => 'answer',
    'paused' || 'pausing' || 'pause' => 'pause',
    'planned' || 'planning' || 'plans' => 'plan',
    'replied' || 'replying' || 'replies' => 'reply',
    'checked' || 'checking' => 'check',
    'finished' || 'finishing' => 'finish',
    'stopped' || 'stopping' => 'stop',
    'started' || 'starting' => 'start',
    'meetings' => 'meeting',
    'messages' => 'message',
    'deadlines' => 'deadline',
    'feelings' => 'feeling',
    _ => token,
  };
}
