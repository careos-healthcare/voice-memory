enum AiFeedbackState { pending, correct, incorrect, later }

class AiAccuracyFeedback {
  const AiAccuracyFeedback({
    required this.conclusionId,
    required this.confidencePercentage,
    this.feedbackState = AiFeedbackState.pending,
    this.feedbackTimestamp,
    this.correctionNote,
    this.engine = 'unknown',
  }) : assert(confidencePercentage >= 0 && confidencePercentage <= 100);

  final String conclusionId;
  final int confidencePercentage;
  final AiFeedbackState feedbackState;
  final DateTime? feedbackTimestamp;
  final String? correctionNote;
  final String engine;

  DateTime? get deferredUntil =>
      feedbackState == AiFeedbackState.later && feedbackTimestamp != null
      ? feedbackTimestamp!.add(const Duration(days: 7))
      : null;

  bool isDeferredAt(DateTime now) =>
      deferredUntil?.isAfter(now.toUtc()) == true;

  AiAccuracyFeedback copyWith({
    AiFeedbackState? feedbackState,
    DateTime? feedbackTimestamp,
    String? correctionNote,
  }) => AiAccuracyFeedback(
    conclusionId: conclusionId,
    confidencePercentage: confidencePercentage,
    feedbackState: feedbackState ?? this.feedbackState,
    feedbackTimestamp: feedbackTimestamp ?? this.feedbackTimestamp,
    correctionNote: correctionNote ?? this.correctionNote,
    engine: engine,
  );

  Map<String, dynamic> toJson() => {
    'conclusionId': conclusionId,
    'confidencePercentage': confidencePercentage,
    'feedbackState': feedbackState.name,
    'feedbackTimestamp': feedbackTimestamp?.toUtc().toIso8601String(),
    if (correctionNote?.trim().isNotEmpty == true)
      'correctionNote': correctionNote!.trim(),
    'engine': engine,
  };

  static AiAccuracyFeedback? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final conclusionId = json['conclusionId']?.toString() ?? '';
    final confidence = json['confidencePercentage'];
    if (conclusionId.isEmpty ||
        confidence is! int ||
        confidence < 0 ||
        confidence > 100) {
      return null;
    }
    AiFeedbackState state;
    try {
      final wireState =
          json['feedbackState']?.toString() ??
          json['userFeedbackState']?.toString() ??
          'pending';
      state = AiFeedbackState.values.byName(
        wireState == 'deferred' ? 'later' : wireState,
      );
    } on ArgumentError {
      return null;
    }
    return AiAccuracyFeedback(
      conclusionId: conclusionId,
      confidencePercentage: confidence,
      feedbackState: state,
      feedbackTimestamp: DateTime.tryParse(
        json['feedbackTimestamp']?.toString() ?? '',
      )?.toUtc(),
      correctionNote:
          json['correctionNote']?.toString() ??
          json['userCorrectionNote']?.toString(),
      engine: json['engine']?.toString() ?? 'unknown',
    );
  }
}

class AiAccuracyMetrics {
  const AiAccuracyMetrics({
    required this.correct,
    required this.incorrect,
    required this.later,
  });

  final int correct;
  final int incorrect;
  final int later;

  int get verified => correct + incorrect;
  double get accuracyPercentage => verified == 0 ? 0 : correct * 100 / verified;
}
