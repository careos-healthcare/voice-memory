/// How a pattern has moved across several check-ins.
enum PatternProgressType {
  gettingLighter,
  gettingHeavier,
  stillRepeating,
  changing,
  notEnoughYet,
}

extension PatternProgressTypeIds on PatternProgressType {
  String get id => name;
}

PatternProgressType patternProgressTypeFromId(String? raw) {
  for (final t in PatternProgressType.values) {
    if (t.id == raw) return t;
  }
  return PatternProgressType.notEnoughYet;
}

/// A clear payoff shown after enough check-ins: "here is what changed".
class PatternProgressMoment {
  const PatternProgressMoment({
    required this.id,
    required this.memoryId,
    required this.createdAt,
    required this.type,
    required this.headline,
    required this.body,
    required this.nextLine, required this.checkInCount, required this.shouldShow, this.beforeLine,
    this.helpedLine,
  });

  final String id;
  final String memoryId;
  final DateTime createdAt;
  final PatternProgressType type;
  final String headline;
  final String body;
  final String? beforeLine;
  final String? helpedLine;
  final String nextLine;
  final int checkInCount;
  final bool shouldShow;

  Map<String, dynamic> toJson() => {
    'id': id,
    'memoryId': memoryId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'type': type.id,
    'headline': headline,
    'body': body,
    if (beforeLine != null) 'beforeLine': beforeLine,
    if (helpedLine != null) 'helpedLine': helpedLine,
    'nextLine': nextLine,
    'checkInCount': checkInCount,
    'shouldShow': shouldShow,
  };

  static PatternProgressMoment? fromJson(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;
    final id = map['id'] as String?;
    if (id == null || id.isEmpty) return null;
    final createdAt = DateTime.tryParse(map['createdAt'] as String? ?? '');
    if (createdAt == null) return null;
    return PatternProgressMoment(
      id: id,
      memoryId: map['memoryId'] as String? ?? '',
      createdAt: createdAt,
      type: patternProgressTypeFromId(map['type'] as String?),
      headline: map['headline'] as String? ?? '',
      body: map['body'] as String? ?? '',
      beforeLine: map['beforeLine'] as String?,
      helpedLine: map['helpedLine'] as String?,
      nextLine: map['nextLine'] as String? ?? '',
      checkInCount: map['checkInCount'] is int
          ? map['checkInCount'] as int
          : (map['checkInCount'] as num?)?.toInt() ?? 0,
      shouldShow: map['shouldShow'] == true,
    );
  }
}