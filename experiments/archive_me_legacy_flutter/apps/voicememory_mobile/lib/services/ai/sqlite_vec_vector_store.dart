import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite_vec_native/sqlite_vec_native.dart';

import '../analytics/ffi_safety_monitor.dart';
import '../security/native_boundary_fuzzer.dart';

final class SqliteVecRecord {
  SqliteVecRecord({
    required this.entryId,
    required Float32List embedding,
    required this.clusterType,
    required this.updatedAt,
    required this.confidence,
    required Iterable<String> nodeIds,
    required Iterable<String> tags,
  }) : embedding = Float32List.fromList(embedding),
       nodeIds = List.unmodifiable(nodeIds),
       tags = Set.unmodifiable(tags);

  final String entryId;
  final Float32List embedding;
  final String clusterType;
  final DateTime updatedAt;
  final double confidence;
  final List<String> nodeIds;
  final Set<String> tags;
}

final class SqliteVecHit {
  const SqliteVecHit({
    required this.entryId,
    required this.distance,
    required this.nodeIds,
    required this.tags,
    required this.clusterType,
    required this.updatedAt,
    required this.confidence,
  });

  final String entryId;
  final double distance;
  final List<String> nodeIds;
  final Set<String> tags;
  final String clusterType;
  final DateTime updatedAt;
  final double confidence;

  double get cosineSimilarity => (1 - distance).clamp(-1, 1);
}

/// Native sqlite-vec `vec0` index for content-free local embeddings.
///
/// The extension is registered through sqlite3's auto-extension API. No
/// runtime `load_extension()` SQL is enabled, which keeps arbitrary dynamic
/// library loading disabled on mobile.
final class SqliteVecVectorStore {
  SqliteVecVectorStore._({
    required Database? database,
    required this.databasePath,
    required this.dimensions,
    required this.unavailableReason,
    required FFIResourceLease? safetyLease,
  }) : // Public named parameters cannot initialize private fields directly.
       // ignore: prefer_initializing_formals
       _database = database,
       // Public named parameters cannot initialize private fields directly.
       // ignore: prefer_initializing_formals
       _safetyLease = safetyLease;

  final Database? _database;
  final FFIResourceLease? _safetyLease;
  final String databasePath;
  final int dimensions;
  final String? unavailableReason;
  bool _closed = false;

  bool get isAccelerated => _database != null && !_closed;

  static Future<SqliteVecVectorStore> open({
    required String databasePath,
    required int dimensions,
  }) async {
    if (dimensions <= 0 || dimensions > 8192) {
      throw ArgumentError.value(
        dimensions,
        'dimensions',
        'must be between 1 and 8192',
      );
    }
    Database? database;
    try {
      await Directory(path.dirname(databasePath)).create(recursive: true);
      sqlite3.ensureExtensionLoaded(SqliteExtension(sqliteVecInitPointer()));
      database = sqlite3.open(databasePath)
        ..execute('PRAGMA journal_mode = WAL')
        ..execute('PRAGMA synchronous = NORMAL')
        ..execute('PRAGMA busy_timeout = 3000')
        ..select('SELECT vec_version()');
      _createSchema(database, dimensions);
      return SqliteVecVectorStore._(
        database: database,
        databasePath: databasePath,
        dimensions: dimensions,
        unavailableReason: null,
        safetyLease: FFISafetyMonitor.installed?.acquire(
          FFIResourceKind.sqliteDatabase,
          owner: 'sqlite-vec',
        ),
      );
    } on Object catch (error) {
      database?.close();
      return SqliteVecVectorStore._(
        database: null,
        databasePath: databasePath,
        dimensions: dimensions,
        unavailableReason: '$error',
        safetyLease: null,
      );
    }
  }

