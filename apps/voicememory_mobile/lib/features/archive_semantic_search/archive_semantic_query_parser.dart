import 'archive_semantic_search_models.dart';

final class ArchiveSemanticQueryParser {
  // Public parameter name intentionally differs from the private field.
  // ignore: prefer_initializing_formals
  const ArchiveSemanticQueryParser({DateTime Function()? now}) : _now = now;

  final DateTime Function()? _now;

  ArchiveSemanticSearchQuery parse(String input) {
    final raw = input.trim();
    final lower = raw.toLowerCase();
    final now = (_now?.call() ?? DateTime.now()).toLocal();
    var intent = ArchiveSemanticSearchIntent.general;
    if (RegExp(r'\b(happiest|most happy|most joyful)\b').hasMatch(lower)) {
      intent = ArchiveSemanticSearchIntent.happiest;
    } else if (RegExp(r'\b(saddest|most sad)\b').hasMatch(lower)) {
      intent = ArchiveSemanticSearchIntent.saddest;
    } else if (RegExp(r'\b(most anxious|most worried)\b').hasMatch(lower)) {
      intent = ArchiveSemanticSearchIntent.mostAnxious;
    } else if (RegExp(r'\b(calmest|most calm)\b').hasMatch(lower)) {
      intent = ArchiveSemanticSearchIntent.calmest;
    } else if (RegExp(
      r'\b(show|find|list)\b.*\b(every|all|times?|entries|mentions?)\b',
    ).hasMatch(lower)) {
      intent = ArchiveSemanticSearchIntent.topicEnumeration;
    } else if (lower.startsWith('entries about ') ||
        lower.startsWith('entries mentioning ')) {
      intent = ArchiveSemanticSearchIntent.topicEnumeration;
    }

    DateTime? after;
    DateTime? before;
    if (lower.contains('last week')) {
      after = now.subtract(const Duration(days: 7));
    } else if (lower.contains('last month')) {
      after = DateTime(now.year, now.month - 1, now.day);
    } else if (lower.contains('last year')) {
      after = DateTime(now.year - 1, now.month, now.day);
    }
    final afterMatch = RegExp(
      r'\bafter\s+(\d{4}-\d{2}-\d{2})\b',
    ).firstMatch(lower);
    final beforeMatch = RegExp(
      r'\bbefore\s+(\d{4}-\d{2}-\d{2})\b',
    ).firstMatch(lower);
    after = DateTime.tryParse(afterMatch?.group(1) ?? '') ?? after;
    before = DateTime.tryParse(
      beforeMatch?.group(1) ?? '',
    )?.add(const Duration(days: 1));

    var searchable = raw
        .replaceAll(
          RegExp(
            r'\b(show|find|list)\s+(me\s+)?(every|all)\s+(time(s)?\s+)?(i\s+)?(mentioned|talked about|wrote about)\b',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(r'^\s*entries\s+(about|mentioning)\s+', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(r'\b(last week|last month|last year)\b', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(
            r'\b(before|after)\s+\d{4}-\d{2}-\d{2}\b',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    if (intent != ArchiveSemanticSearchIntent.general &&
        intent != ArchiveSemanticSearchIntent.topicEnumeration) {
      searchable = switch (intent) {
        ArchiveSemanticSearchIntent.happiest => 'happy joy joyful',
        ArchiveSemanticSearchIntent.saddest => 'sad grief unhappy',
        ArchiveSemanticSearchIntent.mostAnxious => 'anxious worried fear',
        ArchiveSemanticSearchIntent.calmest => 'calm peaceful relaxed',
        _ => searchable,
      };
    }
    searchable = searchable
        .replaceAll(RegExp(r'^[\s:,\-]+|[\s:,\-]+$'), '')
        .replaceAll(RegExp(r'\s+'), ' ');

    return ArchiveSemanticSearchQuery(
      raw: raw,
      searchText: searchable,
      intent: intent,
      after: after?.toUtc(),
      before: before?.toUtc(),
      concepts: _concepts(searchable),
    );
  }

  static List<String> _concepts(String text) {
    final tokens = RegExp(
      r"[a-z0-9]+(?:'[a-z0-9]+)?",
    ).allMatches(text.toLowerCase()).map((match) => match.group(0)!).toList();
    const ignored = {
      'a',
      'an',
      'the',
      'i',
      'me',
      'my',
      'about',
      'and',
      'or',
      'when',
      'was',
      'were',
      'entry',
      'entries',
    };
    return tokens.where((token) => !ignored.contains(token)).toSet().toList();
  }
}
