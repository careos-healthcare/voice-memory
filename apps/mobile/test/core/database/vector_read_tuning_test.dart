import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/core/database/benchmark_seeder_isolate.dart';
import 'package:archiveme_mobile/core/database/database_service.dart';
import 'package:archiveme_mobile/features/search/rag_search_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

void main() {
  late Directory directory;
  late String path;

  setUpAll(() {
    directory = Directory.systemTemp.createTempSync('vector-read-tuning');
    path = '${directory.path}/bench.db';
    insertBenchmarkEntries(
      BenchmarkSeedRequest(databasePath: path, entryCount: 50000),
    );
  });

  tearDownAll(() {
    directory.deleteSync(recursive: true);
  });

  test('warm memory-mapped scans are at least 25% faster', () {
    final warmup = sql.sqlite3.open(path);
    DatabaseTuning.apply(warmup, mmapSize: 0);
    expect(_touchEmbeddings(warmup), greaterThan(0));
    warmup.close();

    final baseline = _medianWarmScan(path, mmapSize: 0);
    final mapped = _medianWarmScan(path, mmapSize: DatabaseTuning.mmapSize);

    expect(
      mapped,
      lessThan(baseline * 0.75),
      reason:
          'mapped ${mapped.toStringAsFixed(2)} ms vs '
          'baseline ${baseline.toStringAsFixed(2)} ms',
    );
  });

  test('ranking 50k entries leaves the main isolate free', () async {
    var ticks = 0;
    final timer =
        Stream<void>.periodic(
          const Duration(milliseconds: 1),
        ).listen((_) {
          ticks += 1;
        });
    final query = Float32List(benchmarkEmbeddingDimensions);
    fillBenchmarkVector(query, 7);

    final hits = await RagIsolatePool().rank(
      RagRankRequest(
        databasePath: path,
        query: query,
        category: 'morning',
        createdFrom: '2024-01-01T00:00:00.000Z',
        createdTo: '2024-06-01T00:00:00.000Z',
      ),
    );
    await timer.cancel();

    expect(ticks, greaterThan(0));
    expect(hits, isNotEmpty);
    expect(hits.length, lessThanOrEqualTo(10));
    final index = int.parse(hits.first.id.replaceFirst('bench-', ''));
    expect(index % 6, 0);
    expect(hits.first.similarity, greaterThan(0));
  });
}

double _medianWarmScan(String path, {required int mmapSize}) {
  final db = sql.sqlite3.open(path);
  try {
    DatabaseTuning.apply(db, mmapSize: mmapSize);
    _touchEmbeddings(db);
    _touchEmbeddings(db);
    final samples = <double>[];
    for (var i = 0; i < 7; i++) {
      final watch = Stopwatch()..start();
      final bytes = _touchEmbeddings(db);
      watch.stop();
      expect(bytes, greaterThan(0));
      samples.add(watch.elapsedMicroseconds / 1000);
    }
    db.execute('PRAGMA shrink_memory');
    samples.sort();
    return samples[samples.length ~/ 2];
  } finally {
    db.close();
  }
}

int _touchEmbeddings(sql.Database db) {
  var bytes = 0;
  final statement = db.prepare(
    'SELECT embedding FROM $benchmarkEntriesTable',
  );
  try {
    final cursor = statement.selectCursor();
    while (cursor.moveNext()) {
      bytes += (cursor.current['embedding'] as Uint8List).length;
    }
  } finally {
    statement.close();
  }
  return bytes;
}
