import 'package:drift/drift.dart';

@DataClassName('QuickCaptureOutboxRow')
class QuickCaptureOutboxEntries extends Table {
  @override
  String get tableName => 'quick_capture_outbox';

  TextColumn get outboxId => text().named('outbox_id')();
  TextColumn get captureId => text().named('capture_id')();
  TextColumn get kind => text()();
  TextColumn get payloadJson => text().named('payload_json')();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get attemptCount => integer().named('attempt_count').withDefault(const Constant(0))();
  TextColumn get lastError => text().named('last_error').nullable()();
  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  Set<Column<Object>> get primaryKey => {outboxId};
}

@TableIndex(name: 'idx_embedding_deferred_queue_created', columns: {#createdAt})
@DataClassName('EmbeddingDeferredQueueRow')
class EmbeddingDeferredQueueEntries extends Table {
  @override
  String get tableName => 'embedding_deferred_queue';

  TextColumn get queueId => text().named('queue_id')();
  TextColumn get operation => text()();
  TextColumn get entryId => text().named('entry_id')();
  TextColumn get bodyText => text().named('text')();
  TextColumn get contentHash => text().named('content_hash').nullable()();
  TextColumn get sqliteFilePath => text().named('sqlite_file_path')();
  TextColumn get keyAlias => text().named('key_alias').nullable()();
  TextColumn get encryptionPassword =>
      text().named('encryption_password').nullable()();
  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  Set<Column<Object>> get primaryKey => {queueId};
}

@DataClassName('AudioProcessingQueueRow')
class AudioProcessingQueueEntries extends Table {
  @override
  String get tableName => 'audio_processing_queue';

  TextColumn get id => text()();
  TextColumn get filePath => text().named('file_path')();
  IntColumn get timestamp => integer()();
  IntColumn get durationMs => integer().named('duration_ms')();
  TextColumn get status => text().withDefault(const Constant('pending'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('CaptureAudioMetadataRow')
class CaptureAudioMetadataEntries extends Table {
  @override
  String get tableName => 'capture_audio_metadata';

  TextColumn get id => text()();
  TextColumn get filePath => text().named('file_path')();
  IntColumn get createdAt => integer().named('created_at')();
  TextColumn get status => text().withDefault(const Constant('pending_analysis'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
