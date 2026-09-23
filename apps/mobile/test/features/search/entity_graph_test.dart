import 'dart:io';

import 'package:archiveme_mobile/features/search/entity_extraction_worker.dart';
import 'package:archiveme_mobile/features/search/vec_search_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('extracts entities and grows relationship weight', () async {
    final db = await _openGraph();
    const worker = EntityExtractionWorker();
    const transcript =
        'Met Ada at Harbor. I want to walk more when evenings get quiet.';

    final first = await worker.processEntry(
      db: db,
      entryId: 'moment-1',
      transcript: transcript,
      seenAt: DateTime.utc(2026, 9),
    );
    expect(first.entityIds, contains('people:ada'));
    expect(first.entityIds, contains('locations:harbor'));
    expect(first.entityIds, contains('goals:walk-more'));
    expect(first.entityIds, contains('triggers:evenings-get-quiet'));

    await worker.processEntry(
      db: db,
      entryId: 'moment-2',
      transcript: 'Met Ada at Harbor again.',
      seenAt: DateTime.utc(2026, 9, 2),
    );

    final seenAt = await db.query(
      'relationships',
      where: 'relation_type = ?',
      whereArgs: ['seen_at'],
    );
    expect(seenAt.single['weight'], 2.0);
    expect(seenAt.single['source_id'], 'people:ada');
    expect(seenAt.single['target_id'], 'locations:harbor');

    final ada = await db.query(
      'entities',
      where: 'id = ?',
      whereArgs: ['people:ada'],
    );
    expect(
      ada.single['created_at'],
      DateTime.utc(2026, 9).millisecondsSinceEpoch,
    );
    await db.close();
  });

  test('hybrid search blends vector distance with graph neighbors', () async {
    final db = await _openGraph();
    await db.insert('entities', {
      'id': 'people:ada',
      'name': 'Ada',
      'category': 'people',
      'description': 'Ada',
      'created_at': 1,
    });
    await db.insert('entities', {
      'id': 'locations:harbor',
      'name': 'Harbor',
      'category': 'locations',
      'description': 'Harbor',
      'created_at': 1,
    });
    await db.insert('relationships', {
      'id': 'seen_at:people:ada:locations:harbor',
      'source_id': 'people:ada',
      'target_id': 'locations:harbor',
      'relation_type': 'seen_at',
      'weight': 3.0,
      'last_seen': 2,
    });
    await db.insert('entry_entities', {
      'entry_id': 'moment-a',
      'entity_id': 'people:ada',
    });
    await db.insert('entry_entities', {
      'entry_id': 'moment-b',
      'entity_id': 'locations:harbor',
    });

    final hits = await VecSearchService(
      loadDistances: (db, query, limit) async => const [
        VecDistanceHit(entryId: 'moment-a', distance: 1),
        VecDistanceHit(entryId: 'moment-b', distance: 0.25),
      ],
    ).search(
      db: db,
      queryEmbedding: const [0.1, 0.2],
      entityIds: const ['people:ada'],
    );

    expect(hits.map((hit) => hit.entryId).toList(), ['moment-b', 'moment-a']);
    expect(hits.first.vectorDistance, 0.25);
    expect(hits.first.graphWeight, 1.5);
    expect(hits.last.graphWeight, 1);
    await db.close();
  });
}

Future<Database> _openGraph() async {
  final file = File(
    '${Directory.systemTemp.path}/entity-graph-${DateTime.now().microsecondsSinceEpoch}.db',
  );
  final db = await databaseFactory.openDatabase(file.path);
  final sql = File('lib/core/database/schema.sql').readAsStringSync();
  for (final statement in sql.split(';')) {
    final trimmed = statement.trim();
    if (trimmed.isEmpty) continue;
    await db.execute(trimmed);
  }
  return db;
}
