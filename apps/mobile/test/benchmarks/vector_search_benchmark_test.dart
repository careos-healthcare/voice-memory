import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archiveme_mobile/core/database/benchmark_seeder_isolate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

const _scales = <int>[1000, 10000, 50000, 100000];
const _topK = <int>[5, 10, 50];
const _warmSamples = 100;
const int _lanesPerVector = benchmarkEmbeddingDimensions ~/ 4;

void main() {
  test(
    'vector search latency, memory, and database size',
    () {
      final directory = Directory.systemTemp.createTempSync(
        'vector-search-bench',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final results = <Map<String, Object?>>[];
      Object? failure;
      StackTrace? stack;
      try {
        for (final count in _scales) {
          results.add(_measureScale(directory.path, count));
        }
      } on Object catch (error, trace) {
        failure = error;
        stack = trace;
      } finally {
        final payload = <String, Object?>{
          'generatedAt': DateTime.now().toUtc().toIso8601String(),
          'dimensions': benchmarkEmbeddingDimensions,
          'warmSamples': _warmSamples,
          'distance': 'cosine',
          'results': results,
          'table': _markdownTable(results),
        };
        _writeResults(payload);
        stdout.writeln(_markdownTable(results));
      }
      if (failure != null) {
        Error.throwWithStackTrace(failure, stack!);
      }
      _assertThresholds(results);
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

Map<String, Object?> _measureScale(String directory, int entryCount) {
  final path = '$directory/bench-$entryCount.db';
  final seeded = insertBenchmarkEntries(
    BenchmarkSeedRequest(databasePath: path, entryCount: entryCount),
  );
  final dbBytes = _databaseBytes(path);
  final db = sql.sqlite3.open(path);
  final workspace = _SearchWorkspace();
  final rssBefore = ProcessInfo.currentRss;
  var rssPeak = rssBefore;
  try {
    final vec0 = _vec0Ready(db);
    final cold = _coldQuery(db, k: 10, vec0: vec0);
    rssPeak = math.max(rssPeak, ProcessInfo.currentRss);
    if (!vec0) {
      workspace.load(db, entryCount);
      rssPeak = math.max(rssPeak, ProcessInfo.currentRss);
    }

    final byK = <String, Object?>{};
    for (final k in _topK) {
      final warm = _warmQueries(
        db: db,
        workspace: workspace,
        entryCount: entryCount,
        k: k,
        vec0: vec0,
      );
      rssPeak = math.max(rssPeak, warm.rssPeak);
      byK['$k'] = warm.toJson();
    }
    final top10 = byK['10']! as Map<String, Object?>;
    final rssAfterSearch = ProcessInfo.currentRss;
    rssPeak = math.max(rssPeak, rssAfterSearch);
    workspace.release();
    db.execute('PRAGMA shrink_memory');
    final rssIdle = ProcessInfo.currentRss;
    expect(workspace.retainedBytes, 0);
    expect(rssIdle, lessThanOrEqualTo(rssPeak));

    return <String, Object?>{
      'entryCount': entryCount,
      'batchInsertTimeMs': seeded.elapsedMilliseconds,
      'recordsPerSecond': seeded.recordsPerSecond,
      'vec0': vec0 && seeded.vec0,
      'coldTop10Ms': cold,
      'top10': top10,
      'byK': byK,
      'dbFileSizeBytes': dbBytes,
      'peakMemoryBytes': rssPeak,
      'heapDeltaBytes': rssAfterSearch - rssBefore,
      'idleMemoryBytes': rssIdle,
      'workspaceBytesAfter': workspace.retainedBytes,
    };
  } finally {
    workspace.release();
    db.close();
  }
}

double _coldQuery(sql.Database db, {required int k, required bool vec0}) {
  final watch = Stopwatch()..start();
  if (vec0) {
    _vec0Search(db, _queryLanes(0), k);
  } else {
    _blobColdSearch(db, _queryFloats(0), k);
  }
  watch.stop();
  return watch.elapsedMicroseconds / 1000;
}

_WarmStats _warmQueries({
  required sql.Database db,
  required _SearchWorkspace workspace,
  required int entryCount,
  required int k,
  required bool vec0,
}) {
  final samples = List<double>.filled(_warmSamples, 0);
  var rssPeak = ProcessInfo.currentRss;
  final random = math.Random(entryCount * 17 + k);
  for (var sample = 0; sample < _warmSamples; sample++) {
    final lanes = workspace.queryLanes;
    _fillRandomUnit(workspace.queryFloats, random);
    final watch = Stopwatch()..start();
    if (vec0) {
      _vec0Search(db, lanes, k);
    } else {
      _simdSearch(
        matrix: workspace.lanes,
        rows: entryCount,
        query: lanes,
        k: k,
        bestDistance: workspace.bestDistance,
        bestIndex: workspace.bestIndex,
      );
    }
    watch.stop();
    samples[sample] = watch.elapsedMicroseconds / 1000;
    if (sample % 25 == 0) {
      rssPeak = math.max(rssPeak, ProcessInfo.currentRss);
    }
  }
  samples.sort();
  return _WarmStats(
    averageMs: samples.reduce((a, b) => a + b) / samples.length,
    p50Ms: _percentile(samples, 50),
    p95Ms: _percentile(samples, 95),
    p99Ms: _percentile(samples, 99),
    rssPeak: rssPeak,
  );
}

void _simdSearch({
  required Float32x4List matrix,
  required int rows,
  required Float32x4List query,
  required int k,
  required Float64List bestDistance,
  required Int32List bestIndex,
}) {
  for (var i = 0; i < k; i++) {
    bestDistance[i] = 2;
    bestIndex[i] = -1;
  }
  var worst = 0;
  for (var row = 0; row < rows; row++) {
    final distance = 1 - _dot(matrix, row, query);
    if (distance >= bestDistance[worst]) continue;
    bestDistance[worst] = distance;
    bestIndex[worst] = row;
    worst = 0;
    for (var i = 1; i < k; i++) {
      if (bestDistance[i] > bestDistance[worst]) worst = i;
    }
  }
}

double _dot(Float32x4List matrix, int row, Float32x4List query) {
  final start = row * _lanesPerVector;
  var a = Float32x4.zero();
  var b = Float32x4.zero();
  var c = Float32x4.zero();
  var d = Float32x4.zero();
  for (var i = 0; i < _lanesPerVector; i += 4) {
    a += matrix[start + i] * query[i];
    b += matrix[start + i + 1] * query[i + 1];
    c += matrix[start + i + 2] * query[i + 2];
    d += matrix[start + i + 3] * query[i + 3];
  }
  final sum = a + b + c + d;
  return sum.x + sum.y + sum.z + sum.w;
}

void _blobColdSearch(sql.Database db, Float32List query, int k) {
  final bestDistance = Float64List(k);
  final bestIndex = Int32List(k);
  for (var i = 0; i < k; i++) {
    bestDistance[i] = 2;
  }
  var worst = 0;
  var row = 0;
  final statement = db.prepare(
    'SELECT embedding FROM $benchmarkEntriesTable',
  );
  try {
    final cursor = statement.selectCursor();
    while (cursor.moveNext()) {
      final blob = cursor.current['embedding'] as Uint8List;
      final distance = 1 - _dotBlob(blob, query);
      if (distance < bestDistance[worst]) {
        bestDistance[worst] = distance;
        bestIndex[worst] = row;
        worst = 0;
        for (var i = 1; i < k; i++) {
          if (bestDistance[i] > bestDistance[worst]) worst = i;
        }
      }
      row += 1;
    }
  } finally {
    statement.close();
  }
}

double _dotBlob(Uint8List blob, Float32List query) {
  final data = ByteData.sublistView(blob);
  var sum = 0.0;
  for (var i = 0; i < benchmarkEmbeddingDimensions; i++) {
    sum += data.getFloat32(i * 4, Endian.host) * query[i];
  }
  return sum;
}

void _vec0Search(sql.Database db, Float32x4List query, int k) {
  final bytes = query.buffer.asUint8List(
    query.offsetInBytes,
    query.lengthInBytes,
  );
  db.select(
    '''
    SELECT entry_id, distance
    FROM $benchmarkVecTable
    WHERE embedding MATCH ?
      AND k = ?
    ORDER BY distance
    ''',
    [bytes, k],
  );
}

bool _vec0Ready(sql.Database db) {
  final rows = db.select(
    'SELECT name FROM sqlite_master WHERE name = ?',
    [benchmarkVecTable],
  );
  return rows.isNotEmpty;
}

Float32x4List _queryLanes(int seed) {
  final lanes = Float32x4List(_lanesPerVector);
  fillBenchmarkVector(lanes.buffer.asFloat32List(), seed);
  return lanes;
}

Float32List _queryFloats(int seed) {
  final values = Float32List(benchmarkEmbeddingDimensions);
  fillBenchmarkVector(values, seed);
  return values;
}

void _fillRandomUnit(Float32List values, math.Random random) {
  var sumSquares = 0.0;
  for (var i = 0; i < values.length; i++) {
    final value = random.nextDouble() * 2 - 1;
    values[i] = value;
    sumSquares += value * value;
  }
  final inverse = sumSquares == 0 ? 0.0 : 1 / math.sqrt(sumSquares);
  for (var i = 0; i < values.length; i++) {
    values[i] = values[i] * inverse;
  }
}

double _percentile(List<double> sorted, int percentile) {
  final index = (percentile / 100 * sorted.length).ceil() - 1;
  return sorted[index.clamp(0, sorted.length - 1)];
}

class _SearchWorkspace {
  Float32x4List lanes = Float32x4List(0);
  Float32List queryFloats = Float32List(benchmarkEmbeddingDimensions);
  late Float32x4List queryLanes = queryFloats.buffer.asFloat32x4List();
  Float64List bestDistance = Float64List(50);
  Int32List bestIndex = Int32List(50);
  int retainedBytes = 0;

  void load(sql.Database db, int rows) {
    lanes = Float32x4List(rows * _lanesPerVector);
    retainedBytes = lanes.lengthInBytes;
    final dest = lanes.buffer.asFloat32List();
    var row = 0;
    final statement = db.prepare(
      'SELECT embedding FROM $benchmarkEntriesTable',
    );
    try {
      final cursor = statement.selectCursor();
      while (cursor.moveNext()) {
        final blob = cursor.current['embedding'] as Uint8List;
        final start = row * benchmarkEmbeddingDimensions;
        if (blob.lengthInBytes >= benchmarkEmbeddingDimensions * 4 &&
            blob.offsetInBytes % 4 == 0) {
          final view = Float32List.view(
            blob.buffer,
            blob.offsetInBytes,
            benchmarkEmbeddingDimensions,
          );
          dest.setRange(start, start + benchmarkEmbeddingDimensions, view);
        } else {
          final data = ByteData.sublistView(blob);
          for (var i = 0; i < benchmarkEmbeddingDimensions; i++) {
            dest[start + i] = data.getFloat32(i * 4, Endian.host);
          }
        }
        row += 1;
      }
    } finally {
      statement.close();
    }
  }

  void release() {
    lanes = Float32x4List(0);
    retainedBytes = 0;
  }
}

class _WarmStats {
  const _WarmStats({
    required this.averageMs,
    required this.p50Ms,
    required this.p95Ms,
    required this.p99Ms,
    required this.rssPeak,
  });

  final double averageMs;
  final double p50Ms;
  final double p95Ms;
  final double p99Ms;
  final int rssPeak;

  Map<String, Object?> toJson() => {
    'averageMs': averageMs,
    'p50Ms': p50Ms,
    'p95Ms': p95Ms,
    'p99Ms': p99Ms,
  };
}

int _databaseBytes(String path) {
  var total = 0;
  for (final suffix in const ['', '-wal', '-shm']) {
    final file = File('$path$suffix');
    if (file.existsSync()) total += file.lengthSync();
  }
  return total;
}

void _assertThresholds(List<Map<String, Object?>> results) {
  final tenK = _top10(results, 10000);
  final fiftyK = _top10(results, 50000);
  expect(tenK['p50Ms']! as double, lessThan(15));
  expect(fiftyK['p50Ms']! as double, lessThan(80));
}

Map<String, Object?> _top10(List<Map<String, Object?>> results, int count) {
  final top10 = results.firstWhere(
    (row) => row['entryCount'] == count,
  )['top10'];
  if (top10 is! Map<String, Object?>) {
    throw StateError('missing top-10 stats for $count entries');
  }
  return top10;
}

String _markdownTable(List<Map<String, Object?>> results) {
  const header = '''
| Entry Count | Batch Insert Time | Top-10 Latency (p50) | Top-10 Latency (p95) | DB File Size | Peak Memory |
|-------------|-------------------|-----------------------|-----------------------|--------------|-------------|''';
  final lines = <String>[header];
  for (final row in results) {
    final top10 = row['top10']! as Map<String, Object?>;
    final entryCount = row['entryCount']! as int;
    final insertMs = row['batchInsertTimeMs']! as int;
    final p50 = top10['p50Ms']! as double;
    final p95 = top10['p95Ms']! as double;
    final dbBytes = row['dbFileSizeBytes']! as int;
    final peak = row['peakMemoryBytes']! as int;
    lines.add(
      '| ${_cell(entryCount)} '
      '| ${_cell(_ms(insertMs))} '
      '| ${_cell(_msDouble(p50))} '
      '| ${_cell(_msDouble(p95))} '
      '| ${_cell(_bytes(dbBytes))} '
      '| ${_cell(_bytes(peak))} |',
    );
  }
  return lines.join('\n');
}

String _cell(Object? value) => '$value'.padLeft(13);

String _ms(int value) => '$value ms';

String _msDouble(double value) => '${value.toStringAsFixed(2)} ms';

String _bytes(int value) {
  if (value >= 1024 * 1024) {
    return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (value >= 1024) {
    return '${(value / 1024).toStringAsFixed(1)} KB';
  }
  return '$value B';
}

void _writeResults(Map<String, Object?> payload) {
  final file = File('build/benchmark_results.json');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(payload));
}
