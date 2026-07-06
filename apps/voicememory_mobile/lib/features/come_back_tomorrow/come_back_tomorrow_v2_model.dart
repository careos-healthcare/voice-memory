/// Local active watch target — phrase stored for UI only, never analytics.
class ActiveWatchTarget {
  const ActiveWatchTarget({
    required this.watchKey,
    required this.groundedPhrase,
    required this.createdDateKey,
    required this.source,
    this.lastAnsweredDateKey,
    this.lastResponseType,
    this.unrelatedSaveCount = 0,
    this.quietSignalDismissed = false,
  });

  final String watchKey;
  final String groundedPhrase;
  final String createdDateKey;
  final String source;
  final String? lastAnsweredDateKey;
  final String? lastResponseType;
  final int unrelatedSaveCount;
  final bool quietSignalDismissed;

  bool get hasGroundedPhrase => groundedPhrase.trim().isNotEmpty;

  ActiveWatchTarget copyWith({
    String? watchKey,
    String? groundedPhrase,
    String? createdDateKey,
    String? source,
    String? lastAnsweredDateKey,
    String? lastResponseType,
    int? unrelatedSaveCount,
    bool? quietSignalDismissed,
  }) =>
      ActiveWatchTarget(
        watchKey: watchKey ?? this.watchKey,
        groundedPhrase: groundedPhrase ?? this.groundedPhrase,
        createdDateKey: createdDateKey ?? this.createdDateKey,
        source: source ?? this.source,
        lastAnsweredDateKey: lastAnsweredDateKey ?? this.lastAnsweredDateKey,
        lastResponseType: lastResponseType ?? this.lastResponseType,
        unrelatedSaveCount: unrelatedSaveCount ?? this.unrelatedSaveCount,
        quietSignalDismissed:
            quietSignalDismissed ?? this.quietSignalDismissed,
      );
}

/// Post-save watch card content.
class ComeBackTomorrowPostSaveWatch {
  const ComeBackTomorrowPostSaveWatch({
    required this.title,
    required this.body,
    required this.groundedPhrase,
    required this.footer,
    required this.source,
  });

  final String title;
  final String body;
  final String groundedPhrase;
  final String footer;
  final String source;
}

/// Return-day question content.
class ComeBackTomorrowReturnQuestion {
  const ComeBackTomorrowReturnQuestion({
    required this.title,
    required this.body,
    required this.groundedPhrase,
    required this.daysSinceSet,
    required this.source,
  });

  final String title;
  final String body;
  final String groundedPhrase;
  final int daysSinceSet;
  final String source;
}

/// Quiet signal when a watch target has not appeared recently.
class ComeBackTomorrowQuietSignal {
  const ComeBackTomorrowQuietSignal({
    required this.title,
    required this.body,
    required this.footer,
    required this.cta,
    required this.daysSinceSet,
    required this.source,
  });

  final String title;
  final String body;
  final String footer;
  final String cta;
  final int daysSinceSet;
  final String source;
}

/// User response on the return-day question.
enum ComeBackTomorrowAnswerType {
  cameBack,
  notToday,
  different,
}
