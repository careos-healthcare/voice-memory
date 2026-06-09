/// How specific a read is — based on concrete behaviour + context in text.
enum InterpretationSpecificityLevel {
  low,
  medium,
  high,
}

/// Where a read came from.
enum InterpretationSource {
  latestOnly,
  archiveRepeat,
  feedbackAdjusted,
  patternMemory,
}

/// Safety flags for unsupported or vague input.
enum InterpretationSafetyFlag {
  tooVague,
  tooSensitive,
  unsupported,
}

/// One evidence-grounded possible read on a moment.
class InterpretationRead {
  const InterpretationRead({
    required this.id,
    required this.title,
    required this.shortRead,
    required this.evidenceFragments,
    required this.evidenceTags,
    required this.specificityLevel,
    required this.strengthLabel,
    required this.whyThisRead,
    required this.whatWouldConfirm,
    required this.whatWouldContradict,
    required this.nextEvidencePrompt,
    required this.mightMean,
    required this.evidenceUsed,
    required this.alternativeAngleIds,
    required this.source,
    required this.categoryId,
    this.angleCategory,
    this.rankScore = 0,
    this.safetyFlags = const [],
  });

  final String id;
  final String title;
  final String shortRead;
  final List<String> evidenceFragments;
  final List<String> evidenceTags;
  final InterpretationSpecificityLevel specificityLevel;
  final String strengthLabel;
  final String whyThisRead;
  final String whatWouldConfirm;
  final String whatWouldContradict;
  final String nextEvidencePrompt;
  final String mightMean;
  final String evidenceUsed;
  final List<String> alternativeAngleIds;
  final InterpretationSource source;
  final String categoryId;
  final String? angleCategory;
  final double rankScore;
  final List<InterpretationSafetyFlag> safetyFlags;
}

/// Ranked interpretation output for post-save UI.
class InterpretationResult {
  const InterpretationResult({
    required this.reads,
    required this.needsClearerMoment,
    this.clearerMomentPrompt,
    this.clearerMomentTitle,
    this.archiveRepeatDetected = false,
    this.changedAngleDetected = false,
    this.loopUnsupported = false,
  });

  final List<InterpretationRead> reads;
  final bool needsClearerMoment;
  final String? clearerMomentPrompt;
  final String? clearerMomentTitle;
  final bool loopUnsupported;
  final bool archiveRepeatDetected;
  final bool changedAngleDetected;

  bool get hasReads => reads.isNotEmpty;
}
