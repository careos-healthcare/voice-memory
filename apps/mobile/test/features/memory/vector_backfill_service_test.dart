import 'dart:typed_data';

import 'package:archiveme_mobile/features/memory/services/embedding_service.dart';
import 'package:archiveme_mobile/features/memory/services/local_vector_db.dart';
import 'package:archiveme_mobile/features/memory/services/vector_backfill_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../storage/sqlite/support/configure_sqlite_test_ffi.dart';

void main() {
  setUpAll(configureSqliteTestFfi);

  const vocab = '[PAD]\n[UNK]\n[CLS]\n[SEP]\nthe\nriver\n';

  List<double> vector(double fill) {
    return List<double>.filled(LocalVectorDb.dimensions, fill);
  }

  JournalEntry entry(String id, String transcript, {int seconds = 10}) {
    return JournalEntry(
      id: id,
      createdAt: DateTime.utc(2026, 1, 2),
      transcript: transcript,
      durationSeconds: seconds,
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 0,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
    );
  }

  test('backfill stores chunks from an isolate and delete clears them', () async {
    final db = await openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    final vectors = LocalVectorDb(db);
    final service = VectorBackfillService(
      db: vectors,
      loadVocab: () async => vocab,
      embed: (encoding) async {
        expect(encoding.inputIds.first, 2);
        expect(encoding.inputIds.last, 3);
        return vector(0.1);
      },
    );

    final stored = await service.backfillEntries([
      entry('river', 'The river was high. The river fell.'),
    ]);
    expect(stored, 2);
    final rows = await vectors.readEntry('river');
    expect(rows, hasLength(2));
    expect(rows.first.startTimeMs, 0);
    expect(rows.last.startTimeMs, greaterThan(0));
    expect(rows.first.modelVersion, LocalVectorDb.modelVersion);

    await vectors.deleteEntry('river');
    final left = await db.rawQuery(
      'SELECT entry_id FROM entry_vectors WHERE entry_id = ?',
      ['river'],
    );
    expect(left, isEmpty);
  });

  test('a different model version or width is not compared', () async {
    final db = await openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    final vectors = LocalVectorDb(db);
    await vectors.ensure();
    await db.insert('entry_vectors', {
      'entry_id': 'old',
      'chunk_index': 0,
      'vector': Uint8List(8),
      'dimensions': 2,
      'model_version': 'local-ngram-v1',
      'start_time_ms': 40,
    });
    await vectors.purgeIncompatible();
    final left = await db.query('entry_vectors');
    expect(left, isEmpty);

    expect(
      LocalVectorDb.cosine(vector(1), StoredVector(
        entryId: 'other',
        chunkIndex: 0,
        vector: const [1, 0],
        modelVersion: LocalVectorDb.modelVersion,
        startTimeMs: 0,
      )),
      isNull,
    );
    expect(
      LocalVectorDb.cosine(vector(1), StoredVector(
        entryId: 'other',
        chunkIndex: 0,
        vector: vector(1),
        modelVersion: 'other-model',
        startTimeMs: 12,
      )),
      isNull,
    );
  });
}
