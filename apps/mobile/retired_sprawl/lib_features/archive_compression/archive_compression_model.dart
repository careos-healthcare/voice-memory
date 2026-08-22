/// What ArchiveMe suggests the user do with a group of similar moments.
enum ArchiveCompressionSuggestedAction { keepTogether, split, review }

extension ArchiveCompressionSuggestedActionIds
    on ArchiveCompressionSuggestedAction {
  String get id => name;
}

ArchiveCompressionSuggestedAction archiveCompressionSuggestedActionFromId(
  String? id,
) {
  for (final a in ArchiveCompressionSuggestedAction.values) {
    if (a.name == id) return a;
  }
  return ArchiveCompressionSuggestedAction.review;
}

/// A suggested group of similar key moments — never deletes underlying moments.
class ArchiveMomentGroup {
  const ArchiveMomentGroup({
    required this.id,
    required this.title,
    required this.momentIds,
    required this.tags,
    required this.firstDate,
    required this.lastDate,
    required this.count,
    required this.suggestedAction,
    this.patternTitle,
  });

  final String id;
  final String title;
  final List<String> momentIds;
  final String? patternTitle;
  final List<String> tags;
  final DateTime firstDate;
  final DateTime lastDate;
  final int count;
  final ArchiveCompressionSuggestedAction suggestedAction;

  bool get hasPatternTitle =>
      patternTitle != null && patternTitle!.trim().isNotEmpty;

  /// Plain date range for the group card — uses day / week / month language.
  String get dateRangeLabel {
    if (count <= 1 || _sameDay(firstDate, lastDate)) {
      return _dayLabel(firstDate);
    }
    final spanDays = lastDate.difference(firstDate).inDays;
    if (spanDays <= 7) {
      return '${_dayLabel(firstDate)} – ${_dayLabel(lastDate)}';
    }
    if (spanDays <= 14) return '2 weeks';
    if (spanDays <= 31) return '1 month';
    return '${_dayLabel(firstDate)} – ${_dayLabel(lastDate)}';
  }

  ArchiveMomentGroup copyWith({
    String? id,
    String? title,
    List<String>? momentIds,
    String? patternTitle,
    List<String>? tags,
    DateTime? firstDate,
    DateTime? lastDate,
    int? count,
    ArchiveCompressionSuggestedAction? suggestedAction,
  }) {
    return ArchiveMomentGroup(
      id: id ?? this.id,
      title: title ?? this.title,
      momentIds: momentIds ?? this.momentIds,
      patternTitle: patternTitle ?? this.patternTitle,
      tags: tags ?? this.tags,
      firstDate: firstDate ?? this.firstDate,
      lastDate: lastDate ?? this.lastDate,
      count: count ?? this.count,
      suggestedAction: suggestedAction ?? this.suggestedAction,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'momentIds': momentIds,
    if (patternTitle != null) 'patternTitle': patternTitle,
    'tags': tags,
    'firstDate': firstDate.toIso8601String(),
    'lastDate': lastDate.toIso8601String(),
    'count': count,
    'suggestedAction': suggestedAction.id,
  };

  static ArchiveMomentGroup? fromJson(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;
    final id = map['id'] as String?;
    final title = map['title'] as String?;
    final firstRaw = map['firstDate'] as String?;
    final lastRaw = map['lastDate'] as String?;
    if (id == null || title == null || firstRaw == null || lastRaw == null) {
      return null;
    }
    final firstDate = DateTime.tryParse(firstRaw);
    final lastDate = DateTime.tryParse(lastRaw);
    if (firstDate == null || lastDate == null) return null;
    final rawIds = map['momentIds'];
    final momentIds = rawIds is List
        ? rawIds.map((e) => e.toString()).toList()
        : const <String>[];
    final rawTags = map['tags'];
    final tags = rawTags is List
        ? rawTags.map((e) => e.toString()).toList()
        : const <String>[];
    return ArchiveMomentGroup(
      id: id,
      title: title,
      momentIds: momentIds,
      patternTitle: map['patternTitle'] as String?,
      tags: tags,
      firstDate: firstDate,
      lastDate: lastDate,
      count: (map['count'] as num?)?.toInt() ?? momentIds.length,
      suggestedAction: archiveCompressionSuggestedActionFromId(
        map['suggestedAction'] as String?,
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _dayLabel(DateTime date) {
    const months = [
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
    return '${months[date.month - 1]} ${date.day}';
  }
}

/// User decisions about which group suggestions to show again.
class ArchiveCompressionPrefs {
  const ArchiveCompressionPrefs({
    this.keptGroupIds = const {},
    this.splitGroupIds = const {},
    this.hiddenGroupIds = const {},
  });

  final Set<String> keptGroupIds;
  final Set<String> splitGroupIds;
  final Set<String> hiddenGroupIds;

  ArchiveCompressionPrefs copyWith({
    Set<String>? keptGroupIds,
    Set<String>? splitGroupIds,
    Set<String>? hiddenGroupIds,
  }) {
    return ArchiveCompressionPrefs(
      keptGroupIds: keptGroupIds ?? this.keptGroupIds,
      splitGroupIds: splitGroupIds ?? this.splitGroupIds,
      hiddenGroupIds: hiddenGroupIds ?? this.hiddenGroupIds,
    );
  }

  Map<String, dynamic> toJson() => {
    'keptGroupIds': keptGroupIds.toList(),
    'splitGroupIds': splitGroupIds.toList(),
    'hiddenGroupIds': hiddenGroupIds.toList(),
  };

  static ArchiveCompressionPrefs fromJson(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return const ArchiveCompressionPrefs();
    Set<String> readSet(String key) {
      final raw = map[key];
      if (raw is! List) return {};
      return raw.map((e) => e.toString()).toSet();
    }

    return ArchiveCompressionPrefs(
      keptGroupIds: readSet('keptGroupIds'),
      splitGroupIds: readSet('splitGroupIds'),
      hiddenGroupIds: readSet('hiddenGroupIds'),
    );
  }
}