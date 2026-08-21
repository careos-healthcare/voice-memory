import 'dart:convert';

import 'package:archiveme_mobile/database/app_database.dart';
import 'package:archiveme_mobile/features/capture/models/capture_audio_metadata.dart';
import 'package:archiveme_mobile/features/quick_capture/quick_capture_outbox_models.dart';
import 'package:archiveme_mobile/models/audio_processing_queue_item.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_014_embedding_deferred_queue.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_016_audio_processing_queue.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_017_capture_audio_metadata.dart';
import 'package:archiveme_mobile/sync/ulid.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

part 'queue_dao.g.dart';

/// One deferred embedding task persisted until power/battery constraints ease.
final class EmbeddingDeferredTask {
  const EmbeddingDeferredTask({
    required this.queueId,
    required this.operation,
    required this.entryId,
    required this.text,
    required this.sqliteFilePath,
    this.contentHash,
    this.keyAlias,
    this.encryptionPassword,
    required this.createdAt,
  });

  final String queueId;
  final String operation;
  final String entryId;
  final String text;
  final String? contentHash;
  final String sqliteFilePath;
  final String? keyAlias;
  final String? encryptionPassword;
  final DateTime createdAt;
}

@DriftAccessor(tables: [
  EmbeddingDeferredQueueEntries,
  AudioProcessingQueueEntries,
  CaptureAudioMetadataEntries,
  QuickCaptureOutboxEntries,
])
class QueueDao extends DatabaseAccessor<AppDatabase> with _$QueueDaoMixin {
  QueueDao(super.db);

  static const _uuid = Uuid();

  Future<void> enqueueDeferredReflection({
    required String entryId,
    required String text,
    required String contentHash,
    required String sqliteFilePath,
    String? keyAlias,
    String? encryptionPassword,
  }) =>
      _enqueueDeferred(
        operation: Migration014EmbeddingDeferredQueue.operationIndexReflection,
        entryId: entryId,
        text: text,
        contentHash: contentHash,
        sqliteFilePath: sqliteFilePath,
        keyAlias: keyAlias,
        encryptionPassword: encryptionPassword,
        queueId: 'reflection:$entryId:$contentHash',
      );

  Future<void> enqueueDeferredLlmSummary({
    required String entryId,
    required String llmSummary,
    required String sqliteFilePath,
    String? keyAlias,
    String? encryptionPassword,
  }) =>
      _enqueueDeferred(
        operation: Migration014EmbeddingDeferredQueue.operationIndexTranscript,
        entryId: entryId,
        text: llmSummary,
        sqliteFilePath: sqliteFilePath,
        keyAlias: keyAlias,
        encryptionPassword: encryptionPassword,
        queueId: 'transcript:$entryId',
      );

  Future<List<EmbeddingDeferredTask>> listDeferredPending({int? limit}) async {
    final query = select(embeddingDeferredQueueEntries)
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    if (limit != null) {
      query.limit(limit);
    }
    final rows = await query.get();
    return rows.map(_deferredTaskFromRow).toList(growable: false);
  }

  Future<int> deferredPendingCount() async {
    final count = countAll();
    final query = selectOnly(embeddingDeferredQueueEntries)..addColumns([count]);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<void> removeDeferred(String queueId) async {
    if (queueId.isEmpty) return;
    await (delete(embeddingDeferredQueueEntries)
          ..where((t) => t.queueId.equals(queueId)))
        .go();
  }

  Future<void> insertAudioProcessingPending({
    required String id,
    required String filePath,
    required DateTime timestamp,
    required int durationMs,
  }) async {
    await into(audioProcessingQueueEntries).insert(
      AudioProcessingQueueEntriesCompanion.insert(
        id: id,
        filePath: filePath,
        timestamp: timestamp.millisecondsSinceEpoch,
        durationMs: durationMs,
        status: Value(AudioProcessingQueueStatus.pending.storageValue),
      ),
    );
  }

  Future<AudioProcessingQueueItem?> findAudioProcessingById(String id) async {
    final row = await (select(audioProcessingQueueEntries)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return AudioProcessingQueueItem.fromMap(_audioProcessingToMap(row));
  }

  Future<List<AudioProcessingQueueItem>> listAudioProcessingPending({
    int limit = 50,
  }) async {
    final rows = await (select(audioProcessingQueueEntries)
          ..where(
            (t) => t.status.equals(AudioProcessingQueueStatus.pending.storageValue),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.timestamp)])
          ..limit(limit))
        .get();
    return rows
        .map((row) => AudioProcessingQueueItem.fromMap(_audioProcessingToMap(row)))
        .toList(growable: false);
  }

