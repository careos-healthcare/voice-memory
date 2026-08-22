import 'package:drift/drift.dart';

/// Drift mirror of the `sync_outbox` SQLite table (offline-first push queue).
@DataClassName('SyncOutboxRow')
class SyncOutboxEntries extends Table {
  @override
  String get tableName => 'sync_outbox';

  TextColumn get outboxId => text().named('outbox_id')();
  TextColumn get blobId => text().named('blob_id')();
  TextColumn get blobType => text().named('blob_type')();
  TextColumn get payloadJson => text().named('payload_json')();
  TextColumn get status => text()();
  IntColumn get attemptCount => integer().named('attempt_count')();
  TextColumn get lastError => text().named('last_error').nullable()();
  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get updatedAt => integer().named('updated_at')();
  IntColumn get nextRetryAt => integer().named('next_retry_at').nullable()();

  @override
  Set<Column<Object>> get primaryKey => {outboxId};
}
