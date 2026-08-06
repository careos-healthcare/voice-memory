/// Early archive proof surfaces that accept insight accuracy feedback.
enum EarlyArchiveInsightType {
  confirmedRepeat,
  timeline,
  triggerPayoff,
  softeningNotice,
  helpfulActionPayoff,
}

/// Local feedback choice — metadata only, never journal text.
enum EarlyArchiveInsightFeedbackValue { feelsRight, notQuite, wrongPattern }

extension EarlyArchiveInsightTypeAnalytics on EarlyArchiveInsightType {
  String get analyticsStage => switch (this) {
    EarlyArchiveInsightType.confirmedRepeat => 'confirmed_repeat',
    EarlyArchiveInsightType.timeline => 'timeline',
    EarlyArchiveInsightType.triggerPayoff => 'trigger_payoff',
    EarlyArchiveInsightType.softeningNotice => 'softening_notice',
    EarlyArchiveInsightType.helpfulActionPayoff => 'helpful_action_payoff',
  };
}

extension EarlyArchiveInsightFeedbackValueAnalytics
    on EarlyArchiveInsightFeedbackValue {
  String get analyticsReason => switch (this) {
    EarlyArchiveInsightFeedbackValue.feelsRight => 'feels_right',
    EarlyArchiveInsightFeedbackValue.notQuite => 'not_quite',
    EarlyArchiveInsightFeedbackValue.wrongPattern => 'wrong_pattern',
  };
}

class EarlyArchiveInsightFeedbackRecord {
  const EarlyArchiveInsightFeedbackRecord({
    required this.insightType,
    required this.value,
    required this.entryCount,
    required this.surface,
    required this.createdAt,
  });

  final EarlyArchiveInsightType insightType;
  final EarlyArchiveInsightFeedbackValue value;
  final int entryCount;
  final String surface;
  final DateTime createdAt;

  String get storageKey => '${insightType.name}|$surface|$entryCount';

  Map<String, dynamic> toJson() => {
    'insightType': insightType.name,
    'value': value.name,
    'entryCount': entryCount,
    'surface': surface,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  factory EarlyArchiveInsightFeedbackRecord.fromJson(
    Map<String, dynamic> json,
  ) {
    return EarlyArchiveInsightFeedbackRecord(
      insightType: EarlyArchiveInsightType.values.firstWhere(
        (type) => type.name == json['insightType'],
        orElse: () => EarlyArchiveInsightType.confirmedRepeat,
      ),
      value: EarlyArchiveInsightFeedbackValue.values.firstWhere(
        (value) => value.name == json['value'],
        orElse: () => EarlyArchiveInsightFeedbackValue.feelsRight,
      ),
      entryCount: (json['entryCount'] as num?)?.toInt() ?? 0,
      surface: json['surface'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
