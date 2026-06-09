/// The one simple next action offered after a pattern progress payoff.
enum PatternNextActionType {
  repeatCheck,
  sharpenQuestion,
  lookForHelped,
  lookForHeavier,
  recordDifferentMoment,
}

extension PatternNextActionTypeIds on PatternNextActionType {
  String get id => name;
}

PatternNextActionType patternNextActionTypeFromId(String? raw) {
  for (final t in PatternNextActionType.values) {
    if (t.id == raw) return t;
  }
  return PatternNextActionType.sharpenQuestion;
}

/// A concrete, single next step the person can take tomorrow.
class PatternNextAction {
  const PatternNextAction({
    required this.id,
    required this.memoryId,
    required this.createdAt,
    required this.type,
    required this.title,
    required this.body,
    required this.question,
    required this.ctaLabel,
    required this.sourceProgressType,
    required this.sourceStatus,
  });

  final String id;
  final String memoryId;
  final DateTime createdAt;
  final PatternNextActionType type;
  final String title;
  final String body;
  final String question;
  final String ctaLabel;
  final String sourceProgressType;
  final String sourceStatus;

  Map<String, dynamic> toJson() => {
        'id': id,
        'memoryId': memoryId,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'type': type.id,
        'title': title,
        'body': body,
        'question': question,
        'ctaLabel': ctaLabel,
        'sourceProgressType': sourceProgressType,
        'sourceStatus': sourceStatus,
      };

  static PatternNextAction? fromJson(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;
    final id = map['id'] as String?;
    if (id == null || id.isEmpty) return null;
    final createdAt = DateTime.tryParse(map['createdAt'] as String? ?? '');
    if (createdAt == null) return null;
    return PatternNextAction(
      id: id,
      memoryId: map['memoryId'] as String? ?? '',
      createdAt: createdAt,
      type: patternNextActionTypeFromId(map['type'] as String?),
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      question: map['question'] as String? ?? '',
      ctaLabel: map['ctaLabel'] as String? ?? '',
      sourceProgressType: map['sourceProgressType'] as String? ?? 'none',
      sourceStatus: map['sourceStatus'] as String? ?? '',
    );
  }
}
