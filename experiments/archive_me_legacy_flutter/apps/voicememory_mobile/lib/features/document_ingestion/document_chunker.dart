import 'document_models.dart';

/// Deterministic whitespace-token chunking with paragraph/block preference.
///
/// Chunk text is always an exact substring of [ParsedDocument.text]. Tokens
/// are maximal non-whitespace spans, making boundaries stable across devices.
final class DocumentChunker {
  const DocumentChunker({this.maxTokens = 500, this.overlapTokens = 50})
    : assert(maxTokens > 0),
      assert(overlapTokens >= 0),
      assert(overlapTokens < maxTokens);

  final int maxTokens;
  final int overlapTokens;

  List<DocumentChunk> chunk(ParsedDocument document) {
    final tokens = RegExp(r'\S+')
        .allMatches(document.text)
        .map((match) => (start: match.start, end: match.end))
        .toList();
    if (tokens.isEmpty) return const [];

    final result = <DocumentChunk>[];
    var firstToken = 0;
    while (firstToken < tokens.length) {
      final hardLastExclusive = (firstToken + maxTokens).clamp(
        0,
        tokens.length,
      );
      var endChar = tokens[hardLastExclusive - 1].end;

      if (hardLastExclusive < tokens.length) {
        final preferredEnds = document.blocks
            .where(
              (block) =>
                  block.endChar > tokens[firstToken].start &&
                  block.endChar <= endChar,
            )
            .map((block) => block.endChar);
        if (preferredEnds.isNotEmpty) {
          endChar = preferredEnds.reduce(
            (left, right) => left > right ? left : right,
          );
        }
      }

      var lastExclusive = firstToken;
      while (lastExclusive < tokens.length &&
          tokens[lastExclusive].end <= endChar) {
        lastExclusive++;
      }
      if (lastExclusive == firstToken) {
        lastExclusive = hardLastExclusive;
        endChar = tokens[lastExclusive - 1].end;
      }

      final startChar = tokens[firstToken].start;
      final intersecting = document.blocks.where(
        (block) => block.startChar < endChar && block.endChar > startChar,
      );
      result.add(
        DocumentChunk(
          index: result.length,
          text: document.text.substring(startChar, endChar),
          startChar: startChar,
          endChar: endChar,
          tokenCount: lastExclusive - firstToken,
          pageNumbers: intersecting
              .map((block) => block.pageNumber)
              .whereType<int>(),
          chapterIndexes: intersecting
              .map((block) => block.chapterIndex)
              .whereType<int>(),
        ),
      );
      if (lastExclusive == tokens.length) break;
      firstToken = lastExclusive - overlapTokens;
    }
    return List.unmodifiable(result);
  }
}
