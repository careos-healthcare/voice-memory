import 'package:archiveme_mobile/database/tables/journal_entries.dart';
import 'package:drift/drift.dart';

/// Reflection knowledge-graph nodes (`reflection_graph_nodes`).
@TableIndex(name: 'idx_reflection_graph_nodes_entry_id', columns: {#entryId})
@TableIndex(name: 'idx_reflection_graph_nodes_kind', columns: {#kind})
@DataClassName('ReflectionGraphNodeRow')
class ReflectionGraphNodes extends Table {
  @override
  String get tableName => 'reflection_graph_nodes';

  TextColumn get id => text()();
  TextColumn get entryId =>
      text().named('entry_id').references(JournalEntries, #id)();
  TextColumn get kind => text()();
  TextColumn get label => text()();
  TextColumn get payloadJson => text().named('payload_json').nullable()();
  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Key/value metadata for graph backfill (`app_sqlite_meta`).
@DataClassName('AppSqliteMetaRow')
class AppSqliteMeta extends Table {
  @override
  String get tableName => 'app_sqlite_meta';

  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
