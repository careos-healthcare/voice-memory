/// How a pattern behaved across a single week of check-ins.
enum WeeklyPatternRecapType {
  repeated,
  lighter,
  heavier,
  changing,
  notEnoughYet,
}

extension WeeklyPatternRecapTypeIds on WeeklyPatternRecapType {
  String get id => name;
}

WeeklyPatternRecapType weeklyPatternRecapTypeFromId(String? raw) {
  for (final t in WeeklyPatternRecapType.values) {
    if (t.id == raw) return t;
  }
  return WeeklyPatternRecapType.notEnoughYet;
}

/// A short weekly payoff: what kept repeating, and what to check next week.
class WeeklyPatternRecap {
  const WeeklyPatternRecap({
    required this.id,
    required this.memoryId,
    required this.createdAt,
    required this.weekStart,
    required this.weekEnd,
    required this.type,
    required this.patternTitle,
    required this.headline,
    required this.body,
    this.usefulLine,
    this.nextQuestion,
    required this.checkInCount,
    required this.shouldShow,
  });

  final String id;
  final String memoryId;
  final DateTime createdAt;
  final DateTime weekStart;
  final DateTime weekEnd;
  final WeeklyPatternRecapType type;
  final String patternTitle;
  final String headline;
  final String body;
  final String? usefulLine;
  final String? nextQuestion;
  final int checkInCount;
  final bool shouldShow;

  Map<String, dynamic> toJson() => {
        'id': id,
        'memoryId': memoryId,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'weekStart': weekStart.toUtc().toIso8601String(),
        'weekEnd': weekEnd.toUtc().toIso8601String(),
        'type': type.id,
        'patternTitle': patternTitle,
        'headline': headline,
        'body': body,
        if (usefulLine != null) 'usefulLine': usefulLine,
        if (nextQuestion != null) 'nextQuestion': nextQuestion,
        'checkInCount': checkInCount,
        'shouldShow': shouldShow,
      };

  static WeeklyPatternRecap? fromJson(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;
    final id = map['id'] as String?;
    if (id == null || id.isEmpty) return null;
    final createdAt = DateTime.tryParse(map['createdAt'] as String? ?? '');
    final weekStart = DateTime.tryParse(map['weekStart'] as String? ?? '');
    final weekEnd = DateTime.tryParse(map['weekEnd'] as String? ?? '');
    if (createdAt == null || weekStart == null || weekEnd == null) return null;
    return WeeklyPatternRecap(
      id: id,
      memoryId: map['memoryId'] as String? ?? '',
      createdAt: createdAt,
      weekStart: weekStart,
      weekEnd: weekEnd,
      type: weeklyPatternRecapTypeFromId(map['type'] as String?),
      patternTitle: map['patternTitle'] as String? ?? '',
      headline: map['headline'] as String? ?? '',
      body: map['body'] as String? ?? '',
      usefulLine: map['usefulLine'] as String?,
      nextQuestion: map['nextQuestion'] as String?,
      checkInCount: map['checkInCount'] is int
          ? map['checkInCount'] as int
          : (map['checkInCount'] as num?)?.toInt() ?? 0,
      shouldShow: map['shouldShow'] == true,
    );
  }
}
