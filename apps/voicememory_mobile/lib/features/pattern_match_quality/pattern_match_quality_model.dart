import 'pattern_match_quality_copy.dart';

enum PatternMatchConfidenceBand { weak, emerging, solid, strong }

extension PatternMatchConfidenceBandAnalytics on PatternMatchConfidenceBand {
  String get analyticsValue => switch (this) {
    PatternMatchConfidenceBand.weak => 'weak',
    PatternMatchConfidenceBand.emerging => 'emerging',
    PatternMatchConfidenceBand.solid => 'solid',
    PatternMatchConfidenceBand.strong => 'strong',
  };
}

enum PatternMatchDimension {
  sameTrigger,
  sameBehaviour,
  sameFeeling,
  sameContext,
  sameConsequence,
  sameHelpfulAction,
  sameAvoidancePattern,
  sameCorrectionFreshReturn,
}

extension PatternMatchDimensionAnalytics on PatternMatchDimension {
  String get analyticsValue => switch (this) {
    PatternMatchDimension.sameTrigger => 'same_trigger',
    PatternMatchDimension.sameBehaviour => 'same_behaviour',
    PatternMatchDimension.sameFeeling => 'same_feeling',
    PatternMatchDimension.sameContext => 'same_context',
    PatternMatchDimension.sameConsequence => 'same_consequence',
    PatternMatchDimension.sameHelpfulAction => 'same_helpful_action',
    PatternMatchDimension.sameAvoidancePattern => 'same_avoidance_pattern',
    PatternMatchDimension.sameCorrectionFreshReturn =>
      'same_correction_fresh_return',
  };
}

enum PatternMatchWeakReason {
  onlyGenericWordingOverlaps,
  onlyOneWeakDimensionMatches,
  entriesTooUnrelated,
  oldEvidenceOnly,
  userMarkedNotRelevant,
  noSafeAnchorAvailable,
  noChangeDeltaAvailable,
}

extension PatternMatchWeakReasonAnalytics on PatternMatchWeakReason {
  String get analyticsValue => switch (this) {
    PatternMatchWeakReason.onlyGenericWordingOverlaps =>
      'only_generic_wording_overlaps',
    PatternMatchWeakReason.onlyOneWeakDimensionMatches =>
      'only_one_weak_dimension_matches',
    PatternMatchWeakReason.entriesTooUnrelated => 'entries_too_unrelated',
    PatternMatchWeakReason.oldEvidenceOnly => 'old_evidence_only',
    PatternMatchWeakReason.userMarkedNotRelevant => 'user_marked_not_relevant',
    PatternMatchWeakReason.noSafeAnchorAvailable => 'no_safe_anchor_available',
    PatternMatchWeakReason.noChangeDeltaAvailable =>
      'no_change_delta_available',
  };
}

class PatternMatchQualityResult {
  const PatternMatchQualityResult({
    required this.shouldResolve,
    required this.entryCount,
    required this.source,
    required this.score,
    required this.confidenceBand,
    required this.matchedDimensions,
    required this.weakReasons,
    required this.safeExplanation,
    required this.shouldShowAsProof,
    required this.shouldShowAsWatchOnly,
  });

  factory PatternMatchQualityResult.hidden({
    required String source,
    required int entryCount,
  }) => PatternMatchQualityResult(
    shouldResolve: false,
    entryCount: entryCount,
    source: source,
    score: 0,
    confidenceBand: PatternMatchConfidenceBand.weak,
    matchedDimensions: const [],
    weakReasons: const [PatternMatchWeakReason.entriesTooUnrelated],
    safeExplanation: PatternMatchQualityCopy.weak,
    shouldShowAsProof: false,
    shouldShowAsWatchOnly: true,
  );

  final bool shouldResolve;
  final int entryCount;
  final String source;
  final int score;
  final PatternMatchConfidenceBand confidenceBand;
  final List<PatternMatchDimension> matchedDimensions;
  final List<PatternMatchWeakReason> weakReasons;
  final String safeExplanation;
  final bool shouldShowAsProof;
  final bool shouldShowAsWatchOnly;
}
