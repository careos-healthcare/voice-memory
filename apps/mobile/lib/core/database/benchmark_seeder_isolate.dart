import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archiveme_mobile/src/native/sqlite_vector_extension.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

/// Width of the local embedding model (all-MiniLM-L6-v2).
const benchmarkEmbeddingDimensions = 384;

/// Rows committed together. The last batch may be shorter.
const benchmarkSeedBatchSize = 1000;

const benchmarkEntriesTable = 'benchmark_entries';
const benchmarkVecTable = 'benchmark_entry_vec';

const _categories = <String>[
  'morning',
  'work',
  'family',
  'health',
  'place',
  'rest',
];

const _titles = <String>[
  'Morning notes',
  'After the meeting',
  'Kitchen table',
  'Call home',
  'Walk between trains',
  'Quiet hour',
];

const _places = <String>[
  'London',
  'Manchester',
  'Bristol',
  'Edinburgh',
  'Cardiff',
  'Brighton',
];

const _weather = <String>[
  '12°C',
  '18°C',
  '7°C',
  '21°C',
  '15°C',
  '9°C',
];

const _calendar = <String>[
  'Design review',
  'School run',
  'Lunch',
  'Focus block',
  'Evening walk',
  '',
];

/// One synthetic journal row. The embedding lives in the shared buffer.
class SyntheticEntryPayload {
  const SyntheticEntryPayload({
    required this.id,
    required this.createdAt,
    required this.title,
    required this.category,
    required this.ambientJson,
  });

  final String id;
  final String createdAt;
  final String title;
  final String category;
  final String ambientJson;
}

/// Reused float32 storage for one 384-d vector.
///
/// [fill] overwrites [values] in place. Call [release] when seeding finishes
/// so the buffer is not left holding the last vector.
class SyntheticVectorBuffer {
  SyntheticVectorBuffer({this.dimensions = benchmarkEmbeddingDimensions})
    : values = Float32List(dimensions) {
    bytes = values.buffer.asUint8List(
      values.offsetInBytes,
      values.lengthInBytes,
    );
  }

  final int dimensions;
  final Float32List values;
  late final Uint8List bytes;

  void fill(int index) {
    fillBenchmarkVector(values, index);
  }

  void release() {
    values.fillRange(0, values.length, 0);
  }
}

/// Writes a deterministic unit-length vector into [values].
void fillBenchmarkVector(Float32List values, int index) {
  var state = (index + 1) * 0x9E3779B1;
  var sumSquares = 0.0;
  for (var i = 0; i < values.length; i++) {
    state = (1664525 * state + 1013904223) & 0x7fffffff;
    final value = (state / 0x7fffffff) * 2 - 1;
    values[i] = value;
    sumSquares += value * value;
  }
  final inverse = sumSquares == 0 ? 0.0 : 1 / math.sqrt(sumSquares);
  for (var i = 0; i < values.length; i++) {
    values[i] = values[i] * inverse;
  }
}

double benchmarkVectorNorm(Float32List values) {
  var sumSquares = 0.0;
  for (final value in values) {
    sumSquares += value * value;
  }
  return math.sqrt(sumSquares);
}

/// Timestamp, title, category, and ambient JSON for entry [index].
SyntheticEntryPayload syntheticEntryPayload(int index) {
  final created = DateTime.utc(2024, 1).add(Duration(minutes: index));
  final place = _places[index % _places.length];
  final weather = _weather[index % _weather.length];
  final steps = 1800 + (index % 9000);
  final calendar = _calendar[index % _calendar.length];
  final ambient = <String, Object?>{
    'locality': place,
    'weatherLabel': weather,
    'stepCount': steps,
    if (calendar.isNotEmpty) 'calendarTitle': calendar,
  };
  return SyntheticEntryPayload(
    id: 'bench-$index',
    createdAt: created.toIso8601String(),
    title: '${_titles[index % _titles.length]} ${index + 1}',
    category: _categories[index % _categories.length],
    ambientJson: jsonEncode(ambient),
  );
}

/// What the background seeder should write.
class BenchmarkSeedRequest {
  const BenchmarkSeedRequest({
    required this.databasePath,
    required this.entryCount,
    this.batchSize = benchmarkSeedBatchSize,
    this.dimensions = benchmarkEmbeddingDimensions,
  });

  final String databasePath;
  final int entryCount;
  final int batchSize;
  final int dimensions;
}

/// Insertion timing captured inside the worker isolate.
class BenchmarkSeedReport {
  const BenchmarkSeedReport({
    required this.inserted,
    required this.elapsedMilliseconds,
    required this.recordsPerSecond,
    required this.batchSize,
    required this.batches,
    required this.vec0,
  });

  final int inserted;
  final int elapsedMilliseconds;
  final double recordsPerSecond;
  final int batchSize;
  final int batches;
  final bool vec0;
}

