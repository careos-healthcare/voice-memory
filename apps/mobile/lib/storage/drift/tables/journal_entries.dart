import 'package:drift/drift.dart';

/// Drift table matching the production `journal_entries` SQLite schema.
@DataClassName('JournalEntryRow')
class JournalEntries extends Table {
  @override
  String get tableName => 'journal_entries';

  TextColumn get id => text()();
  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get updatedAt => integer().named('updated_at')();
  IntColumn get deletedAt => integer().named('deleted_at').nullable()();
  IntColumn get isArchived => integer().named('is_archived')();
  TextColumn get transcript => text()();
  IntColumn get hasVerifiedProof => integer().named('has_verified_proof')();
  TextColumn get payloadJson => text().named('payload_json').nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
