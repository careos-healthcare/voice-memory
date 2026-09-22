import 'package:archiveme_mobile/features/search/vector_search_service.dart';

/// A saved moment cited in a natural-language answer.
class RagCitation {
  const RagCitation({
    required this.entryId,
    required this.excerpt,
    required this.similarity,
    required this.href,
    this.createdAt,
  });

  final String entryId;
  final String excerpt;

  /// Cosine similarity from sqlite-vec, or the local blob fallback. 1 is identical.
  final double similarity;

  /// In-app link to the historical entry.
  final String href;
  final DateTime? createdAt;
}

/// Humanized reply plus the entries it was drawn from.
class RagSearchAnswer {
  const RagSearchAnswer({
    required this.query,
    required this.summary,
    required this.citations,
  });

  final String query;
  final String summary;
  final List<RagCitation> citations;
}

/// Answers a question from the top matching entry chunks.
///
/// The query is embedded on device, then [TranscriptChunkStore.nearestMatches]
/// reads sqlite-vec when that table is present.
class RagSearchService {
  RagSearchService({
    required TranscriptEmbedder embedder,
    required TranscriptChunkStore store,
    this.topK = 5,
    this.createdAtFor,
  }) : _search = VectorSearchService(store: store, embedder: embedder);

  final int topK;
  final DateTime? Function(String entryId)? createdAtFor;
  final VectorSearchService _search;

  Future<RagSearchAnswer> search(String naturalLanguageQuery) async {
    final trimmed = naturalLanguageQuery.trim();
    if (trimmed.isEmpty) {
      return RagSearchAnswer(
        query: naturalLanguageQuery,
        summary: '',
        citations: const [],
      );
    }
    final result = await _search.ask(trimmed, limit: topK);
    final citations = _order(trimmed, [
      for (final hit in result.citations)
        RagCitation(
          entryId: hit.entryId,
          excerpt: hit.text,
          similarity: hit.score.clamp(0, 1).toDouble(),
          href: '/entry/${hit.entryId}',
          createdAt: createdAtFor?.call(hit.entryId),
        ),
    ]);
    return RagSearchAnswer(
      query: trimmed,
      summary: summarizeRagAnswer(trimmed, citations),
      citations: citations,
    );
  }

  List<RagCitation> _order(String query, List<RagCitation> citations) {
    if (citations.length < 2 || !_asksForLatest(query)) return citations;
    final dated = citations.where((item) => item.createdAt != null).toList();
    if (dated.isEmpty) return citations;
    dated.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
    final rest = [
      for (final item in citations)
        if (!dated.contains(item)) item,
    ];
    return [...dated, ...rest];
  }
}

bool _asksForLatest(String query) {
  return RegExp(
    r'\b(when|last time|latest|most recent|recently)\b',
    caseSensitive: false,
  ).hasMatch(query);
}

/// Short answer with a citation link and the similarity score.
String summarizeRagAnswer(String query, List<RagCitation> citations) {
  if (citations.isEmpty) {
    return 'Nothing saved yet matches "$query".';
  }
  final lead = citations.first;
  final when = lead.createdAt;
  final dated = when == null ? '' : ' On ${_formatDay(when)}';
  final score = lead.similarity.toStringAsFixed(2);
  final excerpt = _clip(lead.excerpt);
  final buffer = StringBuffer()
    ..write('The closest saved moment$dated says "$excerpt".')
    ..write(' Similarity $score.')
    ..write(' [Open entry](${lead.href}).');
  if (citations.length > 1) {
    final more = citations.skip(1).take(2);
    buffer.write(' Also ${more.map(_cite).join(' ')}');
  }
  return buffer.toString();
}

String _cite(RagCitation citation) {
  final score = citation.similarity.toStringAsFixed(2);
  return '[${_clip(citation.excerpt)}](${citation.href}) ($score).';
}

String _clip(String text) {
  final trimmed = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (trimmed.length <= 80) return trimmed;
  return '${trimmed.substring(0, 77)}...';
}

String _formatDay(DateTime when) {
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
  final local = when.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}
