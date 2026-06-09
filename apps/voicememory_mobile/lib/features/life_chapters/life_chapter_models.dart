/// Evidence-backed quote tied to a recording in a life chapter.
class LifeChapterQuote {
  const LifeChapterQuote({
    required this.quote,
    required this.entryId,
  });

  final String quote;
  final String entryId;

  Map<String, dynamic> toJson() => {
        'quote': quote,
        'entryId': entryId,
      };

  static LifeChapterQuote? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final quote = json['quote']?.toString().trim() ?? '';
    final id = json['entryId']?.toString() ?? '';
    if (quote.isEmpty || id.isEmpty) return null;
    return LifeChapterQuote(quote: quote, entryId: id);
  }
}

/// A time-bounded period grouped from chronological archive evidence.
class LifeChapter {
  const LifeChapter({
    required this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.dominantThemes,
    required this.keyBeliefs,
    required this.importantQuotes,
    required this.evidenceIds,
  });

  final String id;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> dominantThemes;
  final List<String> keyBeliefs;
  final List<LifeChapterQuote> importantQuotes;
  final List<String> evidenceIds;

  String get dateRangeLabel => _formatRange(startDate, endDate);

  String get themeSummary =>
      dominantThemes.isEmpty ? 'Mixed themes' : dominantThemes.join(' · ');

  String? get primaryBelief =>
      keyBeliefs.isNotEmpty ? keyBeliefs.first : null;

  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'id': id,
        'title': title,
        'startDate': startDate.toUtc().toIso8601String(),
        'endDate': endDate.toUtc().toIso8601String(),
        'dominantThemes': dominantThemes,
        'keyBeliefs': keyBeliefs,
        'importantQuotes': importantQuotes.map((q) => q.toJson()).toList(),
        'evidenceIds': evidenceIds,
      };

  static LifeChapter? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final title = json['title']?.toString().trim() ?? '';
    if (title.isEmpty) return null;
    final start = DateTime.tryParse(json['startDate']?.toString() ?? '');
    final end = DateTime.tryParse(json['endDate']?.toString() ?? '');
    if (start == null || end == null) return null;
    final quotes = <LifeChapterQuote>[];
    for (final item in json['importantQuotes'] as List<dynamic>? ?? []) {
      if (item is Map<String, dynamic>) {
        final q = LifeChapterQuote.fromJson(item);
        if (q != null) quotes.add(q);
      } else if (item is Map) {
        final q = LifeChapterQuote.fromJson(Map<String, dynamic>.from(item));
        if (q != null) quotes.add(q);
      }
    }
    return LifeChapter(
      id: json['id']?.toString() ?? '',
      title: title,
      startDate: start,
      endDate: end,
      dominantThemes: (json['dominantThemes'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      keyBeliefs: (json['keyBeliefs'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      importantQuotes: quotes,
      evidenceIds: (json['evidenceIds'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList(),
    );
  }
}

class LifeChapterResult {
  const LifeChapterResult({
    required this.chapters,
    required this.hasMinimumArchiveEvidence,
    required this.evidenceReflectionCount,
  });

  final List<LifeChapter> chapters;
  final bool hasMinimumArchiveEvidence;
  final int evidenceReflectionCount;

  bool get hasChapters => chapters.isNotEmpty;
}

String _formatRange(DateTime start, DateTime end) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  String label(DateTime d) =>
      '${months[d.toLocal().month - 1]} ${d.toLocal().year}';
  final s = label(start);
  final e = label(end);
  return s == e ? s : '$s – $e';
}
