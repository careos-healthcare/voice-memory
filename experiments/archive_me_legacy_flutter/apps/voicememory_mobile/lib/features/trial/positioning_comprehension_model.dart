/// Trial-only answer to “What did ArchiveMe feel most like?”
enum PositioningComprehensionAnswer { archiveMemory, journal, chat, notSure }

extension PositioningComprehensionAnswerIds on PositioningComprehensionAnswer {
  String get id => name;
}

PositioningComprehensionAnswer? positioningComprehensionAnswerFromId(
  String? raw,
) {
  if (raw == null) return null;
  for (final a in PositioningComprehensionAnswer.values) {
    if (a.id == raw) return a;
  }
  return null;
}

/// Labels shown only in trial/developer comprehension survey.
abstract class PositioningComprehensionCopy {
  PositioningComprehensionCopy._();

  static const String question = 'What did ArchiveMe feel most like?';
  static const String followUpQuestion = 'What made you choose that?';
  static const String archiveMemoryLabel = 'A memory for patterns';
  static const String journalLabel = 'A journal';
  static const String chatLabel = 'A chat';
  static const String notSureLabel = 'Not sure';

  static String labelFor(PositioningComprehensionAnswer answer) =>
      switch (answer) {
        PositioningComprehensionAnswer.archiveMemory => archiveMemoryLabel,
        PositioningComprehensionAnswer.journal => journalLabel,
        PositioningComprehensionAnswer.chat => chatLabel,
        PositioningComprehensionAnswer.notSure => notSureLabel,
      };
}

class PositioningComprehensionResponse {
  const PositioningComprehensionResponse({
    required this.answer,
    required this.recordedAt,
    this.followUp,
  });

  final PositioningComprehensionAnswer answer;
  final DateTime recordedAt;
  final String? followUp;

  Map<String, dynamic> toJson() => {
    'answer': answer.id,
    'recordedAt': recordedAt.toUtc().toIso8601String(),
    if (followUp != null && followUp!.trim().isNotEmpty)
      'followUp': followUp!.trim(),
  };

  static PositioningComprehensionResponse? fromJson(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;
    final answer = positioningComprehensionAnswerFromId(
      map['answer'] as String?,
    );
    final recordedAt = DateTime.tryParse(map['recordedAt'] as String? ?? '');
    if (answer == null || recordedAt == null) return null;
    return PositioningComprehensionResponse(
      answer: answer,
      recordedAt: recordedAt,
      followUp: map['followUp'] as String?,
    );
  }
}

class PositioningComprehensionSummary {
  const PositioningComprehensionSummary({
    required this.askedCount,
    required this.answeredCount,
    required this.archiveMemoryCount,
    required this.journalCount,
    required this.chatCount,
    required this.notSureCount,
  });

  final int askedCount;
  final int answeredCount;
  final int archiveMemoryCount;
  final int journalCount;
  final int chatCount;
  final int notSureCount;

  /// Pass when at least 3 of 5 trial users chose archive memory framing.
  bool get pass => answeredCount >= 5 && archiveMemoryCount >= 3;

  double? get archiveMemoryRate =>
      answeredCount == 0 ? null : archiveMemoryCount / answeredCount;
}
