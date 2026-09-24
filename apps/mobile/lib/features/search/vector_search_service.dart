import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archiveme_mobile/storage/sqlite/embedding_blob_ranker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

/// One transcript paragraph and the moment it starts in the recording.
class TranscriptChunk {
  const TranscriptChunk({
    required this.entryId,
    required this.chunkIndex,
    required this.text,
    required this.startSeconds,
    required this.embedding,
  });

  final String entryId;
  final int chunkIndex;
  final String text;
  final double startSeconds;
  final List<double> embedding;
}

class SemanticSearchHit {
  const SemanticSearchHit({
    required this.entryId,
    required this.chunkIndex,
    required this.text,
    required this.startSeconds,
    required this.score,
  });

  final String entryId;
  final int chunkIndex;
  final String text;
  final double startSeconds;
  final double score;

  String get timestampLabel {
    final total = startSeconds.floor();
    final minutes = total ~/ 60;
    final seconds = total % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}

/// A sqlite-vec neighbor, or a cosine score from the local blob fallback.
class VecMatch {
  const VecMatch({required this.key, required this.cosine});

  final String key;

  /// Higher is closer. sqlite-vec cosine distance is converted with `1 - distance`.
  final double cosine;
}

/// Natural-language answer built only from local matches.
class ConversationalSearchResult {
  const ConversationalSearchResult({
    required this.query,
    required this.reply,
    required this.citations,
    required this.lookupLatency,
  });

  final String query;
  final String reply;
  final List<SemanticSearchHit> citations;

  /// Time spent in the sqlite-vec or local cosine lookup, after embedding.
  final Duration lookupLatency;
}

/// Turns saved matches into a short reply. No network model is involved.
String composeConversationalReply(
  String query,
  List<SemanticSearchHit> hits,
) {
  if (hits.isEmpty) {
    return 'I could not find a saved moment that matches "$query".';
  }
  final lead = hits.first;
  final related = hits.skip(1).take(2).toList();
  final buffer = StringBuffer()
    ..write('The closest moment says "${_clip(lead.text)}"')
    ..write(' at ${lead.timestampLabel}.');
  if (related.isNotEmpty) {
    buffer
      ..write(' Also nearby: ')
      ..write(related.map((hit) => '"${_clip(hit.text)}"').join(' '))
      ..write('.');
  }
  return buffer.toString();
}

String _clip(String text) {
  final trimmed = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (trimmed.length <= 80) return trimmed;
  return '${trimmed.substring(0, 77)}...';
}

/// Yields the reply word by word so the chat surface can stream it locally.
Stream<String> streamConversationalReply(String reply) async* {
  final words = reply.split(RegExp(' +')).where((word) => word.isNotEmpty);
  final buffer = StringBuffer();
  for (final word in words) {
    if (buffer.isNotEmpty) buffer.write(' ');
    buffer.write(word);
    yield buffer.toString();
  }
}

typedef TranscriptEmbedder = Future<List<double>> Function(String text);

/// Splits a transcript into paragraphs and estimates each start time.
List<({String text, double startSeconds})> chunkTranscriptParagraphs(
  String transcript, {
  double durationSeconds = 0,
}) {
  final parts = transcript
      .split(RegExp(r'\n\s*\n'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) return const [];
    return [(text: trimmed, startSeconds: 0)];
  }
  final slice = durationSeconds > 0 ? durationSeconds / parts.length : 0.0;
  return [
    for (var i = 0; i < parts.length; i++)
      (text: parts[i], startSeconds: slice * i),
  ];
}

/// Local cosine search over paragraph embeddings stored beside sqlite-vec.
class VectorSearchService {
  VectorSearchService({
    required TranscriptChunkStore store,
    required TranscriptEmbedder embedder,
  }) : _store = store,
       _embedder = embedder;

  final TranscriptChunkStore _store;
  final TranscriptEmbedder _embedder;

  Future<void> indexTranscript({
    required String entryId,
    required String transcript,
    double durationSeconds = 0,
  }) async {
    final chunks = chunkTranscriptParagraphs(
      transcript,
      durationSeconds: durationSeconds,
    );
    for (var i = 0; i < chunks.length; i++) {
      final embedding = await _embedder(chunks[i].text);
      await _store.upsert(
        TranscriptChunk(
          entryId: entryId,
          chunkIndex: i,
          text: chunks[i].text,
          startSeconds: chunks[i].startSeconds,
          embedding: embedding,
        ),
      );
    }
  }

  Future<List<SemanticSearchHit>> search(String query, {int limit = 5}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final queryEmbedding = await _embedder(trimmed);
    return _lookup(queryEmbedding, limit: limit);
  }

