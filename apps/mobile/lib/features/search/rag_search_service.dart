import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archiveme_mobile/core/database/benchmark_seeder_isolate.dart';
import 'package:archiveme_mobile/core/database/database_service.dart';
import 'package:archiveme_mobile/core/execution/isolate_compute_job.dart';
import 'package:archiveme_mobile/features/search/vector_search_service.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

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
    RagIsolatePool? pool,
  }) : _search = VectorSearchService(store: store, embedder: embedder),
       _pool = pool ?? RagIsolatePool();

  final int topK;
  final DateTime? Function(String entryId)? createdAtFor;
  final VectorSearchService _search;
  final RagIsolatePool _pool;

  /// Ranks a journal file on a background worker.
  ///
  /// The worker applies the read pragmas, drops rows outside the date range
  /// or category, then scores the remaining float32 vectors.
  Future<List<RagRankHit>> rankDatabase(RagRankRequest request) {
    return _pool.rank(request);
  }

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

/// One row scored by [rankFilteredVectors].
class RagRankHit {
  const RagRankHit({required this.id, required this.similarity});

  final String id;
  final double similarity;
}

/// File-backed query. Only the 384-d query vector crosses to the worker.
class RagRankRequest {
  const RagRankRequest({
    required this.databasePath,
    required this.query,
    this.limit = 10,
    this.category,
    this.createdFrom,
    this.createdTo,
  });

  final String databasePath;
  final Float32List query;
  final int limit;
  final String? category;
  final String? createdFrom;
  final String? createdTo;
}

/// Background workers for filtered cosine ranking.
class RagIsolatePool {
  RagIsolatePool({IsolateJobThrottle? workers})
    : _workers = workers ?? IsolateJobThrottle();

  final IsolateJobThrottle _workers;

  Future<List<RagRankHit>> rank(RagRankRequest request) {
    return IsolateComputeJob.run<RagRankRequest, List<RagRankHit>>(
      label: 'rag.filtered_rank',
      payload: request,
      computeFn: rankFilteredVectors,
      throttle: _workers,
    );
  }
}

/// Opens [request]'s database on the calling isolate and returns the top hits.
List<RagRankHit> rankFilteredVectors(RagRankRequest request) {
  final db = sql.sqlite3.open(request.databasePath);
  try {
    DatabaseTuning.apply(db);
    db.execute('''
      CREATE INDEX IF NOT EXISTS benchmark_entries_filter
      ON $benchmarkEntriesTable(category, created_at)
    ''');
    final clauses = <String>[];
    final args = <Object?>[];
    final category = request.category?.trim();
    final from = request.createdFrom?.trim();
    final to = request.createdTo?.trim();
    if (category != null && category.isNotEmpty) {
      clauses.add('category = ?');
      args.add(category);
    }
    if (from != null && from.isNotEmpty) {
      clauses.add('created_at >= ?');
      args.add(from);
    }
    if (to != null && to.isNotEmpty) {
      clauses.add('created_at < ?');
      args.add(to);
    }
    final where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';
    final statement = db.prepare(
      'SELECT id, embedding FROM $benchmarkEntriesTable $where',
    );
    final best = <_Scored>[];
    try {
      final cursor = statement.selectCursor(args);
      while (cursor.moveNext()) {
        final row = cursor.current;
        final similarity = _cosine(
          request.query,
          row['embedding'] as Uint8List,
        );
        _consider(
          best,
          request.limit,
          row['id'] as String,
          similarity,
        );
      }
    } finally {
      statement.close();
    }
    best.sort((a, b) => b.similarity.compareTo(a.similarity));
    return [
      for (final item in best)
        RagRankHit(id: item.id, similarity: item.similarity),
    ];
  } finally {
    db.close();
  }
}

class _Scored {
  _Scored(this.id, this.similarity);

  final String id;
  final double similarity;
}

void _consider(List<_Scored> best, int limit, String id, double similarity) {
  if (limit <= 0) return;
  if (best.length < limit) {
    best.add(_Scored(id, similarity));
    return;
  }
  var worst = 0;
  for (var i = 1; i < best.length; i++) {
    if (best[i].similarity < best[worst].similarity) worst = i;
  }
  if (similarity <= best[worst].similarity) return;
  best[worst] = _Scored(id, similarity);
}

double _cosine(Float32List query, Uint8List blob) {
  final values = _vectorView(blob);
  final length = math.min(query.length, values.length);
  if (length == 0) return 0;
  var dot = 0.0;
  var normQuery = 0.0;
  var normRow = 0.0;
  for (var i = 0; i < length; i++) {
    final left = query[i];
    final right = values[i];
    dot += left * right;
    normQuery += left * left;
    normRow += right * right;
  }
  if (normQuery == 0 || normRow == 0) return 0;
  return dot / (math.sqrt(normQuery) * math.sqrt(normRow));
}

Float32List _vectorView(Uint8List blob) {
  final aligned = blob.offsetInBytes % 4 == 0 && blob.lengthInBytes % 4 == 0;
  if (!aligned) {
    return Float32List.sublistView(Uint8List.fromList(blob));
  }
  return Float32List.sublistView(blob);
}
