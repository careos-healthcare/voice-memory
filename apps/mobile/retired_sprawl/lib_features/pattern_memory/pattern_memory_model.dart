/// How a single active pattern is trending across several check-ins.
enum PatternMemoryStatus { forming, active, easing, needsAttention, changing }

extension PatternMemoryStatusIds on PatternMemoryStatus {
  String get id => name;
}

PatternMemoryStatus patternMemoryStatusFromId(String? raw) {
  for (final s in PatternMemoryStatus.values) {
    if (s.id == raw) return s;
  }
  return PatternMemoryStatus.forming;
}

/// Allowed result hints for a single check-in answer.
abstract class PatternMemoryResultHint {
  PatternMemoryResultHint._();

  static const same = 'same';
  static const lighter = 'lighter';
  static const heavier = 'heavier';
  static const changed = 'changed';

  static const List<String> all = [same, lighter, heavier, changed];

  static String normalize(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    return all.contains(v) ? v : same;
  }
}

/// What ArchiveMe remembers about how one pattern changes over time.
class PatternMemory {
  const PatternMemory({
    required this.id,
    required this.patternTitle,
    required this.createdAt,
    required this.updatedAt,
    this.checkInCount = 0,
    this.showedAgainCount = 0,
    this.lighterCount = 0,
    this.heavierCount = 0,
    this.changedCount = 0,
    this.lastResult,
    this.commonBeforeMoments = const [],
    this.helpedMoments = const [],
    this.harderMoments = const [],
    this.nextBestQuestion,
    this.status = PatternMemoryStatus.forming,
  });

  final String id;
  final String patternTitle;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int checkInCount;
  final int showedAgainCount;
  final int lighterCount;
  final int heavierCount;
  final int changedCount;
  final String? lastResult;
  final List<String> commonBeforeMoments;
  final List<String> helpedMoments;
  final List<String> harderMoments;
  final String? nextBestQuestion;
  final PatternMemoryStatus status;

  PatternMemory copyWith({
    String? patternTitle,
    DateTime? updatedAt,
    int? checkInCount,
    int? showedAgainCount,
    int? lighterCount,
    int? heavierCount,
    int? changedCount,
    String? lastResult,
    List<String>? commonBeforeMoments,
    List<String>? helpedMoments,
    List<String>? harderMoments,
    String? nextBestQuestion,
    PatternMemoryStatus? status,
  }) {
    return PatternMemory(
      id: id,
      patternTitle: patternTitle ?? this.patternTitle,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      checkInCount: checkInCount ?? this.checkInCount,
      showedAgainCount: showedAgainCount ?? this.showedAgainCount,
      lighterCount: lighterCount ?? this.lighterCount,
      heavierCount: heavierCount ?? this.heavierCount,
      changedCount: changedCount ?? this.changedCount,
      lastResult: lastResult ?? this.lastResult,
      commonBeforeMoments: commonBeforeMoments ?? this.commonBeforeMoments,
      helpedMoments: helpedMoments ?? this.helpedMoments,
      harderMoments: harderMoments ?? this.harderMoments,
      nextBestQuestion: nextBestQuestion ?? this.nextBestQuestion,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'patternTitle': patternTitle,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'checkInCount': checkInCount,
    'showedAgainCount': showedAgainCount,
    'lighterCount': lighterCount,
    'heavierCount': heavierCount,
    'changedCount': changedCount,
    if (lastResult != null) 'lastResult': lastResult,
    'commonBeforeMoments': commonBeforeMoments,
    'helpedMoments': helpedMoments,
    'harderMoments': harderMoments,
    if (nextBestQuestion != null) 'nextBestQuestion': nextBestQuestion,
    'status': status.id,
  };

  static PatternMemory? fromJson(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;
    final id = map['id'] as String?;
    if (id == null || id.isEmpty) return null;
    final createdAt = DateTime.tryParse(map['createdAt'] as String? ?? '');
    final updatedAt = DateTime.tryParse(map['updatedAt'] as String? ?? '');
    if (createdAt == null || updatedAt == null) return null;
    return PatternMemory(
      id: id,
      patternTitle: map['patternTitle'] as String? ?? '',
      createdAt: createdAt,
      updatedAt: updatedAt,
      checkInCount: _int(map['checkInCount']),
      showedAgainCount: _int(map['showedAgainCount']),
      lighterCount: _int(map['lighterCount']),
      heavierCount: _int(map['heavierCount']),
      changedCount: _int(map['changedCount']),
      lastResult: map['lastResult'] as String?,
      commonBeforeMoments: _stringList(map['commonBeforeMoments']),
      helpedMoments: _stringList(map['helpedMoments']),
      harderMoments: _stringList(map['harderMoments']),
      nextBestQuestion: map['nextBestQuestion'] as String?,
      status: patternMemoryStatusFromId(map['status'] as String?),
    );
  }

  static int _int(dynamic v) => v is int ? v : (v is num ? v.toInt() : 0);

  static List<String> _stringList(dynamic v) {
    if (v is! List) return const [];
    return v.map((e) => '$e').where((e) => e.isNotEmpty).toList();
  }
}

/// One check-in answer applied to a pattern memory.
class PatternMemoryUpdate {
  const PatternMemoryUpdate({
    required this.checkInId,
    required this.resultHint,
    required this.reflectionText,
    required this.createdAt,
  });

  /// One of [PatternMemoryResultHint].
  final String checkInId;
  final String resultHint;
  final String reflectionText;
  final DateTime createdAt;
}