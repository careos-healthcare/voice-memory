/// User correction for whether a past pattern still affects current thinking.
enum CurrentRelevanceAnswer { yes, little, notReally, notSure }

extension CurrentRelevanceAnswerLabels on CurrentRelevanceAnswer {
  String get analyticsValue => switch (this) {
    CurrentRelevanceAnswer.yes => 'yes',
    CurrentRelevanceAnswer.little => 'little',
    CurrentRelevanceAnswer.notReally => 'not_really',
    CurrentRelevanceAnswer.notSure => 'not_sure',
  };
}

/// Local answer record — proof key only, never transcript or pattern text.
class CurrentRelevanceRecord {
  const CurrentRelevanceRecord({
    required this.proofKey,
    required this.answer,
    required this.entryCountAtCapture,
    required this.createdAt,
  });

  final String proofKey;
  final CurrentRelevanceAnswer answer;
  final int entryCountAtCapture;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'proofKey': proofKey,
    'answer': answer.analyticsValue,
    'entryCountAtCapture': entryCountAtCapture,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  factory CurrentRelevanceRecord.fromJson(Map<String, dynamic> json) {
    final answerRaw = json['answer']?.toString() ?? '';
    return CurrentRelevanceRecord(
      proofKey: json['proofKey']?.toString() ?? '',
      answer: CurrentRelevanceAnswer.values.firstWhere(
        (value) => value.analyticsValue == answerRaw,
        orElse: () => CurrentRelevanceAnswer.notSure,
      ),
      entryCountAtCapture: json['entryCountAtCapture'] as int? ?? 0,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now().toUtc(),
    );
  }
}

/// Prompt or answered state for one confirmed-repeat foundation.
class CurrentRelevanceState {
  const CurrentRelevanceState({
    required this.proofKey,
    required this.entryCount,
    required this.hasConfirmedRepeat,
    this.answer,
  });

  final String proofKey;
  final int entryCount;
  final bool hasConfirmedRepeat;
  final CurrentRelevanceAnswer? answer;

  bool get isAnswered => answer != null;
  bool get isQuestionActive => answer == null;
}
