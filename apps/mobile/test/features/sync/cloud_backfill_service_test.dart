import 'package:archiveme_mobile/core/database/database_provider.dart';
import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/features/settings/services/cloud_data_service.dart';
import 'package:archiveme_mobile/features/sync/services/cloud_backfill_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import '../../storage/sqlite/support/configure_sqlite_test_ffi.dart';

void main() {
  setUpAll(configureSqliteTestFfi);

  JournalEntry entry(String id) {
    return JournalEntry(
      id: id,
      createdAt: DateTime.utc(2026, 4, 1),
      transcript: 'the river was high',
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

  test('a failed upload leaves the cursor and last entry id alone', () async {
    var cursor = 4;
    String? lastId;
    final service = CloudBackfillService(
      postChunk: (_) async => const ApiFailureResult(ApiFailureOffline()),
      writeCursor: (value) async => cursor = value,
      writeLastEntryId: (id) async => lastId = id,
    );

    await expectLater(
      service.acceptChunk(chunk: [entry('river')], nextCursor: 5),
      throwsA(isA<CloudUploadException>()),
    );
    expect(cursor, 4);
    expect(lastId, isNull);
  });

  test('dirty rows upload before the sequential cursor moves', () async {
    var cursor = 2;
    final cleared = <String>[];
    final service = CloudBackfillService(
      loadDirtyEntries: () async => [
        DirtyJournalRow(
          id: 'edited',
          createdAt: DateTime.utc(2026, 4, 2),
          transcript: 'changed while offline',
          deleted: false,
        ),
      ],
      loadDirtyTombstones: () async => const ['removed'],
      postDirty: (_) async => ApiSuccess(http.Response('{"ok":true}', 200)),
      deleteDirty: (_) async => ApiSuccess(http.Response('{"ok":true}', 200)),
      clearEntryDirty: (id) async {
        cleared.add(id);
      },
      clearTombstoneDirty: (id) async {
        cleared.add(id);
      },
      writeCursor: (value) async => cursor = value,
      writeLastEntryId: (_) async {},
      writeTimestamp: (_) async {},
    );

    await service.flushDirty();
    expect(cleared, ['edited', 'removed']);
    expect(cursor, 2);
  });

  test('deleting the cloud copy resets the cursor only after success', () async {
    var cursor = '12';
    String? timestamp = '2026-04-01T00:00:00.000Z';
    final failed = CloudDataService(
      sendDelete: () async => ApiSuccess(http.Response('no', 500)),
      resetLocal: () async {
        cursor = '0';
        timestamp = null;
      },
    );
    expect(await failed.deleteCloudCopy(), isFalse);
    expect(cursor, '12');
    expect(timestamp, isNotNull);

    final deleted = CloudDataService(
      sendDelete: () async => ApiSuccess(http.Response('{"ok":true}', 200)),
      resetLocal: () async {
        cursor = '0';
        timestamp = null;
      },
    );
    expect(await deleted.deleteCloudCopy(), isTrue);
    expect(cursor, '0');
    expect(timestamp, isNull);
  });

  test('creates, edits, and deletes stay dirty while cloud is off', () async {
    final db = await openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    final provider = DatabaseProvider(db);
    final when = DateTime.utc(2026, 4, 3);

    await provider.markEntryDirty(
      id: 'note',
      createdAt: when,
      updatedAt: when,
      transcript: 'written offline',
    );
    await provider.recordTombstone('note', deletedAt: when);

    final dirty = await provider.dirtyEntries();
    expect(dirty.single.id, 'note');
    expect(await provider.dirtyTombstoneIds(), ['note']);

    await provider.clearEntryDirty('note');
    await provider.clearTombstoneDirty('note');
    expect(await provider.dirtyEntries(), isEmpty);
    expect(await provider.dirtyTombstoneIds(), isEmpty);
  });
}
