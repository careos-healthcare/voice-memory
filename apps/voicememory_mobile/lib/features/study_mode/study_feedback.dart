/// What a piece of participant feedback is about.
enum StudyFeedbackTopic { capture, result, speed, clarity, price, other }

/// The single thing that got in the participant's way, if anything did.
enum StudyFeedbackBlocker {
  none,
  confusing,
  tooSlow,
  notUseful,
  technicalProblem,
  privacyConcern,
}

extension StudyFeedbackTopicToken on StudyFeedbackTopic {
  String get token => switch (this) {
    StudyFeedbackTopic.capture => 'capture',
    StudyFeedbackTopic.result => 'result',
    StudyFeedbackTopic.speed => 'speed',
    StudyFeedbackTopic.clarity => 'clarity',
    StudyFeedbackTopic.price => 'price',
    StudyFeedbackTopic.other => 'other',
  };
}

extension StudyFeedbackBlockerToken on StudyFeedbackBlocker {
  String get token => switch (this) {
    StudyFeedbackBlocker.none => 'none',
    StudyFeedbackBlocker.confusing => 'confusing',
    StudyFeedbackBlocker.tooSlow => 'too_slow',
    StudyFeedbackBlocker.notUseful => 'not_useful',
    StudyFeedbackBlocker.technicalProblem => 'technical_problem',
    StudyFeedbackBlocker.privacyConcern => 'privacy_concern',
  };
}

/// One structured answer. Every field is a token, a small integer, or a date.
///
/// [hasPrivateNote] records only that the participant also wrote something;
/// the words live in [StudyPrivateNote], which the export never reads.
final class StudyFeedbackEntry {
  const StudyFeedbackEntry({
    required this.topic,
    required this.ease,
    required this.blocker,
    required this.submittedAt,
    required this.hasPrivateNote,
    this.schemaVersion = currentSchemaVersion,
  });

  static const currentSchemaVersion = 1;

  /// Inclusive bounds of the "how easy was this" answer.
  static const minEase = 1;
  static const maxEase = 5;

  final StudyFeedbackTopic topic;

  /// 1 (hard) to 5 (easy).
  final int ease;
  final StudyFeedbackBlocker blocker;
  final DateTime submittedAt;
  final bool hasPrivateNote;
  final int schemaVersion;

  static bool isValidEase(int ease) => ease >= minEase && ease <= maxEase;

  Map<String, Object?> toExportJson() => {
    'submitted_at': submittedAt.toUtc().toIso8601String(),
    'topic': topic.token,
    'ease': ease,
    'blocker': blocker.token,
    'has_private_note': hasPrivateNote ? 1 : 0,
  };

  Map<String, Object?> toJson() => {
    'topic': topic.token,
    'ease': ease,
    'blocker': blocker.token,
    'submittedAt': submittedAt.toUtc().toIso8601String(),
    'hasPrivateNote': hasPrivateNote,
    'schemaVersion': schemaVersion,
  };

  static StudyFeedbackEntry? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final topic = StudyFeedbackTopic.values
        .where((item) => item.token == json['topic'])
        .firstOrNull;
    final blocker = StudyFeedbackBlocker.values
        .where((item) => item.token == json['blocker'])
        .firstOrNull;
    final ease = (json['ease'] as num?)?.toInt();
    final submittedAt = DateTime.tryParse(
      json['submittedAt']?.toString() ?? '',
    );
    final schemaVersion = (json['schemaVersion'] as num?)?.toInt();

    if (topic == null ||
        blocker == null ||
        ease == null ||
        !isValidEase(ease) ||
        submittedAt == null ||
        schemaVersion != currentSchemaVersion) {
      return null;
    }

    return StudyFeedbackEntry(
      topic: topic,
      ease: ease,
      blocker: blocker,
      submittedAt: submittedAt.toUtc(),
      hasPrivateNote: json['hasPrivateNote'] == true,
      schemaVersion: schemaVersion!,
    );
  }
}
