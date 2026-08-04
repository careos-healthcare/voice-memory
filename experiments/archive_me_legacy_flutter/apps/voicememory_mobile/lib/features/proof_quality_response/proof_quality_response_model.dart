import 'proof_quality_response_copy.dart';

/// Surfaces where proof quality response can appear.
enum ProofQualityResponseSurface {
  timelineProofMoment,
  firstProofPayoff,
  patterns,
  archiveTimelineSpine,
}

extension ProofQualityResponseSurfaceStorage on ProofQualityResponseSurface {
  String get storageValue => switch (this) {
    ProofQualityResponseSurface.timelineProofMoment => 'timeline_proof_moment',
    ProofQualityResponseSurface.firstProofPayoff => 'first_proof_payoff',
    ProofQualityResponseSurface.patterns => 'patterns',
    ProofQualityResponseSurface.archiveTimelineSpine =>
      'archive_timeline_spine',
  };
}

/// Resolved feedback state driving the response card.
enum ProofQualityFeedbackState {
  useful,
  tooVague,
  alreadyKnewThis,
  notRelevant,
  none,
}

extension ProofQualityFeedbackStateStorage on ProofQualityFeedbackState {
  String get analyticsValue => switch (this) {
    ProofQualityFeedbackState.useful => 'useful',
    ProofQualityFeedbackState.tooVague => 'too_vague',
    ProofQualityFeedbackState.alreadyKnewThis => 'already_knew_this',
    ProofQualityFeedbackState.notRelevant => 'not_relevant',
    ProofQualityFeedbackState.none => 'none',
  };
}

/// Unified answer type for analytics — metadata only.
enum ProofQualityResponseAnswerType {
  stillTooVague,
  cameBackStronger,
  feltLighter,
  somethingHelped,
  noChange,
  keepAsBackground,
  watchLightly,
  relevantAgain,
}

extension ProofQualityResponseAnswerTypeStorage
    on ProofQualityResponseAnswerType {
  String get analyticsValue => switch (this) {
    ProofQualityResponseAnswerType.stillTooVague => 'still_too_vague',
    ProofQualityResponseAnswerType.cameBackStronger => 'came_back_stronger',
    ProofQualityResponseAnswerType.feltLighter => 'felt_lighter',
    ProofQualityResponseAnswerType.somethingHelped => 'something_helped',
    ProofQualityResponseAnswerType.noChange => 'no_change',
    ProofQualityResponseAnswerType.keepAsBackground => 'keep_as_background',
    ProofQualityResponseAnswerType.watchLightly => 'watch_lightly',
    ProofQualityResponseAnswerType.relevantAgain => 'relevant_again',
  };
}

/// Resolved proof quality response — safe metadata only, no journal text.
class ProofQualityResponseResult {
  const ProofQualityResponseResult({
    required this.shouldShow,
    required this.feedbackState,
    required this.surface,
    required this.proofKey,
    required this.entryCount,
    required this.source,
    required this.hasConfirmedRepeat,
    required this.hasSafeAnchor,
    required this.hasFreshReturn,
    required this.title,
    required this.body,
    required this.footer,
    required this.rows,
    required this.evidenceAnchors,
    required this.usesFallbackEvidenceLine,
    required this.deltaLine,
    required this.returnedAfterCorrectionLine,
    required this.stillTooVagueFollowUp,
  });

  final bool shouldShow;
  final ProofQualityFeedbackState feedbackState;
  final ProofQualityResponseSurface surface;
  final String proofKey;
  final int entryCount;
  final String source;
  final bool hasConfirmedRepeat;
  final bool hasSafeAnchor;
  final bool hasFreshReturn;
  final String title;
  final String body;
  final String footer;
  final List<String> rows;
  final List<String> evidenceAnchors;
  final bool usesFallbackEvidenceLine;
  final String? deltaLine;
  final String returnedAfterCorrectionLine;
  final bool stillTooVagueFollowUp;

  factory ProofQualityResponseResult.hidden({
    required ProofQualityResponseSurface surface,
    required String source,
    int entryCount = 0,
  }) => ProofQualityResponseResult(
    shouldShow: false,
    feedbackState: ProofQualityFeedbackState.none,
    surface: surface,
    proofKey: '',
    entryCount: entryCount,
    source: source,
    hasConfirmedRepeat: false,
    hasSafeAnchor: false,
    hasFreshReturn: false,
    title: '',
    body: '',
    footer: ProofQualityResponseCopy.footer,
    rows: const [],
    evidenceAnchors: const [],
    usesFallbackEvidenceLine: true,
    deltaLine: null,
    returnedAfterCorrectionLine:
        ProofQualityResponseCopy.returnedAfterCorrectionLine,
    stillTooVagueFollowUp: false,
  );
}

class ProofQualityResponseRecord {
  const ProofQualityResponseRecord({
    this.answerType,
    this.feedbackState,
    this.proofKey,
    this.surface,
    this.entryCount,
    this.answeredAt,
    this.stillTooVague = false,
  });

  static const empty = ProofQualityResponseRecord();

  final ProofQualityResponseAnswerType? answerType;
  final ProofQualityFeedbackState? feedbackState;
  final String? proofKey;
  final ProofQualityResponseSurface? surface;
  final int? entryCount;
  final DateTime? answeredAt;
  final bool stillTooVague;

  bool get answered => answerType != null;

  Map<String, dynamic> toJson() => {
    if (answerType != null) 'answerType': answerType!.analyticsValue,
    if (feedbackState != null) 'feedbackState': feedbackState!.analyticsValue,
    if (proofKey != null) 'proofKey': proofKey,
    if (surface != null) 'surface': surface!.storageValue,
    if (entryCount != null) 'entryCount': entryCount,
    if (answeredAt != null) 'answeredAt': answeredAt!.toUtc().toIso8601String(),
    if (stillTooVague) 'stillTooVague': true,
  };

  factory ProofQualityResponseRecord.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return empty;
    return ProofQualityResponseRecord(
      answerType: _answerFromRaw(json['answerType'] as String?),
      feedbackState: _feedbackFromRaw(json['feedbackState'] as String?),
      proofKey: json['proofKey'] is String ? json['proofKey'] as String : null,
      surface: _surfaceFromRaw(json['surface'] as String?),
      entryCount: json['entryCount'] is int ? json['entryCount'] as int : null,
      answeredAt: _timestampFromRaw(json['answeredAt'] as String?),
      stillTooVague: json['stillTooVague'] == true,
    );
  }

  static ProofQualityResponseAnswerType? _answerFromRaw(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return ProofQualityResponseAnswerType.values.firstWhere(
      (value) => value.analyticsValue == raw,
      orElse: () => ProofQualityResponseAnswerType.noChange,
    );
  }

  static ProofQualityFeedbackState? _feedbackFromRaw(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return ProofQualityFeedbackState.values.firstWhere(
      (value) => value.analyticsValue == raw,
      orElse: () => ProofQualityFeedbackState.none,
    );
  }

  static ProofQualityResponseSurface? _surfaceFromRaw(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return ProofQualityResponseSurface.values.firstWhere(
      (value) => value.storageValue == raw,
      orElse: () => ProofQualityResponseSurface.timelineProofMoment,
    );
  }

  static DateTime? _timestampFromRaw(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}
