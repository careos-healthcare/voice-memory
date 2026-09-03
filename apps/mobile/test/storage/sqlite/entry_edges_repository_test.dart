import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/entry_edges_repository.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_013_entry_edges.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../storage/sqlite/support/sqlite_test_database.dart';

Future<void> _insertEdge(
  AppSqliteDatabase db, {
  required String sourceEntryId,
  required String targetEntryId,
  required double weight,
  String relation = Migration013EntryEdges.relationSemanticSimilarity,
  int createdAt = 1700000000000,
}) {
  return db.database.insert(Migration013EntryEdges.edgesTable, {
    'source_entry_id': sourceEntryId,
    'target_entry_id': targetEntryId,
    'relation': relation,
    'weight': weight,
    'created_at': createdAt,
  });
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(AppSqliteDatabase.resetForTest);

  test('readOutgoingEdges returns edges for the given source, ordered by weight descending', () async {
    final db = await openTestAppSqliteDatabase();
    final repository = EntryEdgesRepository(db);

    await _insertEdge(db, sourceEntryId: 'a', targetEntryId: 'b', weight: 0.3);
    await _insertEdge(db, sourceEntryId: 'a', targetEntryId: 'c', weight: 0.9);
    await _insertEdge(db, sourceEntryId: 'a', targetEntryId: 'd', weight: 0.6);

    final edges = await repository.readOutgoingEdges('a');

    expect(edges.map((e) => e.targetEntryId).toList(), ['c', 'd', 'b']);
    expect(edges.every((e) => e.sourceEntryId == 'a'), isTrue);
  });

  test('readOutgoingEdges only returns edges where the entry is the source, not the target', () async {
    final db = await openTestAppSqliteDatabase();
    final repository = EntryEdgesRepository(db);

    await _insertEdge(db, sourceEntryId: 'a', targetEntryId: 'b', weight: 0.5);
    // 'a' is the target here, not the source — should not appear for readOutgoingEdges('a').
    await _insertEdge(db, sourceEntryId: 'z', targetEntryId: 'a', weight: 0.8);

    final edges = await repository.readOutgoingEdges('a');

    expect(edges.length, 1);
    expect(edges.single.targetEntryId, 'b');
  });

  test('readOutgoingEdges returns an empty list for an entry with no edges', () async {
    final db = await openTestAppSqliteDatabase();
    final repository = EntryEdgesRepository(db);

    final edges = await repository.readOutgoingEdges('lonely-entry');

    expect(edges, isEmpty);
  });

  test('readOutgoingEdges returns an empty list for an empty source id', () async {
    final db = await openTestAppSqliteDatabase();
    final repository = EntryEdgesRepository(db);

    final edges = await repository.readOutgoingEdges('');

    expect(edges, isEmpty);
  });
}
