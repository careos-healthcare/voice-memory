import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archiveme_mobile/features/search/reflection_embedding_contract.dart';
import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_009_reflection_embeddings.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_021_deleted_entries.dart';
import 'package:archiveme_mobile/sync/record_sync.dart';
import 'package:sqflite/sqflite.dart';

/// A past journal entry close to a newly saved transcript.
class SimilarEntry {
  const SimilarEntry({
    required this.id,
    required this.createdAt,
    required this.transcript,
    required this.cosineSimilarity,
    this.localAudioPath,
    this.quote,
    this.startSeconds,
    this.startTimeMs,
  });

  final String id;
  final DateTime createdAt;
  final String transcript;

  /// One sentence from [transcript], chosen because it is closest to the
  /// new entry. The words are the person's own.
  final String? quote;
  final String? localAudioPath;

  /// Seconds into the recording where [quote] starts, when word timestamps exist.
  final int? startSeconds;

  /// Milliseconds into the recording where the matched chunk starts.
  final int? startTimeMs;
  final double cosineSimilarity;

  SimilarEntry atChunk(int startTimeMs) {
    return SimilarEntry(
      id: id,
      createdAt: createdAt,
      transcript: transcript,
      cosineSimilarity: cosineSimilarity,
      localAudioPath: localAudioPath,
      quote: quote,
      startSeconds: startSeconds,
      startTimeMs: startTimeMs,
    );
  }
}

/// Local SQLCipher access for journal vectors stored in `reflection_embeddings`.
class DatabaseProvider {
  DatabaseProvider(this._db);

  final Database _db;

  static const embeddingsTable =
      Migration009ReflectionEmbeddings.embeddingsTable;

  /// Cosine matches below this are left off the receipt.
  static const double minimumSimilarity = 0.35;

