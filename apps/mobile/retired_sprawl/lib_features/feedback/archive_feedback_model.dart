/// What the user said about one piece of ArchiveMe output.
enum ArchiveFeedbackType {
  useful,
  tooGeneric,
  notMe,
  alreadyKnew,
  moreSpecific,
}

extension ArchiveFeedbackTypeIds on ArchiveFeedbackType {
  String get id => name;

  /// Everything except [useful] is a correction we can gently learn from.
  bool get isNegative => this != ArchiveFeedbackType.useful;
}

ArchiveFeedbackType? archiveFeedbackTypeFromId(String? id) {
  for (final t in ArchiveFeedbackType.values) {
    if (t.name == id) return t;
  }
  return null;
}

/// Which piece of output the feedback is about.
enum ArchiveFeedbackTargetType {
  firstPattern,
  checkInResult,
  nextCheck,
  archiveMemory,
  patternMap,
  patternProfile,
}

extension ArchiveFeedbackTargetTypeIds on ArchiveFeedbackTargetType {
  String get id => name;
}

ArchiveFeedbackTargetType archiveFeedbackTargetTypeFromId(String? id) {
  if (id == null || id.isEmpty) {
    return ArchiveFeedbackTargetType.checkInResult;
  }
  // Legacy target ids from earlier builds — map to the closest surface.
  switch (id) {
    case 'perspective':
    case 'kinderAngle':
      return ArchiveFeedbackTargetType.checkInResult;
    default:
      for (final t in ArchiveFeedbackTargetType.values) {
        if (t.name == id) return t;
      }
      return ArchiveFeedbackTargetType.checkInResult;
  }
}

/// One quick correction the user gave about a pattern, result, or next check.
///
/// This is never shown back to the user as a list — it only feeds gentle
/// adjustments to future questions and patterns.
class ArchiveFeedback {
  const ArchiveFeedback({
    required this.id,
    required this.type,
    required this.targetType,
    required this.createdAt,
    this.targetId,
    this.patternTitle,
    this.resultHint,
    this.languageCode,
  });

  final String id;
  final ArchiveFeedbackType type;
  final ArchiveFeedbackTargetType targetType;
  final DateTime createdAt;
  final String? targetId;
  final String? patternTitle;
  final String? resultHint;
  final String? languageCode;

  ArchiveFeedback copyWith({
    String? id,
    ArchiveFeedbackType? type,
    ArchiveFeedbackTargetType? targetType,
    DateTime? createdAt,
    String? targetId,
    String? patternTitle,
    String? resultHint,
    String? languageCode,
  }) {
    return ArchiveFeedback(
      id: id ?? this.id,
      type: type ?? this.type,
      targetType: targetType ?? this.targetType,
      createdAt: createdAt ?? this.createdAt,
      targetId: targetId ?? this.targetId,
      patternTitle: patternTitle ?? this.patternTitle,
      resultHint: resultHint ?? this.resultHint,
      languageCode: languageCode ?? this.languageCode,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.id,
    'targetType': targetType.id,
    'createdAt': createdAt.toIso8601String(),
    if (targetId != null) 'targetId': targetId,
    if (patternTitle != null) 'patternTitle': patternTitle,
    if (resultHint != null) 'resultHint': resultHint,
    if (languageCode != null) 'languageCode': languageCode,
  };

  static ArchiveFeedback? fromJson(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;
    final id = map['id'] as String?;
    final type = archiveFeedbackTypeFromId(map['type'] as String?);
    final createdRaw = map['createdAt'] as String?;
    if (id == null || type == null || createdRaw == null) return null;
    final createdAt = DateTime.tryParse(createdRaw);
    if (createdAt == null) return null;
    return ArchiveFeedback(
      id: id,
      type: type,
      targetType: archiveFeedbackTargetTypeFromId(map['targetType'] as String?),
      createdAt: createdAt,
      targetId: map['targetId'] as String?,
      patternTitle: map['patternTitle'] as String?,
      resultHint: map['resultHint'] as String?,
      languageCode: map['languageCode'] as String?,
    );
  }
}