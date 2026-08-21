import 'package:archiveme_mobile/database/app_database.dart';
import 'package:archiveme_mobile/features/quick_capture/quick_capture_outbox_models.dart';
import 'package:archiveme_mobile/storage/drift/journal_database.dart';

/// Drift-backed outbox for widget / shortcut capture intents.
class QuickCaptureOutboxStore {
  QuickCaptureOutboxStore(this._db);

  final JournalDatabase _db;

  Future<String> enqueue(QuickCaptureOutboxPayload payload) =>
      _db.queueDao.enqueueQuickCapture(payload);

  Future<List<QuickCaptureOutboxEntry>> pending({int limit = 16}) =>
      _db.queueDao.listQuickCapturePending(limit: limit);

  Future<int> pendingCount() => _db.queueDao.quickCapturePendingCount();

  Future<void> markProcessing(String outboxId) =>
      _db.queueDao.markQuickCaptureProcessing(outboxId);

  Future<void> markDone(String outboxId) =>
      _db.queueDao.markQuickCaptureDone(outboxId);

  Future<void> markFailed(String outboxId, String error) =>
      _db.queueDao.markQuickCaptureFailed(outboxId, error);

  Future<int> requeueProcessing() => _db.queueDao.requeueQuickCaptureProcessing();
}