  Future<List<double>?> readEmbedding(String entryId) async {
    if (entryId.isEmpty) return null;
    final rows = await _db.query(
      embeddingsTable,
      columns: ['embedding'],
      where: 'entry_id = ?',
      whereArgs: [entryId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final blob = rows.first['embedding'] as Uint8List?;
    if (blob == null || blob.isEmpty) return null;
    return _blobToEmbedding(blob);
  }

  /// Past entries older than [excludeWithinDays], closest to [vector] first.
  Future<List<SimilarEntry>> findSimilarEntries(
    List<double> vector, {
    int excludeWithinDays = 7,
    int limit = 3,
    DateTime? now,
  }) async {
    if (vector.length != ReflectionEmbeddingContract.dimensions) {
      throw ArgumentError.value(
        vector.length,
        'vector.length',
        'expected ${ReflectionEmbeddingContract.dimensions}',
      );
    }
    if (limit <= 0) return const [];

    final cutoff = (now ?? DateTime.now())
        .toUtc()
        .subtract(Duration(days: excludeWithinDays))
        .millisecondsSinceEpoch;
    final rows = await _db.rawQuery(
      '''
      SELECT e.entry_id AS entry_id,
             e.embedding AS embedding,
             j.created_at AS created_at,
             j.transcript AS transcript,
             j.payload_json AS payload_json
      FROM $embeddingsTable AS e
      JOIN journal_entries AS j ON j.id = e.entry_id
      WHERE j.deleted_at IS NULL
        AND j.created_at < ?
      ''',
      [cutoff],
    );

    final scored = <SimilarEntry>[];
    for (final row in rows) {
      final id = row['entry_id'] as String? ?? '';
      final transcript = (row['transcript'] as String? ?? '').trim();
      final blob = row['embedding'] as Uint8List?;
      if (id.isEmpty || transcript.isEmpty || blob == null) continue;
      final embedding = _blobToEmbedding(blob);
      final score = _cosineSimilarity(vector, embedding);
      if (score < minimumSimilarity) continue;
      scored.add(
        SimilarEntry(
          id: id,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            row['created_at'] as int? ?? 0,
            isUtc: true,
          ),
          transcript: transcript,
          localAudioPath: _audioPath(row['payload_json']),
          cosineSimilarity: score,
        ),
      );
    }

    scored.sort((a, b) {
      final byScore = b.cosineSimilarity.compareTo(a.cosineSimilarity);
      if (byScore != 0) return byScore;
      return a.id.compareTo(b.id);
    });
    return scored.take(limit).toList(growable: false);
  }

  static const deletedEntriesTable = Migration021DeletedEntries.table;

  /// A deletion stays until other devices have had time to learn about it.
  static const tombstoneRetention = RecordSyncSchedule.tombstoneRetention;

  Future<void> recordTombstone(
    String id, {
    DateTime? deletedAt,
    String syncStatus = 'pendingUpload',
  }) async {
    if (id.isEmpty) return;
    await _ensureDeletedEntries();
    final when = (deletedAt ?? DateTime.now()).toUtc();
    await _db.insert(deletedEntriesTable, {
      'id': id,
      'deleted_at': when.millisecondsSinceEpoch,
      'sync_status': syncStatus,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<DeletedEntryTombstone?> tombstoneFor(String id) async {
    await _ensureDeletedEntries();
    final rows = await _db.query(
      deletedEntriesTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DeletedEntryTombstone.fromRow(rows.first);
  }

  /// Drops tombstones only after [tombstoneRetention]. A shorter window is raised to 180 days.
  Future<int> purgeExpiredTombstones({
    DateTime? now,
    Duration retention = tombstoneRetention,
  }) async {
    await _ensureDeletedEntries();
    final window = retention < tombstoneRetention
        ? tombstoneRetention
        : retention;
    final cutoff = (now ?? DateTime.now())
        .toUtc()
        .subtract(window)
        .millisecondsSinceEpoch;
    return _db.delete(
      deletedEntriesTable,
      where: 'deleted_at < ?',
      whereArgs: [cutoff],
    );
  }

  Future<void> _ensureDeletedEntries() {
    return _db.execute('''
      CREATE TABLE IF NOT EXISTS $deletedEntriesTable (
        id TEXT PRIMARY KEY NOT NULL,
        deleted_at INTEGER NOT NULL,
        sync_status TEXT NOT NULL
      )
    ''');
  }

  static const onThisDaySilenceColumn = 'is_silenced_from_on_this_day';

  /// Hides one moment from On This Day without deleting it.
  Future<void> silenceEntryFromOnThisDay(String entryId) async {
    if (entryId.isEmpty) return;
    final info = await _db.rawQuery('PRAGMA table_info(journal_entries)');
    final exists = info.any((row) => row['name'] == onThisDaySilenceColumn);
    if (!exists) {
      await _db.execute(
        'ALTER TABLE journal_entries ADD COLUMN $onThisDaySilenceColumn INTEGER NOT NULL DEFAULT 0',
      );
    }
    await _db.update(
      'journal_entries',
      {onThisDaySilenceColumn: 1},
      where: 'id = ?',
      whereArgs: [entryId],
    );
  }

  static String? _audioPath(Object? payloadJson) {
    if (payloadJson is! String || payloadJson.isEmpty) return null;
    try {
      final decoded = jsonDecode(payloadJson);
      if (decoded is! Map) return null;
      final path = decoded['localAudioPath'];
      if (path is! String) return null;
      final trimmed = path.trim();
      return trimmed.isEmpty ? null : trimmed;
    } on Object {
      return null;
    }
  }

  static List<double> _blobToEmbedding(Uint8List blob) {
    final floats = Float32List.view(
      blob.buffer,
      blob.offsetInBytes,
      blob.lengthInBytes ~/ Float32List.bytesPerElement,
    );
    return floats.toList(growable: false);
  }

  static double _cosineSimilarity(List<double> a, List<double> b) {
    final length = math.min(a.length, b.length);
    if (length == 0) return 0;
    var dot = 0.0;
    var normA = 0.0;
    var normB = 0.0;
    for (var i = 0; i < length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0;
    return dot / (math.sqrt(normA) * math.sqrt(normB));
  }
}

/// One deleted journal entry, kept so the deletion can sync.
class DeletedEntryTombstone {
  const DeletedEntryTombstone({
    required this.id,
    required this.deletedAt,
    required this.syncStatus,
  });

  final String id;
  final DateTime deletedAt;
  final String syncStatus;

  factory DeletedEntryTombstone.fromRow(Map<String, Object?> row) {
    return DeletedEntryTombstone(
      id: row['id'] as String? ?? '',
      deletedAt: DateTime.fromMillisecondsSinceEpoch(
        row['deleted_at'] as int? ?? 0,
        isUtc: true,
      ),
      syncStatus:
          row['sync_status'] as String? ?? SyncStatus.pendingUpload.name,
    );
  }
}

/// Writes a tombstone into the open account database when a journal entry is deleted.
abstract final class JournalTombstones {
  JournalTombstones._();

  static Database? _database;

  static void bind(Database database) => _database = database;

  static void unbind() => _database = null;

  static Future<void> remember(String id) async {
    final database = _database;
    if (database == null || id.isEmpty) return;
    try {
      await DatabaseProvider(database).recordTombstone(id);
    } on Object {
      return;
    }
  }
}

/// The words the person said, shortened on a word boundary.
String shortVerbatimQuote(String transcript, {int maxChars = 140}) {
  final trimmed = transcript.trim();
  if (trimmed.length <= maxChars) return trimmed;
  final cut = trimmed.substring(0, maxChars);
  final space = cut.lastIndexOf(' ');
  if (space < 40) return cut;
  return cut.substring(0, space);
}