  static void _createSchema(Database database, int dimensions) {
    database.execute('''
      CREATE TABLE IF NOT EXISTS semantic_vector_schema (
        singleton INTEGER PRIMARY KEY CHECK (singleton = 1),
        dimensions INTEGER NOT NULL
      )
    ''');
    final row = database.select(
      'SELECT dimensions FROM semantic_vector_schema WHERE singleton = 1',
    );
    if (row.isNotEmpty && row.single['dimensions'] != dimensions) {
      database.execute('DROP TABLE IF EXISTS semantic_vectors');
      database.execute('DELETE FROM semantic_vector_schema');
    }
    database.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS semantic_vectors USING vec0(
        entry_id TEXT PRIMARY KEY,
        embedding FLOAT[$dimensions] distance_metric=cosine,
        cluster_type TEXT,
        updated_at INTEGER,
        confidence FLOAT,
        +node_ids TEXT,
        +tags TEXT
      )
    ''');
    database.execute(
      'INSERT OR REPLACE INTO semantic_vector_schema(singleton, dimensions) '
      'VALUES (1, ?)',
      [dimensions],
    );
  }

  void replaceAll(Iterable<SqliteVecRecord> records) {
    final database = _requiredDatabase();
    database.execute('BEGIN IMMEDIATE');
    PreparedStatement? insert;
    try {
      database.execute('DELETE FROM semantic_vectors');
      insert = database.prepare('''
        INSERT INTO semantic_vectors(
          entry_id,
          embedding,
          cluster_type,
          updated_at,
          confidence,
          node_ids,
          tags
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ''');
      for (final record in records) {
        _validate(record);
        insert.execute([
          record.entryId,
          _vectorBytes(record.embedding),
          record.clusterType,
          record.updatedAt.toUtc().millisecondsSinceEpoch,
          record.confidence.clamp(0, 1),
          jsonEncode(record.nodeIds),
          jsonEncode(record.tags.toList()..sort()),
        ]);
      }
      database.execute('COMMIT');
    } on Object {
      database.execute('ROLLBACK');
      rethrow;
    } finally {
      insert?.close();
    }
  }

  /// Transactionally adds or replaces a bounded batch without rebuilding the
  /// entire disposable sqlite-vec cache.
  void upsertAll(Iterable<SqliteVecRecord> records) {
    final database = _requiredDatabase();
    final values = records.toList(growable: false);
    if (values.isEmpty) return;
    if (values.length > 5000) {
      throw ArgumentError.value(
        values.length,
        'records.length',
        'batch exceeds 5000 records',
      );
    }
    PreparedStatement? remove;
    PreparedStatement? insert;
    database.execute('BEGIN IMMEDIATE');
    try {
      remove = database.prepare(
        'DELETE FROM semantic_vectors WHERE entry_id = ?',
      );
      insert = database.prepare('''
        INSERT INTO semantic_vectors(
          entry_id,
          embedding,
          cluster_type,
          updated_at,
          confidence,
          node_ids,
          tags
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ''');
      for (final record in values) {
        _validate(record);
        remove.execute([record.entryId]);
        insert.execute([
          record.entryId,
          _vectorBytes(record.embedding),
          record.clusterType,
          record.updatedAt.toUtc().millisecondsSinceEpoch,
          record.confidence.clamp(0, 1),
          jsonEncode(record.nodeIds),
          jsonEncode(record.tags.toList()..sort()),
        ]);
      }
      database.execute('COMMIT');
    } on Object {
      database.execute('ROLLBACK');
      rethrow;
    } finally {
      remove?.close();
      insert?.close();
    }
  }

  List<SqliteVecHit> search(
    Float32List query, {
    int limit = 20,
    String? clusterType,
    DateTime? updatedAfter,
    double minimumConfidence = 0,
  }) {
    if (query.length != dimensions) {
      throw ArgumentError.value(query.length, 'query', 'dimension mismatch');
    }
    NativeBoundaryContract.requireBoundedBytes(
      query.lengthInBytes,
      maximum: 8192 * 4,
    );
    if (query.any((value) => !value.isFinite)) {
      throw const NativeBoundaryViolation(
        'sqlite-vec query contains a non-finite value.',
      );
    }
    final boundedLimit = limit.clamp(1, 500);
    final clauses = <String>['embedding MATCH ?', 'k = ?', 'confidence >= ?'];
    final arguments = <Object?>[
      _vectorBytes(query),
      boundedLimit,
      minimumConfidence.clamp(0, 1),
    ];
    if (clusterType?.trim().isNotEmpty == true) {
      clauses.add('cluster_type = ?');
      arguments.add(clusterType!.trim());
    }
    if (updatedAfter != null) {
      clauses.add('updated_at >= ?');
      arguments.add(updatedAfter.toUtc().millisecondsSinceEpoch);
    }
    final rows = _requiredDatabase().select('''
        SELECT
          entry_id,
          distance,
          cluster_type,
          updated_at,
          confidence,
          node_ids,
          tags
        FROM semantic_vectors
        WHERE ${clauses.join(' AND ')}
        ORDER BY distance ASC
        ''', arguments);
    return [
      for (final row in rows)
        SqliteVecHit(
          entryId: row['entry_id'] as String,
          distance: (row['distance'] as num).toDouble(),
          clusterType: row['cluster_type'] as String? ?? '',
          updatedAt: DateTime.fromMillisecondsSinceEpoch(
            (row['updated_at'] as num?)?.toInt() ?? 0,
            isUtc: true,
          ),
          confidence: (row['confidence'] as num?)?.toDouble() ?? 0,
          nodeIds: _strings(row['node_ids']),
          tags: _strings(row['tags']).toSet(),
        ),
    ];
  }

  int get count {
    final row = _requiredDatabase().select(
      'SELECT COUNT(*) AS count FROM semantic_vectors',
    );
    return row.single['count'] as int;
  }

  void clear() {
    _requiredDatabase().execute('DELETE FROM semantic_vectors');
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _database?.close();
    _safetyLease?.release();
  }

  Database _requiredDatabase() {
    if (!isAccelerated) {
      throw StateError(
        unavailableReason ?? 'sqlite-vec vector store is unavailable',
      );
    }
    return _database!;
  }

  void _validate(SqliteVecRecord record) {
    final entryBytes = utf8.encode(record.entryId);
    NativeBoundaryContract.requireBoundedBytes(
      entryBytes.length,
      maximum: 4096,
    );
    NativeBoundaryContract.requireBoundedBytes(
      record.embedding.lengthInBytes,
      maximum: 8192 * 4,
    );
    if (record.entryId.isEmpty ||
        record.embedding.length != dimensions ||
        record.embedding.any((value) => !value.isFinite)) {
      throw ArgumentError('Invalid sqlite-vec record ${record.entryId}.');
    }
  }
}

Uint8List _vectorBytes(Float32List vector) =>
    vector.buffer.asUint8List(vector.offsetInBytes, vector.lengthInBytes);

List<String> _strings(Object? encoded) {
  if (encoded is! String) return const [];
  final value = jsonDecode(encoded);
  return value is List
      ? value.whereType<String>().toList(growable: false)
      : const [];
}