/// Opens the request database on this isolate and writes the synthetic rows.
BenchmarkSeedReport insertBenchmarkEntries(BenchmarkSeedRequest request) {
  if (request.databasePath.trim().isEmpty) {
    throw ArgumentError.value(
      request.databasePath,
      'databasePath',
      'required',
    );
  }
  if (request.entryCount < 0) {
    throw ArgumentError.value(request.entryCount, 'entryCount', 'negative');
  }
  if (request.batchSize < 1) {
    throw ArgumentError.value(request.batchSize, 'batchSize', 'below 1');
  }
  if (request.dimensions != benchmarkEmbeddingDimensions) {
    throw ArgumentError.value(
      request.dimensions,
      'dimensions',
      'expected $benchmarkEmbeddingDimensions',
    );
  }

  final db = sql.sqlite3.open(request.databasePath);
  final buffer = SyntheticVectorBuffer(dimensions: request.dimensions);
  final params = List<Object?>.filled(6, null);
  sql.PreparedStatement? insert;
  sql.PreparedStatement? vecInsert;
  try {
    db
      ..execute('PRAGMA journal_mode = WAL')
      ..execute('PRAGMA synchronous = NORMAL')
      ..execute('''
      CREATE TABLE IF NOT EXISTS $benchmarkEntriesTable (
        id TEXT PRIMARY KEY,
        created_at TEXT NOT NULL,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        ambient_json TEXT NOT NULL,
        embedding BLOB NOT NULL
      )
    ''');
    final vec0 = _prepareVecTable(db, request.dimensions);
    insert = db.prepare('''
      INSERT INTO $benchmarkEntriesTable (
        id, created_at, title, category, ambient_json, embedding
      ) VALUES (?, ?, ?, ?, ?, ?)
    ''');
    if (vec0) {
      vecInsert = db.prepare('''
        INSERT INTO $benchmarkVecTable (entry_id, embedding) VALUES (?, ?)
      ''');
    }

    final watch = Stopwatch()..start();
    var inserted = 0;
    var batches = 0;
    while (inserted < request.entryCount) {
      final count = math.min(request.batchSize, request.entryCount - inserted);
      _writeBatch(
        db: db,
        insert: insert,
        vecInsert: vecInsert,
        buffer: buffer,
        params: params,
        start: inserted,
        count: count,
      );
      inserted += count;
      batches += 1;
    }
    watch.stop();
    final elapsed = watch.elapsedMilliseconds;
    final seconds = elapsed == 0 ? 0.001 : elapsed / 1000;
    return BenchmarkSeedReport(
      inserted: inserted,
      elapsedMilliseconds: elapsed,
      recordsPerSecond: inserted / seconds,
      batchSize: request.batchSize,
      batches: batches,
      vec0: vec0,
    );
  } finally {
    insert?.close();
    vecInsert?.close();
    buffer.release();
    db.close();
  }
}

/// Runs [insertBenchmarkEntries] on a background isolate.
///
/// The UI isolate only waits. SQLite transactions stay on the worker.
class BenchmarkSeederIsolate {
  const BenchmarkSeederIsolate();

  static Future<BenchmarkSeedReport> seed(BenchmarkSeedRequest request) {
    return Isolate.run(() => insertBenchmarkEntries(request));
  }
}

void _writeBatch({
  required sql.Database db,
  required sql.PreparedStatement insert,
  required sql.PreparedStatement? vecInsert,
  required SyntheticVectorBuffer buffer,
  required List<Object?> params,
  required int start,
  required int count,
}) {
  db.execute('BEGIN TRANSACTION');
  try {
    for (var offset = 0; offset < count; offset++) {
      final index = start + offset;
      buffer.fill(index);
      final payload = syntheticEntryPayload(index);
      params[0] = payload.id;
      params[1] = payload.createdAt;
      params[2] = payload.title;
      params[3] = payload.category;
      params[4] = payload.ambientJson;
      params[5] = buffer.bytes;
      insert.execute(params);
      final vec = vecInsert;
      if (vec != null) {
        vec.execute([payload.id, buffer.bytes]);
      }
    }
    db.execute('COMMIT');
  } on Object {
    try {
      db.execute('ROLLBACK');
    } on Object {
      // The original write error is the one that matters.
    }
    rethrow;
  }
}

bool _prepareVecTable(sql.Database db, int dimensions) {
  try {
    sql.sqlite3.loadSqliteVectorExtension();
  } on Object {
    // The bundled extension is optional in tests and on desktop hosts.
  }
  try {
    db
      ..select('SELECT vec_version()')
      ..execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS $benchmarkVecTable USING vec0(
        entry_id TEXT PRIMARY KEY,
        embedding float[$dimensions] distance_metric=cosine
      )
    ''');
    return true;
  } on Object {
    return false;
  }
}