  /// Embeds [query] locally, then times only the sqlite-vec cosine lookup.
  ///
  /// The reply is assembled from the matched paragraphs. Nothing is sent off
  /// the device, and this is not called while the person is still typing.
  Future<ConversationalSearchResult> ask(String query, {int limit = 5}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return ConversationalSearchResult(
        query: query,
        reply: '',
        citations: const [],
        lookupLatency: Duration.zero,
      );
    }
    final queryEmbedding = await _embedder(trimmed);
    final watch = Stopwatch()..start();
    final hits = await _lookup(queryEmbedding, limit: limit);
    watch.stop();
    return ConversationalSearchResult(
      query: trimmed,
      reply: composeConversationalReply(trimmed, hits),
      citations: hits,
      lookupLatency: watch.elapsed,
    );
  }

  Future<List<SemanticSearchHit>> _lookup(
    List<double> queryEmbedding, {
    required int limit,
  }) async {
    final rows = await _store.all();
    if (rows.isEmpty) return const [];
    final byKey = {
      for (final row in rows) '${row.entryId}#${row.chunkIndex}': row,
    };
    final matches = await _store.nearestMatches(queryEmbedding, limit: limit);
    if (matches != null && matches.isNotEmpty) {
      final hits = <SemanticSearchHit>[];
      for (final match in matches) {
        final row = byKey[match.key];
        if (row == null) continue;
        hits.add(
          SemanticSearchHit(
            entryId: row.entryId,
            chunkIndex: row.chunkIndex,
            text: row.text,
            startSeconds: row.startSeconds,
            score: match.cosine,
          ),
        );
      }
      if (hits.isNotEmpty) return hits;
    }
    final ranked = rankEmbeddingBlobs(
      EmbeddingBlobRankInput(
        queryEmbedding: queryEmbedding,
        rows: [
          for (final row in rows)
            EmbeddingBlobRow(
              entryId: '${row.entryId}#${row.chunkIndex}',
              blob: _doublesToBlob(row.embedding),
            ),
        ],
        limit: limit,
      ),
    );
    return [
      for (final hit in ranked)
        if (byKey[hit.entryId] != null)
          SemanticSearchHit(
            entryId: byKey[hit.entryId]!.entryId,
            chunkIndex: byKey[hit.entryId]!.chunkIndex,
            text: byKey[hit.entryId]!.text,
            startSeconds: byKey[hit.entryId]!.startSeconds,
            score: hit.cosineSimilarity,
          ),
    ];
  }
}

abstract class TranscriptChunkStore {
  Future<void> upsert(TranscriptChunk chunk);

  Future<List<TranscriptChunk>> all();

  /// sqlite-vec row keys (`entryId#chunkIndex`) when the vec0 table can answer.
  Future<List<String>?> nearestKeys(
    List<double> query, {
    int limit = 5,
  }) async => null;

  /// Nearest chunks with cosine similarity. Null when sqlite-vec is absent.
  Future<List<VecMatch>?> nearestMatches(
    List<double> query, {
    int limit = 5,
  }) async {
    final keys = await nearestKeys(query, limit: limit);
    if (keys == null || keys.isEmpty) return null;
    return [
      for (var index = 0; index < keys.length; index++)
        VecMatch(
          key: keys[index],
          cosine: 1 - (index / keys.length),
        ),
    ];
  }
}

class MemoryTranscriptChunkStore implements TranscriptChunkStore {
  final List<TranscriptChunk> _rows = [];

  @override
  Future<void> upsert(TranscriptChunk chunk) async {
    _rows.removeWhere(
      (row) =>
          row.entryId == chunk.entryId && row.chunkIndex == chunk.chunkIndex,
    );
    _rows.add(chunk);
  }

  @override
  Future<List<TranscriptChunk>> all() async => List.unmodifiable(_rows);

  @override
  Future<List<String>?> nearestKeys(
    List<double> query, {
    int limit = 5,
  }) async => null;

  @override
  Future<List<VecMatch>?> nearestMatches(
    List<double> query, {
    int limit = 5,
  }) async => null;
}

/// Stores paragraph embeddings in SQLite. When sqlite-vec is present the
/// same rows are mirrored into a vec0 table for nearest-neighbor lookup.
class SqliteTranscriptChunkStore implements TranscriptChunkStore {
  SqliteTranscriptChunkStore(this._db);

  final Database _db;
  var _ready = false;
  var _vecChecked = false;
  var _vecAvailable = false;

  static const table = 'transcript_chunk_embeddings';
  static const vecTable = 'transcript_chunk_vec';