  Future<void> updateAudioProcessingStatus({
    required String id,
    required AudioProcessingQueueStatus status,
  }) async {
    await (update(audioProcessingQueueEntries)..where((t) => t.id.equals(id)))
        .write(
      AudioProcessingQueueEntriesCompanion(
        status: Value(status.storageValue),
      ),
    );
  }

  Future<CaptureAudioMetadata> insertCaptureMetadataPending({
    required String id,
    required String filePath,
    DateTime? createdAt,
  }) async {
    final timestamp = createdAt ?? DateTime.now();
    final row = CaptureAudioMetadata(
      id: id,
      filePath: filePath,
      createdAt: timestamp,
      status: Migration017CaptureAudioMetadata.statusPendingAnalysis,
    );
    await into(captureAudioMetadataEntries).insert(
      CaptureAudioMetadataEntriesCompanion.insert(
        id: row.id,
        filePath: row.filePath,
        createdAt: row.createdAt.millisecondsSinceEpoch,
        status: Value(row.status),
      ),
    );
    return row;
  }

  Future<void> updateCaptureMetadataStatus({
    required String id,
    required String status,
  }) async {
    await (update(captureAudioMetadataEntries)..where((t) => t.id.equals(id)))
        .write(
      CaptureAudioMetadataEntriesCompanion(status: Value(status)),
    );
  }

