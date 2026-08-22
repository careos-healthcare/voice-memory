// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'queue_dao.dart';

// ignore_for_file: type=lint
mixin _$QueueDaoMixin on DatabaseAccessor<AppDatabase> {
  $EmbeddingDeferredQueueEntriesTable get embeddingDeferredQueueEntries =>
      attachedDatabase.embeddingDeferredQueueEntries;
  $AudioProcessingQueueEntriesTable get audioProcessingQueueEntries =>
      attachedDatabase.audioProcessingQueueEntries;
  $CaptureAudioMetadataEntriesTable get captureAudioMetadataEntries =>
      attachedDatabase.captureAudioMetadataEntries;
  $QuickCaptureOutboxEntriesTable get quickCaptureOutboxEntries =>
      attachedDatabase.quickCaptureOutboxEntries;
  QueueDaoManager get managers => QueueDaoManager(this);
}

class QueueDaoManager {
  final _$QueueDaoMixin _db;
  QueueDaoManager(this._db);
  $$EmbeddingDeferredQueueEntriesTableTableManager
  get embeddingDeferredQueueEntries =>
      $$EmbeddingDeferredQueueEntriesTableTableManager(
        _db.attachedDatabase,
        _db.embeddingDeferredQueueEntries,
      );
  $$AudioProcessingQueueEntriesTableTableManager
  get audioProcessingQueueEntries =>
      $$AudioProcessingQueueEntriesTableTableManager(
        _db.attachedDatabase,
        _db.audioProcessingQueueEntries,
      );
  $$CaptureAudioMetadataEntriesTableTableManager
  get captureAudioMetadataEntries =>
      $$CaptureAudioMetadataEntriesTableTableManager(
        _db.attachedDatabase,
        _db.captureAudioMetadataEntries,
      );
  $$QuickCaptureOutboxEntriesTableTableManager get quickCaptureOutboxEntries =>
      $$QuickCaptureOutboxEntriesTableTableManager(
        _db.attachedDatabase,
        _db.quickCaptureOutboxEntries,
      );
}
