import '../document_ingestion/document_models.dart';

final class DocumentConcept {
  const DocumentConcept({
    required this.index,
    required this.text,
    required this.startChar,
    required this.endChar,
    required this.occurrences,
  });

  final int index;
  final String text;
  final int startChar;
  final int endChar;
  final int occurrences;
}

/// Small deterministic local extractor used when no richer concept list exists.
final class LocalDocumentConceptExtractor {
  const LocalDocumentConceptExtractor({
    this.minimumOccurrences = 2,
    this.maximumConcepts = 24,
  });

  final int minimumOccurrences;
  final int maximumConcepts;

  static final RegExp _word = RegExp(r"[A-Za-z][A-Za-z0-9'-]{2,}");
  static const Set<String> _stopWords = {
    'and',
    'are',
    'but',
    'for',
    'from',
    'has',
    'have',
    'into',
    'its',
    'not',
    'that',
    'the',
    'their',
    'there',
    'these',
    'they',
    'this',
    'was',
    'were',
    'which',
    'with',
    'you',
    'your',
  };

  List<DocumentConcept> extract(Iterable<DocumentChunk> chunks) {
    final occurrences = <String, List<({int start, int end})>>{};
    for (final chunk in chunks) {
      final matches = _word.allMatches(chunk.text).toList();
      for (var index = 0; index < matches.length; index++) {
        final match = matches[index];
        final word = match.group(0)!.toLowerCase();
        if (_stopWords.contains(word)) continue;
        occurrences.putIfAbsent(word, () => []).add((
          start: chunk.startChar + match.start,
          end: chunk.startChar + match.end,
        ));
        if (index + 1 < matches.length) {
          final next = matches[index + 1];
          final nextWord = next.group(0)!.toLowerCase();
          if (!_stopWords.contains(nextWord)) {
            occurrences.putIfAbsent('$word $nextWord', () => []).add((
              start: chunk.startChar + match.start,
              end: chunk.startChar + next.end,
            ));
          }
        }
      }
    }
    final ranked =
        occurrences.entries
            .where((entry) => entry.value.length >= minimumOccurrences)
            .toList()
          ..sort((left, right) {
            final byCount = right.value.length.compareTo(left.value.length);
            return byCount != 0 ? byCount : left.key.compareTo(right.key);
          });
    return List.unmodifiable([
      for (var index = 0; index < ranked.take(maximumConcepts).length; index++)
        DocumentConcept(
          index: index,
          text: ranked[index].key,
          startChar: ranked[index].value.first.start,
          endChar: ranked[index].value.first.end,
          occurrences: ranked[index].value.length,
        ),
    ]);
  }
}