  Future<List<CaptureAudioMetadata>> listCaptureMetadataByStatus(
    String status,
  ) async {
    final rows = await (select(captureAudioMetadataEntries)
          ..where((t) => t.status.equals(status))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    return rows.map(_captureMetadataFromRow).toList(growable: false);
  }

  Future<CaptureAudioMetadata?> findCaptureMetadataById(String id) async {
    final row = await (select(captureAudioMetadataEntries)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return _captureMetadataFromRow(row);
  }

  Future<String> enqueueQuickCapture(QuickCaptureOutboxPayload payload) async {
    final now = DateTime.now().toUtc();
    final nowMillis = now.millisecondsSinceEpoch;
    final payloadJson = jsonEncode(payload.toJson());

    final existing = await (select(quickCaptureOutboxEntries)
          ..where(
            (t) =>
                t.captureId.equals(payload.captureId) &
                t.status.isIn(['pending', 'processing']),
          )
          ..limit(1))
        .getSingleOrNull();

    if (existing != null) {
      await (update(quickCaptureOutboxEntries)
            ..where((t) => t.outboxId.equals(existing.outboxId)))
          .write(
        QuickCaptureOutboxEntriesCompanion(
          payloadJson: Value(payloadJson),
          status: const Value('pending'),
          updatedAt: Value(nowMillis),
          lastError: const Value(null),
        ),
      );
      return existing.outboxId;
    }

    final outboxId = generateUlid();
    await into(quickCaptureOutboxEntries).insert(
      QuickCaptureOutboxEntriesCompanion.insert(
        outboxId: outboxId,
        captureId: payload.captureId,
        kind: payload.kind.storageValue,
        payloadJson: payloadJson,
        createdAt: nowMillis,
        updatedAt: nowMillis,
      ),
    );
    return outboxId;
  }

  Future<List<QuickCaptureOutboxEntry>> listQuickCapturePending({
    int limit = 16,
  }) async {
    final rows = await (select(quickCaptureOutboxEntries)
          ..where((t) => t.status.equals('pending'))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
          ..limit(limit))
        .get();
    return rows.map(_quickCaptureFromRow).toList(growable: false);
  }

  Future<int> quickCapturePendingCount() async {
    final count = countAll();
    final query = selectOnly(quickCaptureOutboxEntries)
      ..addColumns([count])
      ..where(quickCaptureOutboxEntries.status.equals('pending'));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<void> markQuickCaptureProcessing(String outboxId) async {
    final nowMillis = DateTime.now().toUtc().millisecondsSinceEpoch;
    final row = await (select(quickCaptureOutboxEntries)
          ..where((t) => t.outboxId.equals(outboxId)))
        .getSingleOrNull();
    if (row == null) return;

    await (update(quickCaptureOutboxEntries)
          ..where((t) => t.outboxId.equals(outboxId)))
        .write(
      QuickCaptureOutboxEntriesCompanion(
        status: const Value('processing'),
        updatedAt: Value(nowMillis),
        attemptCount: Value(row.attemptCount + 1),
      ),
    );
  }

  Future<void> markQuickCaptureDone(String outboxId) async {
    final nowMillis = DateTime.now().toUtc().millisecondsSinceEpoch;
    await (update(quickCaptureOutboxEntries)
          ..where((t) => t.outboxId.equals(outboxId)))
        .write(
      QuickCaptureOutboxEntriesCompanion(
        status: const Value('done'),
        updatedAt: Value(nowMillis),
        lastError: const Value(null),
      ),
    );
  }

  Future<void> markQuickCaptureFailed(String outboxId, String error) async {
    final nowMillis = DateTime.now().toUtc().millisecondsSinceEpoch;
    await (update(quickCaptureOutboxEntries)
          ..where((t) => t.outboxId.equals(outboxId)))
        .write(
      QuickCaptureOutboxEntriesCompanion(
        status: const Value('pending'),
        updatedAt: Value(nowMillis),
        lastError: Value(error),
      ),
    );
  }

  Future<int> requeueQuickCaptureProcessing() async {
    final nowMillis = DateTime.now().toUtc().millisecondsSinceEpoch;
    return (update(quickCaptureOutboxEntries)
          ..where((t) => t.status.equals('processing')))
        .write(
      QuickCaptureOutboxEntriesCompanion(
        status: const Value('pending'),
        updatedAt: Value(nowMillis),
      ),
    );
  }

  Future<void> _enqueueDeferred({
    required String operation,
    required String entryId,
    required String text,
    required String sqliteFilePath,
    required String queueId,
    String? contentHash,
    String? keyAlias,
    String? encryptionPassword,
  }) async {
    if (entryId.isEmpty || text.trim().isEmpty || sqliteFilePath.isEmpty) {
      return;
    }

    final nowMillis = DateTime.now().toUtc().millisecondsSinceEpoch;
    await into(embeddingDeferredQueueEntries).insertOnConflictUpdate(
      EmbeddingDeferredQueueEntriesCompanion.insert(
        queueId: queueId.isNotEmpty ? queueId : _uuid.v4(),
        operation: operation,
        entryId: entryId,
        bodyText: text,
        contentHash: Value(contentHash),
        sqliteFilePath: sqliteFilePath,
        keyAlias: Value(keyAlias),
        encryptionPassword: Value(encryptionPassword),
        createdAt: nowMillis,
        updatedAt: nowMillis,
      ),
    );
  }

  EmbeddingDeferredTask _deferredTaskFromRow(EmbeddingDeferredQueueRow row) {
    return EmbeddingDeferredTask(
      queueId: row.queueId,
      operation: row.operation,
      entryId: row.entryId,
      text: row.bodyText,
      contentHash: row.contentHash,
      sqliteFilePath: row.sqliteFilePath,
      keyAlias: row.keyAlias,
      encryptionPassword: row.encryptionPassword,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt, isUtc: true),
    );
  }

  Map<String, Object?> _audioProcessingToMap(AudioProcessingQueueRow row) => {
    'id': row.id,
    'file_path': row.filePath,
    'timestamp': row.timestamp,
    'duration_ms': row.durationMs,
    'status': row.status,
  };

  CaptureAudioMetadata _captureMetadataFromRow(CaptureAudioMetadataRow row) {
    return CaptureAudioMetadata(
      id: row.id,
      filePath: row.filePath,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt, isUtc: true),
      status: row.status,
    );
  }

  QuickCaptureOutboxEntry _quickCaptureFromRow(QuickCaptureOutboxRow row) {
    final payloadMap = jsonDecode(row.payloadJson) as Map<String, dynamic>;
    return QuickCaptureOutboxEntry(
      outboxId: row.outboxId,
      payload: QuickCaptureOutboxPayload.fromJson(payloadMap),
      status: QuickCaptureOutboxStatus.parse(row.status),
      attemptCount: row.attemptCount,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt, isUtc: true),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt, isUtc: true),
      lastError: row.lastError,
    );
  }
}
