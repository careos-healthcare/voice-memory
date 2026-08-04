/// Preset date ranges for archive period review.
enum ArchiveReviewRangePreset {
  thisWeek,
  lastWeek,
  thisMonth,
  last30Days,
  custom,
}

extension ArchiveReviewRangePresetIds on ArchiveReviewRangePreset {
  String get id => name;
}

ArchiveReviewRangePreset archiveReviewRangePresetFromId(String? id) {
  for (final p in ArchiveReviewRangePreset.values) {
    if (p.name == id) return p;
  }
  return ArchiveReviewRangePreset.thisWeek;
}

/// What stood out most in a date-range review.
enum ArchiveRangeReviewType {
  repeated,
  lighter,
  heavier,
  changed,
  notEnoughYet,
}

extension ArchiveRangeReviewTypeIds on ArchiveRangeReviewType {
  String get id => name;
}

ArchiveRangeReviewType archiveRangeReviewTypeFromId(String? id) {
  for (final t in ArchiveRangeReviewType.values) {
    if (t.name == id) return t;
  }
  return ArchiveRangeReviewType.notEnoughYet;
}

/// A period review of what repeated, changed, or helped in the archive.
class ArchiveRangeReview {
  const ArchiveRangeReview({
    required this.id,
    required this.preset,
    required this.startDate,
    required this.endDate,
    required this.title,
    required this.type,
    required this.momentCount,
    required this.patternCount,
    this.repeatedLine,
    this.lighterLine,
    this.heavierLine,
    this.changedLine,
    this.helpedLine,
    this.nextCheck,
    this.keyMomentIds = const [],
  });

  final String id;
  final ArchiveReviewRangePreset preset;
  final DateTime startDate;
  final DateTime endDate;
  final String title;
  final ArchiveRangeReviewType type;
  final int momentCount;
  final int patternCount;
  final String? repeatedLine;
  final String? lighterLine;
  final String? heavierLine;
  final String? changedLine;
  final String? helpedLine;
  final String? nextCheck;
  final List<String> keyMomentIds;

  static const int minMomentsForReview = 3;

  bool get hasEnoughData => momentCount >= minMomentsForReview;

  bool get hasNextCheck => (nextCheck ?? '').trim().isNotEmpty;

  String get dateRangeLabel => _formatDateRange(startDate, endDate);

  String get mainLine =>
      switch (type) {
        ArchiveRangeReviewType.repeated => repeatedLine,
        ArchiveRangeReviewType.lighter => lighterLine,
        ArchiveRangeReviewType.heavier => heavierLine,
        ArchiveRangeReviewType.changed => changedLine,
        ArchiveRangeReviewType.notEnoughYet => null,
      } ??
      '';

  ArchiveRangeReview copyWith({
    String? id,
    ArchiveReviewRangePreset? preset,
    DateTime? startDate,
    DateTime? endDate,
    String? title,
    ArchiveRangeReviewType? type,
    int? momentCount,
    int? patternCount,
    String? repeatedLine,
    String? lighterLine,
    String? heavierLine,
    String? changedLine,
    String? helpedLine,
    String? nextCheck,
    List<String>? keyMomentIds,
  }) {
    return ArchiveRangeReview(
      id: id ?? this.id,
      preset: preset ?? this.preset,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      title: title ?? this.title,
      type: type ?? this.type,
      momentCount: momentCount ?? this.momentCount,
      patternCount: patternCount ?? this.patternCount,
      repeatedLine: repeatedLine ?? this.repeatedLine,
      lighterLine: lighterLine ?? this.lighterLine,
      heavierLine: heavierLine ?? this.heavierLine,
      changedLine: changedLine ?? this.changedLine,
      helpedLine: helpedLine ?? this.helpedLine,
      nextCheck: nextCheck ?? this.nextCheck,
      keyMomentIds: keyMomentIds ?? this.keyMomentIds,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'preset': preset.id,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'title': title,
    'type': type.id,
    'momentCount': momentCount,
    'patternCount': patternCount,
    if (repeatedLine != null) 'repeatedLine': repeatedLine,
    if (lighterLine != null) 'lighterLine': lighterLine,
    if (heavierLine != null) 'heavierLine': heavierLine,
    if (changedLine != null) 'changedLine': changedLine,
    if (helpedLine != null) 'helpedLine': helpedLine,
    if (nextCheck != null) 'nextCheck': nextCheck,
    'keyMomentIds': keyMomentIds,
  };

  static ArchiveRangeReview? fromJson(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;
    final id = map['id'] as String?;
    final startRaw = map['startDate'] as String?;
    final endRaw = map['endDate'] as String?;
    if (id == null || startRaw == null || endRaw == null) return null;
    final start = DateTime.tryParse(startRaw);
    final end = DateTime.tryParse(endRaw);
    if (start == null || end == null) return null;
    final rawIds = map['keyMomentIds'];
    final keyMomentIds = rawIds is List
        ? rawIds.map((e) => e.toString()).toList()
        : const <String>[];
    return ArchiveRangeReview(
      id: id,
      preset: archiveReviewRangePresetFromId(map['preset'] as String?),
      startDate: start,
      endDate: end,
      title: (map['title'] as String?) ?? '',
      type: archiveRangeReviewTypeFromId(map['type'] as String?),
      momentCount: _int(map['momentCount']),
      patternCount: _int(map['patternCount']),
      repeatedLine: map['repeatedLine'] as String?,
      lighterLine: map['lighterLine'] as String?,
      heavierLine: map['heavierLine'] as String?,
      changedLine: map['changedLine'] as String?,
      helpedLine: map['helpedLine'] as String?,
      nextCheck: map['nextCheck'] as String?,
      keyMomentIds: keyMomentIds,
    );
  }

  static int _int(dynamic v) => v is int ? v : (v is num ? v.toInt() : 0);
}

String _formatDateRange(DateTime start, DateTime end) {
  final sameMonth = start.year == end.year && start.month == end.month;
  if (sameMonth && start.day == end.day) {
    return _shortDate(start);
  }
  if (sameMonth) {
    return '${_monthName(start.month)} ${start.day}\u2013${end.day}';
  }
  if (start.year == end.year) {
    return '${_monthName(start.month)} ${start.day} \u2013 '
        '${_monthName(end.month)} ${end.day}';
  }
  return '${_shortDate(start)} \u2013 ${_shortDate(end)}';
}

String _shortDate(DateTime d) => '${_monthName(d.month)} ${d.day}, ${d.year}';

String _monthName(int month) {
  const names = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  if (month < 1 || month > 12) return '';
  return names[month - 1];
}
