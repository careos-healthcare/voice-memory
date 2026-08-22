import 'package:drift/drift.dart';

/// Automated semantic edges between journal entries (`entry_edges`).
@TableIndex(name: 'idx_entry_edges_source', columns: {#sourceEntryId})
@TableIndex(name: 'idx_entry_edges_target', columns: {#targetEntryId})
@DataClassName('EntryEdgeRow')
class EntryEdges extends Table {
  @override
  String get tableName => 'entry_edges';

  TextColumn get sourceEntryId => text().named('source_entry_id')();
  TextColumn get targetEntryId => text().named('target_entry_id')();
  TextColumn get relation => text().withDefault(const Constant('semantic_similarity'))();
  RealColumn get weight => real()();
  IntColumn get createdAt => integer().named('created_at')();

  @override
  Set<Column<Object>> get primaryKey => {sourceEntryId, targetEntryId};
}
