import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/core/database/benchmark_seeder_isolate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import 'vector_seeder.dart';

void main() {
  test('synthetic vectors are unit length and reuse one buffer', () {
    final seeder = VectorSeeder();
    final shared = seeder.buffer.values;
    final first = seeder.row(0);
    final firstCopy = seeder.copyCurrent();
    final second = seeder.row(1);

    expect(identical(seeder.buffer.values, shared), isTrue);
    expect(benchmarkVectorNorm(firstCopy), closeTo(1, 1e-3));
    expect(benchmarkVectorNorm(seeder.buffer.values), closeTo(1, 1e-3));
    expect(firstCopy, isNot(equals(seeder.buffer.values)));
    expect(first.id, 'bench-0');
    expect(first.category, 'morning');
    expect(DateTime.parse(first.createdAt).toUtc().year, 2024);
    final ambient = jsonDecode(first.ambientJson) as Map<String, dynamic>;
    expect(ambient['locality'], isNotEmpty);
    expect(ambient['weatherLabel'], isNotEmpty);
    expect(ambient['stepCount'], isA<int>());
    expect(second.title, contains('2'));

    var visits = 0;
    seeder.generate(4, (index, payload) {
      visits += 1;
      expect(payload.id, 'bench-$index');
      expect(identical(seeder.buffer.values, shared), isTrue);
    });
    expect(visits, 4);
    expect(seeder.buffer.values.every((value) => value == 0), isTrue);
  });

  test('a short batch commits a remainder without a new vector buffer', () {
    final directory = Directory.systemTemp.createTempSync('vector-seed-small');
    addTearDown(() => directory.deleteSync(recursive: true));
    final path = '${directory.path}/bench.db';

    final report = insertBenchmarkEntries(
      BenchmarkSeedRequest(
        databasePath: path,
        entryCount: 5,
        batchSize: 2,
      ),
    );

    expect(report.inserted, 5);
    expect(report.batches, 3);
    expect(report.recordsPerSecond, greaterThan(0));
    final db = sql.sqlite3.open(path);
    try {
      final count = db.select(
        'SELECT COUNT(*) AS n FROM $benchmarkEntriesTable',
      );
      expect(count.first['n'], 5);
      final row = db.select(
        'SELECT embedding, ambient_json FROM $benchmarkEntriesTable WHERE id = ?',
        ['bench-4'],
      );
      final blob = row.first['embedding'] as Uint8List;
      expect(blob.length, benchmarkEmbeddingDimensions * 4);
      final ambient = jsonDecode(row.first['ambient_json'] as String);
      expect(ambient, isA<Map<String, dynamic>>());
    } finally {
      db.close();
    }
  });

  test(
    'seeding 10000 entries stays on a background isolate',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'vector-seed-10k',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/bench.db';
      var ticks = 0;
      final timer = Stream<void>.periodic(
        const Duration(milliseconds: 4),
      ).listen((_) {
        ticks += 1;
      });

      final report = await BenchmarkSeederIsolate.seed(
        BenchmarkSeedRequest(databasePath: path, entryCount: 10000),
      );
      await timer.cancel();

      expect(ticks, greaterThan(0));
      expect(report.inserted, 10000);
      expect(report.batches, 10);
      expect(report.batchSize, benchmarkSeedBatchSize);
      expect(report.elapsedMilliseconds, greaterThanOrEqualTo(0));
      expect(report.recordsPerSecond, greaterThan(0));

      final db = sql.sqlite3.open(path);
      try {
        final count = db.select(
          'SELECT COUNT(*) AS n FROM $benchmarkEntriesTable',
        );
        expect(count.first['n'], 10000);
        final blob =
            db.select(
                  'SELECT embedding FROM $benchmarkEntriesTable WHERE id = ?',
                  ['bench-0'],
                ).first['embedding']
                as Uint8List;
        expect(blob.lengthInBytes, benchmarkEmbeddingDimensions * 4);
        final floats = Float32List.view(blob.buffer, blob.offsetInBytes);
        expect(benchmarkVectorNorm(floats), closeTo(1, 1e-3));
      } finally {
        db.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
