import 'dart:convert';

import 'package:archiveme_mobile/models/transcript_provenance.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_018_transcript_provenance.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_migration_registry.dart';
import 'package:archiveme_mobile/storage/sqlite/transcript_provenance_backfill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/sqlite_test_database.dart';

const _table = 'journal_entries';

Future<void> _insertRow(
  DatabaseExecutor db, {
  required String id,
  required int createdAt,
  Map<String, dynamic>? payload,
  String? rawPayload,
}) async {
  await db.insert(_table, {
    'id': id,
    'created_at': createdAt,
    'updated_at': createdAt,
    'deleted_at': null,
    'is_archived': 0,
    'transcript': 'stored transcript for $id',
    'has_verified_proof': 0,
    'payload_json': rawPayload ?? (payload == null ? null : jsonEncode(payload)),
  });
}

Future<String?> _payloadOf(DatabaseExecutor db, String id) async {
  final rows = await db.query(
    _table,
    columns: ['payload_json'],
    where: 'id = ?',
    whereArgs: [id],
  );
  return rows.single['payload_json'] as String?;
}

Future<Map<String, Object?>> _rowOf(DatabaseExecutor db, String id) async {
  final rows = await db.query(_table, where: 'id = ?', whereArgs: [id]);
  return rows.single;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(AppSqliteDatabase.resetForTest);

  test('018 is registered as the newest migration', () {
    final registry = SqliteMigrationRegistry();
    expect(registry.migrationForVersion(18), isA<Migration018TranscriptProvenance>());
    expect(SqliteMigrationRegistry.latestVersion, 18);
  });

  test('the schema step touches no journal rows', () async {
    final app = await openTestAppSqliteDatabase();
    final db = app.database;
    await _insertRow(db, id: 'a', createdAt: 1, payload: {'durationSeconds': 5});
    final before = await _rowOf(db, 'a');

    await Migration018TranscriptProvenance().up(db);

    expect(await _rowOf(db, 'a'), before);
  });

  test('stamps legacy payloads with the untrusted value', () async {
    final app = await openTestAppSqliteDatabase();
    final db = app.database;
    await _insertRow(db, id: 'a', createdAt: 1, payload: {'durationSeconds': 5});
    await _insertRow(db, id: 'b', createdAt: 2, payload: {'durationSeconds': 9});

    final stamped = await TranscriptProvenanceBackfill.run(db);

    expect(stamped, 2);
    for (final id in ['a', 'b']) {
      final payload = jsonDecode((await _payloadOf(db, id))!) as Map;
      expect(
        payload['transcriptProvenance'],
        TranscriptProvenance.unknownLegacy.storageValue,
      );
    }
  });

  test('leaves every other field in the payload alone', () async {
    final app = await openTestAppSqliteDatabase();
    final db = app.database;
    final original = {
      'durationSeconds': 42,
      'reflection': {'mood': 'tired', 'recurringThemes': ['work', 'rest']},
      'transcriptStatus': 'provisional',
      'revision': 7,
      'nested': {'deep': {'value': true}},
    };
    await _insertRow(db, id: 'a', createdAt: 1, payload: original);
    final rowBefore = await _rowOf(db, 'a');

    await TranscriptProvenanceBackfill.run(db);

    final payload =
        jsonDecode((await _payloadOf(db, 'a'))!) as Map<String, dynamic>;
    for (final key in original.keys) {
      expect(payload[key], original[key], reason: 'field $key must survive');
    }

    // Sync anchors must not move, or the backfill would look like a user edit
    // and would enqueue an upload for the entire archive.
    final rowAfter = await _rowOf(db, 'a');
    expect(rowAfter['updated_at'], rowBefore['updated_at']);
    expect(rowAfter['created_at'], rowBefore['created_at']);
    expect(rowAfter['transcript'], rowBefore['transcript']);
  });

  test('never overwrites a stamp that is already there', () async {
    final app = await openTestAppSqliteDatabase();
    final db = app.database;
    await _insertRow(db, id: 'spoken', createdAt: 1, payload: {
      'durationSeconds': 5,
      'transcriptProvenance': TranscriptProvenance.speechToText.storageValue,
    });
    await _insertRow(db, id: 'edited', createdAt: 2, payload: {
      'durationSeconds': 5,
      'transcriptProvenance': TranscriptProvenance.userEdited.storageValue,
    });

    final stamped = await TranscriptProvenanceBackfill.run(db);

    expect(stamped, 0);
    expect(
      (jsonDecode((await _payloadOf(db, 'spoken'))!) as Map)['transcriptProvenance'],
      TranscriptProvenance.speechToText.storageValue,
    );
    expect(
      (jsonDecode((await _payloadOf(db, 'edited'))!) as Map)['transcriptProvenance'],
      TranscriptProvenance.userEdited.storageValue,
    );
  });

  test('is idempotent — a second run writes nothing', () async {
    final app = await openTestAppSqliteDatabase();
    final db = app.database;
    for (var i = 0; i < 5; i++) {
      await _insertRow(db, id: 'e$i', createdAt: i, payload: {'durationSeconds': i});
    }

    expect(await TranscriptProvenanceBackfill.run(db), 5);
    final afterFirst = [
      for (var i = 0; i < 5; i++) await _payloadOf(db, 'e$i'),
    ];

    await TranscriptProvenanceBackfill.resetForTest(db);
    expect(await TranscriptProvenanceBackfill.run(db), 0);

    for (var i = 0; i < 5; i++) {
      expect(await _payloadOf(db, 'e$i'), afterFirst[i]);
    }
  });

  test('a run killed part-way resumes and finishes exactly once', () async {
    final app = await openTestAppSqliteDatabase();
    final db = app.database;
    for (var i = 0; i < 10; i++) {
      await _insertRow(db, id: 'e$i', createdAt: i, payload: {'durationSeconds': i});
    }

    // Stands in for the process dying after the first batch committed.
    final first = await TranscriptProvenanceBackfill.runBatch(db, batchSize: 3);
    expect(first.stamped, 3);
    expect(await TranscriptProvenanceBackfill.pendingCount(db), 7);
    expect(await TranscriptProvenanceBackfill.isPending(db), isTrue);

    // A fresh process starts over with no memory of the watermark.
    final resumed = await TranscriptProvenanceBackfill.run(db);

    expect(resumed, 7);
    expect(await TranscriptProvenanceBackfill.pendingCount(db), 0);
    expect(await TranscriptProvenanceBackfill.isPending(db), isFalse);
    for (var i = 0; i < 10; i++) {
      final payload = jsonDecode((await _payloadOf(db, 'e$i'))!) as Map;
      expect(
        payload['transcriptProvenance'],
        TranscriptProvenance.unknownLegacy.storageValue,
      );
      expect(payload['durationSeconds'], i);
    }
  });

  test('a capped run leaves the rest pending rather than claiming success',
      () async {
    final app = await openTestAppSqliteDatabase();
    final db = app.database;
    for (var i = 0; i < 8; i++) {
      await _insertRow(db, id: 'e$i', createdAt: i, payload: {'durationSeconds': i});
    }

    final stamped =
        await TranscriptProvenanceBackfill.run(db, batchSize: 2, maxBatches: 2);

    expect(stamped, 4);
    expect(await TranscriptProvenanceBackfill.isPending(db), isTrue);
    expect(await TranscriptProvenanceBackfill.pendingCount(db), 4);
  });

  test('rows the stamp cannot be written to do not stall the pass', () async {
    final app = await openTestAppSqliteDatabase();
    final db = app.database;
    await _insertRow(db, id: 'null-payload', createdAt: 1);
    await _insertRow(db, id: 'empty-payload', createdAt: 2, rawPayload: '');
    await _insertRow(db, id: 'corrupt', createdAt: 3, rawPayload: '{not json');
    await _insertRow(db, id: 'good', createdAt: 4, payload: {'durationSeconds': 5});

    // Terminates rather than looping forever on rows json_set cannot rewrite,
    // and a malformed payload does not abort the statement for the good rows.
    final stamped = await TranscriptProvenanceBackfill.run(db);

    expect(stamped, 1);
    expect(await TranscriptProvenanceBackfill.isPending(db), isFalse);
    expect(await _payloadOf(db, 'null-payload'), isNull);
    expect(await _payloadOf(db, 'corrupt'), '{not json');
    expect(
      (jsonDecode((await _payloadOf(db, 'good'))!) as Map)['transcriptProvenance'],
      TranscriptProvenance.unknownLegacy.storageValue,
    );
  });

  test('an archive larger than one pass finishes across passes', () async {
    final app = await openTestAppSqliteDatabase();
    final db = app.database;
    const total = 250;
    await db.transaction((txn) async {
      for (var i = 0; i < total; i++) {
        await _insertRow(txn, id: 'e$i', createdAt: i, payload: {'durationSeconds': i});
      }
    });

    var stamped = 0;
    // Each call stands for one app launch with a deliberately small budget.
    while (await TranscriptProvenanceBackfill.isPending(db)) {
      stamped +=
          await TranscriptProvenanceBackfill.run(db, batchSize: 25, maxBatches: 2);
    }

    expect(stamped, total);
    expect(await TranscriptProvenanceBackfill.pendingCount(db), 0);
  });
}
