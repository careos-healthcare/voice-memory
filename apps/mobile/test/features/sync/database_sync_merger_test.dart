import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/features/sample_vault/sample_vault_embedder.dart';
import 'package:archiveme_mobile/features/sync/database_sync_merger.dart';
import 'package:archiveme_mobile/features/sync/mesh_asset_reconciler.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_020_entity_graph.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_026_habits.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_027_sync_changelog.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_database_initializer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../storage/sqlite/support/sqlite_test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mesh merge keeps newer rows and adds relationship weights', () async {
    expect(V1CapabilityRegistry.p2pAndWebRtc, isFalse);
    final root = await Directory.systemTemp.createTemp('mesh-merge');
    final left = await SqliteDatabaseInitializer.open(
      filePath: '${root.path}/left.db',
      passwordOverride: testSqliteEncryptionPassword,
      runDeferredBackfill: false,
      scheduleVectorExtensions: false,
    );
    final right = await SqliteDatabaseInitializer.open(
      filePath: '${root.path}/right.db',
      passwordOverride: testSqliteEncryptionPassword,
      runDeferredBackfill: false,
      scheduleVectorExtensions: false,
    );
    addTearDown(() async {
      await left.close();
      await right.close();
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    final phoneA = DatabaseSyncMerger(database: left, deviceId: 'phone-a');
    final phoneB = DatabaseSyncMerger(database: right, deviceId: 'phone-b');
    const entryId = 'moment-1';
    const habitId = 'habit-run';
    const logId = 'log-1';
    const edgeId = 'seen_at:people:ada:locations:banstead';
    final morning = DateTime.utc(2026, 9, 23, 8);
    final noon = DateTime.utc(2026, 9, 23, 12);
    final evening = DateTime.utc(2026, 9, 23, 18);
    final embedding = SampleVaultEmbedder.toBlob(
      SampleVaultEmbedder.embed('Met Ada in Banstead'),
    );

    await phoneA.recordChange(
      entityTable: 'journal_entries',
      recordId: entryId,
      updatedAt: morning,
      row: _journal('Met Ada locally', morning),
    );
    await phoneB.recordChange(
      entityTable: 'journal_entries',
      recordId: entryId,
      updatedAt: noon,
      row: {
        ..._journal('Met Ada in Banstead', noon),
        'embedding': embedding,
      },
    );
    await phoneA.recordChange(
      entityTable: Migration026Habits.habitsTable,
      recordId: habitId,
      updatedAt: morning,
      row: {
        'title': 'Morning miles',
        'frequency': 'daily',
        'target_count': 1,
        'created_at': morning.millisecondsSinceEpoch,
      },
    );
    await phoneB.recordChange(
      entityTable: Migration026Habits.habitsTable,
      recordId: habitId,
      updatedAt: noon,
      row: {
        'title': '5km run',
        'frequency': 'daily',
        'target_count': 1,
        'created_at': morning.millisecondsSinceEpoch,
      },
    );
    await phoneA.recordChange(
      entityTable: Migration026Habits.logsTable,
      recordId: logId,
      updatedAt: morning,
      row: {
        'habit_id': habitId,
        'entry_id': entryId,
        'logged_at': morning.millisecondsSinceEpoch,
      },
    );
    await phoneB.recordChange(
      entityTable: Migration026Habits.logsTable,
      recordId: logId,
      updatedAt: evening,
      row: {
        'habit_id': habitId,
        'entry_id': entryId,
        'logged_at': evening.millisecondsSinceEpoch,
      },
    );
    await phoneA.recordChange(
      entityTable: Migration020EntityGraph.entitiesTable,
      recordId: 'people:ada',
      updatedAt: morning,
      row: {
        'name': 'Ada',
        'category': 'people',
        'description': 'Ada',
        'created_at': morning.millisecondsSinceEpoch,
      },
    );
    await phoneB.recordChange(
      entityTable: Migration020EntityGraph.entitiesTable,
      recordId: 'locations:banstead',
      updatedAt: noon,
      row: {
        'name': 'Banstead',
        'category': 'locations',
        'description': 'Banstead',
        'created_at': noon.millisecondsSinceEpoch,
      },
    );
    await phoneA.recordChange(
      entityTable: Migration020EntityGraph.relationshipsTable,
      recordId: edgeId,
      updatedAt: morning,
      row: _edge(weight: 2, seen: morning),
    );
    await phoneB.recordChange(
      entityTable: Migration020EntityGraph.relationshipsTable,
      recordId: edgeId,
      updatedAt: noon,
      row: _edge(weight: 3, seen: noon),
    );

    final first = await phoneA.merge(await phoneB.exportChanges());
    expect(first.applied, greaterThan(0));
    expect(first.mergedEntryIds, [entryId]);
    expect(first.vectorHits.single.id, entryId);
    expect(first.vectorHits.single.score, closeTo(1, 0.001));

    final journal = await left.query(
      'journal_entries',
      where: 'id = ?',
      whereArgs: [entryId],
    );
    expect(journal.single['transcript'], 'Met Ada in Banstead');
    final habit = await left.query(
      Migration026Habits.habitsTable,
      where: 'id = ?',
      whereArgs: [habitId],
    );
    expect(habit.single['title'], '5km run');
    final log = await left.query(
      Migration026Habits.logsTable,
      where: 'id = ?',
      whereArgs: [logId],
    );
    expect(log.single['logged_at'], evening.millisecondsSinceEpoch);
    final people = await left.query(
      Migration020EntityGraph.entitiesTable,
      columns: ['name'],
      orderBy: 'name ASC',
    );
    expect(
      [for (final row in people) row['name']],
      ['Ada', 'Banstead'],
    );
    expect(await _edgeWeight(left, edgeId), 5);

    final replay = await phoneA.merge(await phoneB.exportChanges());
    expect(replay.applied, 0);
    expect(await _edgeWeight(left, edgeId), 5);

    await phoneB.recordChange(
      entityTable: Migration020EntityGraph.relationshipsTable,
      recordId: edgeId,
      updatedAt: evening,
      row: _edge(weight: 4, seen: evening),
    );
    await phoneA.merge(await phoneB.exportChanges());
    expect(await _edgeWeight(left, edgeId), 6);

    final stale = await phoneA.merge([
      SyncChangelogEntry(
        entityTable: 'journal_entries',
        recordId: entryId,
        updatedAt: DateTime.utc(2026, 9, 22),
        deviceId: 'phone-b',
        row: _journal('older note', DateTime.utc(2026, 9, 22)),
      ),
    ]);
    expect(stale.keptLocal, 1);
    final still = await left.query(
      'journal_entries',
      columns: ['transcript'],
      where: 'id = ?',
      whereArgs: [entryId],
    );
    expect(still.single['transcript'], 'Met Ada in Banstead');

    final tied = await phoneA.merge([
      SyncChangelogEntry(
        entityTable: 'journal_entries',
        recordId: entryId,
        updatedAt: noon,
        deviceId: 'phone-c',
        row: _journal('Tied note', noon),
      ),
    ]);
    expect(tied.applied, 1);
    final tiedRow = await left.query(
      'journal_entries',
      columns: ['transcript'],
      where: 'id = ?',
      whereArgs: [entryId],
    );
    expect(tiedRow.single['transcript'], 'Tied note');

    final logged = await left.query(
      Migration027SyncChangelog.changelogTable,
      where: 'entity_table = ? AND record_id = ?',
      whereArgs: ['journal_entries', entryId],
    );
    expect(
      logged.map((row) => row['device_id']),
      containsAll(['phone-a', 'phone-b', 'phone-c']),
    );
    final ownEdge = await phoneA.exportChanges();
    final exported = ownEdge.singleWhere(
      (change) => change.recordId == edgeId,
    );
    expect(exported.row['weight'], 2);
  });

  test('peers stream missing audio and image bytes in chunks', () async {
    final root = await Directory.systemTemp.createTemp('mesh-assets');
    addTearDown(() async {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    final wav = Uint8List.fromList(const [1, 2, 3, 4, 5, 6, 7]);
    final png = Uint8List.fromList(const [9, 8, 7, 6, 5]);
    await File('${root.path}/keep.wav').writeAsBytes(wav);
    final reconciler = const MeshAssetReconciler(chunkSize: 3);
    final remote = [
      const MeshAssetManifestEntry(
        assetId: 'keep',
        fileName: 'keep.wav',
        byteLength: 7,
      ),
      MeshAssetManifestEntry(
        assetId: 'clip',
        fileName: 'wrist.m4a',
        byteLength: wav.length,
      ),
      MeshAssetManifestEntry(
        assetId: 'scan',
        fileName: 'page.png',
        byteLength: png.length,
      ),
      const MeshAssetManifestEntry(
        assetId: 'notes',
        fileName: 'notes.txt',
        byteLength: 4,
      ),
      const MeshAssetManifestEntry(
        assetId: 'escape',
        fileName: '../secret.wav',
        byteLength: 4,
      ),
    ];
    final missing = reconciler.missing(
      remote: remote,
      localAssetIds: {'keep'},
    );
    expect(missing.map((entry) => entry.fileName), ['wrist.m4a', 'page.png']);

    final destination = Directory('${root.path}/inbox');
    final written = await reconciler.pullMissing(
      destination: destination,
      remote: remote,
      localAssetIds: {'keep'},
      open: (entry) {
        final bytes = entry.assetId == 'clip' ? wav : png;
        return reconciler.streamBytes(assetId: entry.assetId, bytes: bytes);
      },
    );
    expect(written, hasLength(2));
    expect(await written[0].readAsBytes(), wav);
    expect(await written[1].readAsBytes(), png);

    final streamed = await reconciler
        .streamFile(written[0], assetId: 'clip')
        .toList();
    expect(streamed.length, greaterThan(1));
    expect(reconciler.assemble(streamed), wav);
  });
}

Map<String, Object?> _journal(String transcript, DateTime when) {
  final millis = when.millisecondsSinceEpoch;
  return {
    'created_at': millis,
    'updated_at': millis,
    'is_archived': 0,
    'transcript': transcript,
    'has_verified_proof': 0,
    'payload_json': '{}',
  };
}

Map<String, Object?> _edge({required num weight, required DateTime seen}) {
  return {
    'source_id': 'people:ada',
    'target_id': 'locations:banstead',
    'relation_type': 'seen_at',
    'weight': weight,
    'last_seen': seen.millisecondsSinceEpoch,
  };
}

Future<double> _edgeWeight(DatabaseExecutor database, String id) async {
  final rows = await database.query(
    Migration020EntityGraph.relationshipsTable,
    columns: ['weight'],
    where: 'id = ?',
    whereArgs: [id],
  );
  return (rows.single['weight'] as num).toDouble();
}