  Future<void> _ensure() async {
    if (_ready) return;
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        entry_id TEXT NOT NULL,
        chunk_index INTEGER NOT NULL,
        text TEXT NOT NULL,
        start_seconds REAL NOT NULL,
        embedding BLOB NOT NULL,
        PRIMARY KEY (entry_id, chunk_index)
      )
    ''');
    try {
      final sample = await _db.rawQuery(
        'SELECT embedding FROM $table LIMIT 1',
      );
      final dims = sample.isEmpty
          ? 0
          : _blobToDoubles(sample.first['embedding'] as Uint8List).length;
      if (dims > 0) {
        await _db.execute('''
          CREATE VIRTUAL TABLE IF NOT EXISTS $vecTable USING vec0(
            entry_id TEXT PRIMARY KEY,
            embedding float[$dims]
          )
        ''');
      }
    } on Object {
      // sqlite-vec is optional. Cosine ranking uses the blob table.
    }
    _ready = true;
  }

  @override
  Future<void> upsert(TranscriptChunk chunk) async {
    await _ensure();
    await _db.insert(table, {
      'entry_id': chunk.entryId,
      'chunk_index': chunk.chunkIndex,
      'text': chunk.text,
      'start_seconds': chunk.startSeconds,
      'embedding': _doublesToBlob(chunk.embedding),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await _mirrorVec(chunk);
  }

  Future<void> _mirrorVec(TranscriptChunk chunk) async {
    if (!_vecChecked) {
      _vecChecked = true;
      try {
        await _db.execute('''
          CREATE VIRTUAL TABLE IF NOT EXISTS $vecTable USING vec0(
            chunk_key TEXT PRIMARY KEY,
            embedding float[${chunk.embedding.length}]
          )
        ''');
        _vecAvailable = true;
      } on Object {
        _vecAvailable = false;
      }
    }
    if (!_vecAvailable) return;
    try {
      await _db.insert(vecTable, {
        'chunk_key': '${chunk.entryId}#${chunk.chunkIndex}',
        'embedding': _doublesToBlob(chunk.embedding),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } on Object {
      _vecAvailable = false;
    }
  }

  @override
  Future<List<TranscriptChunk>> all() async {
    await _ensure();
    final rows = await _db.query(table);
    return [
      for (final row in rows)
        TranscriptChunk(
          entryId: row['entry_id']! as String,
          chunkIndex: row['chunk_index']! as int,
          text: row['text']! as String,
          startSeconds: (row['start_seconds']! as num).toDouble(),
          embedding: _blobToDoubles(row['embedding']! as Uint8List),
        ),
    ];
  }

  @override
  Future<List<String>?> nearestKeys(
    List<double> query, {
    int limit = 5,
  }) async {
    final matches = await nearestMatches(query, limit: limit);
    if (matches == null) return null;
    return [for (final match in matches) match.key];
  }

  @override
  Future<List<VecMatch>?> nearestMatches(
    List<double> query, {
    int limit = 5,
  }) async {
    await _ensure();
    if (!_vecAvailable) return null;
    try {
      final rows = await _db.rawQuery(
        '''
        SELECT chunk_key, distance
        FROM $vecTable
        WHERE embedding MATCH ?
          AND k = ?
        ORDER BY distance
        ''',
        [_doublesToBlob(query), limit],
      );
      if (rows.isEmpty) return null;
      return [
        for (final row in rows)
          if (row['chunk_key'] is String)
            VecMatch(
              key: row['chunk_key']! as String,
              cosine: 1 - ((row['distance'] as num?)?.toDouble() ?? 1),
            ),
      ];
    } on Object {
      return null;
    }
  }
}

/// Small local embedder for tests and for devices without the ONNX model.
List<double> hashTranscriptEmbedding(String text, {int dimensions = 16}) {
  final vector = List<double>.filled(dimensions, 0);
  final tokens = text.toLowerCase().split(RegExp(r'[^a-z0-9]+'));
  for (final token in tokens) {
    if (token.isEmpty) continue;
    final bucket = token.hashCode.abs() % dimensions;
    vector[bucket] += 1;
  }
  var norm = 0.0;
  for (final value in vector) {
    norm += value * value;
  }
  norm = math.sqrt(norm);
  if (norm == 0) return vector;
  return [for (final value in vector) value / norm];
}

Uint8List _doublesToBlob(List<double> values) {
  final floats = Float32List.fromList(values);
  return Uint8List.view(
    floats.buffer,
    floats.offsetInBytes,
    floats.lengthInBytes,
  );
}

List<double> _blobToDoubles(Uint8List blob) {
  final floats = Float32List.view(
    blob.buffer,
    blob.offsetInBytes,
    blob.lengthInBytes ~/ Float32List.bytesPerElement,
  );
  return floats.toList(growable: false);
}

class SemanticSearchQuery extends Notifier<List<SemanticSearchHit>> {
  @override
  List<SemanticSearchHit> build() => const [];

  Future<void> run(String query) async {
    state = await ref.read(semanticSearchServiceProvider).search(query);
  }
}

final semanticSearchServiceProvider = Provider<VectorSearchService>((ref) {
  return VectorSearchService(
    store: MemoryTranscriptChunkStore(),
    embedder: (text) async => hashTranscriptEmbedding(text),
  );
});

final semanticSearchProvider =
    NotifierProvider<SemanticSearchQuery, List<SemanticSearchHit>>(
      SemanticSearchQuery.new,
    );
