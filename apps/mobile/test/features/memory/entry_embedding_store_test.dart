import 'package:archiveme_mobile/features/memory/entry_embedding_store.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../storage/sqlite/support/configure_sqlite_test_ffi.dart';

void main() {
  setUpAll(configureSqliteTestFfi);

  JournalEntry entry(String id, String transcript) {
    return JournalEntry(
      id: id,
      createdAt: DateTime.utc(2026, 1, 2),
      transcript: transcript,
      durationSeconds: 4,
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

  test('a stored vector round-trips with its model version and time', () async {
    final db = await openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    final store = EntryEmbeddingStore(db);
    final createdAt = DateTime.utc(2026, 3, 4, 8);
    final vector = [
      for (var i = 0; i < EntryEmbeddingStore.dimensions; i++) i / 400,
    ];

    await store.writeVector(
      entryId: 'entry-1',
      vector: vector,
      createdAt: createdAt,
      modelVersion: EntryEmbeddingStore.miniLmModelVersion,
    );
    final stored = await store.read('entry-1');

    expect(stored, isNotNull);
    expect(stored!.entryId, 'entry-1');
    expect(stored.modelVersion, EntryEmbeddingStore.miniLmModelVersion);
    expect(stored.createdAt, createdAt);
    expect(stored.vector.length, vector.length);
    for (var i = 0; i < vector.length; i++) {
      expect(stored.vector[i], closeTo(vector[i], 1e-6));
    }
    expect(EntryEmbeddingStore.blobToVector(EntryEmbeddingStore.float32Blob(vector)).length, vector.length);
  });

  test('backfill stores 20 entries, then resumes after a cancel', () async {
    final db = await openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    var embedded = 0;
    final store = EntryEmbeddingStore(
      db,
      embedText: (text) async {
        embedded += 1;
        return EntryEmbeddingStore.localNgramEmbedding(text);
      },
    );
    final entries = [
      for (var i = 0; i < 25; i++) entry('entry-$i', 'Morning note $i by the river.'),
    ];
    var cancelled = false;

    final first = await store.embedMissing(
      entries,
      cancelled: () => cancelled,
    );
    expect(first, EntryEmbeddingStore.backfillBatchSize);

    cancelled = true;
    final stopped = await store.embedMissing(
      entries,
      cancelled: () => cancelled,
    );
    expect(stopped, 0);

    cancelled = false;
    final rest = await store.embedMissing(entries, cancelled: () => cancelled);
    expect(rest, 5);
    expect(embedded, 25);
    expect((await store.readAll()).length, 25);
  });
}
