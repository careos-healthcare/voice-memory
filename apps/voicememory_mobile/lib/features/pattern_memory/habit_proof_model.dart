/// Why continuing to check a pattern is paying off.
enum HabitProofType {
  firstLoopClosed,
  memoryBuilding,
  progressFound,
  nextCheckReady,
  notEnoughYet,
}

extension HabitProofTypeIds on HabitProofType {
  String get id => name;
}

HabitProofType habitProofTypeFromId(String? raw) {
  for (final t in HabitProofType.values) {
    if (t.id == raw) return t;
  }
  return HabitProofType.notEnoughYet;
}

/// A short payoff shown after enough usage: "your checks are turning useful".
class HabitProofMoment {
  const HabitProofMoment({
    required this.id,
    required this.memoryId,
    required this.createdAt,
    required this.type,
    required this.headline,
    required this.body,
    required this.proofLine,
    this.nextLine,
    required this.checkInCount,
    required this.shouldShow,
  });

  final String id;
  final String memoryId;
  final DateTime createdAt;
  final HabitProofType type;
  final String headline;
  final String body;
  final String proofLine;
  final String? nextLine;
  final int checkInCount;
  final bool shouldShow;

  Map<String, dynamic> toJson() => {
        'id': id,
        'memoryId': memoryId,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'type': type.id,
        'headline': headline,
        'body': body,
        'proofLine': proofLine,
        if (nextLine != null) 'nextLine': nextLine,
        'checkInCount': checkInCount,
        'shouldShow': shouldShow,
      };

  static HabitProofMoment? fromJson(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;
    final id = map['id'] as String?;
    if (id == null || id.isEmpty) return null;
    final createdAt = DateTime.tryParse(map['createdAt'] as String? ?? '');
    if (createdAt == null) return null;
    return HabitProofMoment(
      id: id,
      memoryId: map['memoryId'] as String? ?? '',
      createdAt: createdAt,
      type: habitProofTypeFromId(map['type'] as String?),
      headline: map['headline'] as String? ?? '',
      body: map['body'] as String? ?? '',
      proofLine: map['proofLine'] as String? ?? '',
      nextLine: map['nextLine'] as String?,
      checkInCount: map['checkInCount'] is int
          ? map['checkInCount'] as int
          : (map['checkInCount'] as num?)?.toInt() ?? 0,
      shouldShow: map['shouldShow'] == true,
    );
  }
}
