import 'moment_tag_model.dart';

/// Where a saved key moment came from.
enum KeyMomentSource {
  reflection,
  checkIn,
  patternMemory,
  weeklyRecap,
}

extension KeyMomentSourceIds on KeyMomentSource {
  String get id => name;
}

KeyMomentSource keyMomentSourceFromId(String? id) {
  for (final s in KeyMomentSource.values) {
    if (s.name == id) return s;
  }
  return KeyMomentSource.reflection;
}

/// Plain, consumer-facing label for a result hint, or null when there is none.
String? keyMomentResultLabel(String? resultHint) {
  switch (resultHint) {
    case 'same':
    case 'showed_up_again':
      return 'showed up again';
    case 'lighter':
      return 'felt lighter';
    case 'heavier':
      return 'felt heavier';
    case 'changed':
    case 'not_today':
    case 'none_fit':
      return 'changed';
    default:
      return null;
  }
}

/// One saved moment in the long-term Key Moments timeline.
///
/// [originalText] is always preserved verbatim — the timeline is a faithful
/// record, never a rewrite. Everything else is a light, conservative summary so
/// the moment is easy to find again by day.
class KeyMoment {
  const KeyMoment({
    required this.id,
    required this.date,
    required this.title,
    required this.originalText,
    required this.shortSummary,
    this.patternTitle,
    this.resultHint,
    this.nextCheck,
    this.tags = const [],
    this.languageCode,
    this.source = KeyMomentSource.reflection,
  });

  final String id;
  final DateTime date;
  final String title;
  final String originalText;
  final String shortSummary;
  final String? patternTitle;
  final String? resultHint;
  final String? nextCheck;
  final List<String> tags;
  final String? languageCode;
  final KeyMomentSource source;

  /// The recognised [MomentTag]s for this moment (unknown ids are dropped).
  List<MomentTag> get momentTags =>
      tags.map(momentTagFromId).whereType<MomentTag>().toList();

  bool hasTag(MomentTag tag) => tags.contains(tag.id);

  /// `yyyy-mm-dd` key used for grouping and same-day lookups.
  String get dayKey =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  KeyMoment copyWith({
    String? id,
    DateTime? date,
    String? title,
    String? originalText,
    String? shortSummary,
    String? patternTitle,
    String? resultHint,
    String? nextCheck,
    List<String>? tags,
    String? languageCode,
    KeyMomentSource? source,
  }) {
    return KeyMoment(
      id: id ?? this.id,
      date: date ?? this.date,
      title: title ?? this.title,
      originalText: originalText ?? this.originalText,
      shortSummary: shortSummary ?? this.shortSummary,
      patternTitle: patternTitle ?? this.patternTitle,
      resultHint: resultHint ?? this.resultHint,
      nextCheck: nextCheck ?? this.nextCheck,
      tags: tags ?? this.tags,
      languageCode: languageCode ?? this.languageCode,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'title': title,
        'originalText': originalText,
        'shortSummary': shortSummary,
        if (patternTitle != null) 'patternTitle': patternTitle,
        if (resultHint != null) 'resultHint': resultHint,
        if (nextCheck != null) 'nextCheck': nextCheck,
        'tags': tags,
        if (languageCode != null) 'languageCode': languageCode,
        'source': source.id,
      };

  static KeyMoment? fromJson(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;
    final id = map['id'] as String?;
    final dateRaw = map['date'] as String?;
    if (id == null || dateRaw == null) return null;
    final date = DateTime.tryParse(dateRaw);
    if (date == null) return null;
    final rawTags = map['tags'];
    final tags = rawTags is List
        ? rawTags.map((e) => e.toString()).toList()
        : const <String>[];
    return KeyMoment(
      id: id,
      date: date,
      title: (map['title'] as String?) ?? 'Moment from today',
      originalText: (map['originalText'] as String?) ?? '',
      shortSummary: (map['shortSummary'] as String?) ?? '',
      patternTitle: map['patternTitle'] as String?,
      resultHint: map['resultHint'] as String?,
      nextCheck: map['nextCheck'] as String?,
      tags: tags,
      languageCode: map['languageCode'] as String?,
      source: keyMomentSourceFromId(map['source'] as String?),
    );
  }
}
