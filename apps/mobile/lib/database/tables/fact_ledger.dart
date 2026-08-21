import 'package:drift/drift.dart';

/// Local SQLite mirror of user citable facts (`fact_ledger`).
@TableIndex(name: 'idx_fact_ledger_source_entry', columns: {#sourceEntryId})
@TableIndex(name: 'idx_fact_ledger_updated_at', columns: {#updatedAt})
@DataClassName('FactLedgerRow')
class FactLedgerEntries extends Table {
  @override
  String get tableName => 'fact_ledger';

  TextColumn get id => text()();
  TextColumn get sourceEntryId => text().named('source_entry_id')();
  TextColumn get label => text()();
  TextColumn get value => text()();
  TextColumn get note => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get updatedAt => integer().named('updated_at')();
  TextColumn get factType => text().named('fact_type')();
  TextColumn get archivePackId => text().named('archive_pack_id').nullable()();
  TextColumn get archiveThreadId => text().named('archive_thread_id').nullable()();
  TextColumn get collectionIdsJson =>
      text().named('collection_ids_json').withDefault(const Constant('[]'))();
  IntColumn get isPinned => integer().named('is_pinned').withDefault(const Constant(0))();
  IntColumn get preserveOriginal =>
      integer().named('preserve_original').withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
