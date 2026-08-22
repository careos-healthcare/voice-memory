/// What ArchiveMe remembers about one recurring pattern, in plain language.
///
/// This is a faithful, conservative summary built from what is already stored —
/// pattern memory, the pattern map, key moments, progress, and weekly recaps.
/// Lines are omitted when their source is unknown; nothing is invented.
class ArchiveMemorySummary {
  const ArchiveMemorySummary({
    required this.id,
    required this.patternTitle,
    required this.primaryMemoryLine,
    required this.basedOnMomentCount,
    required this.basedOnWeekCount,
    required this.clarityLabel,
    this.startsBeforeLine,
    this.helpedLine,
    this.heavierLine,
    this.changedLine,
    this.firstSeenDate,
    this.lastSeenDate,
    this.nextCheck,
  });

  final String id;
  final String patternTitle;
  final String primaryMemoryLine;
  final String? startsBeforeLine;
  final String? helpedLine;
  final String? heavierLine;
  final String? changedLine;
  final int basedOnMomentCount;
  final int basedOnWeekCount;
  final DateTime? firstSeenDate;
  final DateTime? lastSeenDate;
  final String clarityLabel;
  final String? nextCheck;

  bool get hasNextCheck => (nextCheck ?? '').trim().isNotEmpty;

  /// "Based on X moments across Y weeks." — always safe, plain counts.
  String get basedOnLine {
    final moments = basedOnMomentCount == 1 ? 'moment' : 'moments';
    final weeks = basedOnWeekCount == 1 ? 'week' : 'weeks';
    return 'Based on $basedOnMomentCount $moments across $basedOnWeekCount $weeks.';
  }

  ArchiveMemorySummary copyWith({
    String? id,
    String? patternTitle,
    String? primaryMemoryLine,
    String? startsBeforeLine,
    String? helpedLine,
    String? heavierLine,
    String? changedLine,
    int? basedOnMomentCount,
    int? basedOnWeekCount,
    DateTime? firstSeenDate,
    DateTime? lastSeenDate,
    String? clarityLabel,
    String? nextCheck,
  }) {
    return ArchiveMemorySummary(
      id: id ?? this.id,
      patternTitle: patternTitle ?? this.patternTitle,
      primaryMemoryLine: primaryMemoryLine ?? this.primaryMemoryLine,
      startsBeforeLine: startsBeforeLine ?? this.startsBeforeLine,
      helpedLine: helpedLine ?? this.helpedLine,
      heavierLine: heavierLine ?? this.heavierLine,
      changedLine: changedLine ?? this.changedLine,
      basedOnMomentCount: basedOnMomentCount ?? this.basedOnMomentCount,
      basedOnWeekCount: basedOnWeekCount ?? this.basedOnWeekCount,
      firstSeenDate: firstSeenDate ?? this.firstSeenDate,
      lastSeenDate: lastSeenDate ?? this.lastSeenDate,
      clarityLabel: clarityLabel ?? this.clarityLabel,
      nextCheck: nextCheck ?? this.nextCheck,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'patternTitle': patternTitle,
    'primaryMemoryLine': primaryMemoryLine,
    if (startsBeforeLine != null) 'startsBeforeLine': startsBeforeLine,
    if (helpedLine != null) 'helpedLine': helpedLine,
    if (heavierLine != null) 'heavierLine': heavierLine,
    if (changedLine != null) 'changedLine': changedLine,
    'basedOnMomentCount': basedOnMomentCount,
    'basedOnWeekCount': basedOnWeekCount,
    if (firstSeenDate != null)
      'firstSeenDate': firstSeenDate!.toUtc().toIso8601String(),
    if (lastSeenDate != null)
      'lastSeenDate': lastSeenDate!.toUtc().toIso8601String(),
    'clarityLabel': clarityLabel,
    if (nextCheck != null) 'nextCheck': nextCheck,
  };

  static ArchiveMemorySummary? fromJson(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;
    final id = map['id'] as String?;
    final primary = map['primaryMemoryLine'] as String?;
    if (id == null || primary == null) return null;
    return ArchiveMemorySummary(
      id: id,
      patternTitle: map['patternTitle'] as String? ?? '',
      primaryMemoryLine: primary,
      startsBeforeLine: map['startsBeforeLine'] as String?,
      helpedLine: map['helpedLine'] as String?,
      heavierLine: map['heavierLine'] as String?,
      changedLine: map['changedLine'] as String?,
      basedOnMomentCount: _int(map['basedOnMomentCount']),
      basedOnWeekCount: _int(map['basedOnWeekCount']),
      firstSeenDate: DateTime.tryParse(map['firstSeenDate'] as String? ?? ''),
      lastSeenDate: DateTime.tryParse(map['lastSeenDate'] as String? ?? ''),
      clarityLabel: map['clarityLabel'] as String? ?? 'Getting clearer',
      nextCheck: map['nextCheck'] as String?,
    );
  }

  static int _int(dynamic v) => v is int ? v : (v is num ? v.toInt() : 0);
}