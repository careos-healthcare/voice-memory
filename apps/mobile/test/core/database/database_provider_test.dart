import 'dart:typed_data';

import 'package:archiveme_mobile/core/database/database_provider.dart';
import 'package:archiveme_mobile/features/search/reflection_embedding_contract.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../storage/sqlite/support/configure_sqlite_test_ffi.dart';

void main() {
  setUpAll(configureSqliteTestFfi);

  test(
    'findSimilarEntries returns older cosine matches and skips recent ones',
    () async {
      final db = await openDatabase(inMemoryDatabasePath);
      addTearDown(db.close);
      await db.execute('''
      CREATE TABLE journal_entries (
        id TEXT PRIMARY KEY NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER,
        is_archived INTEGER NOT NULL DEFAULT 0,
        transcript TEXT NOT NULL DEFAULT '',
        has_verified_proof INTEGER NOT NULL DEFAULT 0,
        payload_json TEXT
      )
    ''');
      await db.execute('''
      CREATE TABLE reflection_embeddings (
        entry_id TEXT PRIMARY KEY NOT NULL,
        embedding BLOB NOT NULL,
        dimensions INTEGER NOT NULL,
        content_hash TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

      final now = DateTime.utc(2026, 9, 26);
      final old = now.subtract(const Duration(days: 30));
      final recent = now.subtract(const Duration(days: 2));
      final query = _basis(0);
      await _insert(
        db,
        id: 'older-match',
        at: old,
        transcript: 'I keep coming back to the river in the morning.',
        audioPath: '/tmp/river.m4a',
        vector: query,
      );
      await _insert(
        db,
        id: 'recent-match',
        at: recent,
        transcript: 'I keep coming back to the river today.',
        vector: query,
      );
      await _insert(
        db,
        id: 'unrelated',
        at: old,
        transcript: 'The invoice is still on the desk.',
        vector: _basis(1),
      );

      final matches = await DatabaseProvider(db).findSimilarEntries(
        query,
        now: now,
      );

      expect(matches.map((match) => match.id), ['older-match']);
      expect(matches.single.localAudioPath, '/tmp/river.m4a');
      expect(
        shortVerbatimQuote(matches.single.transcript),
        'I keep coming back to the river in the morning.',
      );
    },
  );

  test('a deleted entry stays as a tombstone for 90 days', () async {
    final db = await openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    final provider = DatabaseProvider(db);
    final now = DateTime.utc(2026, 9, 26, 8);

    await provider.recordTombstone(
      'recent',
      deletedAt: now.subtract(const Duration(days: 30)),
    );
    await provider.recordTombstone(
      'old',
      deletedAt: now.subtract(const Duration(days: 91)),
    );

    final recent = await provider.tombstoneFor('recent');
    expect(recent?.syncStatus, 'pendingUpload');
    expect(recent?.deletedAt, now.subtract(const Duration(days: 30)));

    final purged = await provider.purgeExpiredTombstones(
      now: now,
      retention: const Duration(days: 1),
    );

    expect(purged, 1);
    expect(await provider.tombstoneFor('recent'), isNotNull);
    expect(await provider.tombstoneFor('old'), isNull);
  });
}

List<double> _basis(int hot) {
  return List<double>.generate(
    ReflectionEmbeddingContract.dimensions,
    (index) => index == hot ? 1 : 0,
  );
}

Future<void> _insert(
  Database db, {
  required String id,
  required DateTime at,
  required String transcript,
  required List<double> vector,
  String? audioPath,
}) async {
  final millis = at.millisecondsSinceEpoch;
  await db.insert('journal_entries', {
    'id': id,
    'created_at': millis,
    'updated_at': millis,
    'transcript': transcript,
    'payload_json': audioPath == null
        ? null
        : '{"localAudioPath":"$audioPath"}',
  });
  final floats = Float32List.fromList(vector);
  await db.insert('reflection_embeddings', {
    'entry_id': id,
    'embedding': Uint8List.view(
      floats.buffer,
      floats.offsetInBytes,
      floats.lengthInBytes,
    ),
    'dimensions': vector.length,
    'content_hash': id,
    'updated_at': millis,
  });
}
