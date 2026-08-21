import 'dart:io';

import 'package:archiveme_mobile/features/quick_capture/quick_capture_outbox_models.dart';
import 'package:archiveme_mobile/features/quick_capture/quick_capture_outbox_store.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_models.dart';
import 'package:archiveme_mobile/services/capture_pipeline_service.dart';
import 'package:archiveme_mobile/services/sync/background_sync_queue_worker.dart';

/// Processes queued widget / shortcut captures without opening capture UI.
class QuickCaptureBackgroundHandler {
  QuickCaptureBackgroundHandler({
    required QuickCaptureOutboxStore outbox,
    required CapturePipelineService pipeline,
    BackgroundSyncQueueWorker? backgroundSyncWorker,
  }) : _outbox = outbox,
       _pipeline = pipeline,
       _backgroundSyncWorker = backgroundSyncWorker;

  final QuickCaptureOutboxStore _outbox;
  final CapturePipelineService _pipeline;
  final BackgroundSyncQueueWorker? _backgroundSyncWorker;

  static const maxAttempts = 5;

  Future<QuickCaptureProcessResult> processPending() async {
    await _outbox.requeueProcessing();
    final pending = await _outbox.pending();
    if (pending.isEmpty) {
      return const QuickCaptureProcessResult(processed: 0, failed: 0);
    }

    var processed = 0;
    var failed = 0;

    for (final entry in pending) {
      if (entry.attemptCount >= maxAttempts) {
        await _outbox.markFailed(
          entry.outboxId,
          'max_attempts_exceeded',
        );
        failed += 1;
        continue;
      }

      await _outbox.markProcessing(entry.outboxId);
      try {
        await _processEntry(entry.payload);
        await _outbox.markDone(entry.outboxId);
        processed += 1;
      } on Object catch (error, stackTrace) {
        await _outbox.markFailed(entry.outboxId, '$error');
        failed += 1;
      }
    }

    final worker = _backgroundSyncWorker;
    if (processed > 0 && worker != null) {
      await worker.enqueueAllPending();
      await worker.flush();
    }

    return QuickCaptureProcessResult(processed: processed, failed: failed);
  }

  Future<void> _processEntry(QuickCaptureOutboxPayload payload) async {
    switch (payload.kind) {
      case QuickCaptureKind.text:
        final text = payload.text?.trim() ?? '';
        if (text.isEmpty) {
          throw StateError('quick_capture_text_empty');
        }
        final outcome = await _pipeline.saveTextThought(transcript: text);
        outcome.match(
          (failure) => throw StateError(failure.message),
          (_) {},
        );
      case QuickCaptureKind.voice:
        final path = payload.audioPath?.trim() ?? '';
        if (path.isEmpty) {
          throw StateError('quick_capture_audio_missing');
        }
        final file = File(path);
        if (!file.existsSync()) {
          throw StateError('quick_capture_audio_not_found');
        }
        final duration = payload.durationSeconds < 1
            ? 1
            : payload.durationSeconds;
        final outcome = await _pipeline.run(
          audioFile: file,
          durationSeconds: duration,
        );
        outcome.match(
          (failure) => throw StateError(failure.message),
          (_) {},
        );
    }
  }
}

class QuickCaptureProcessResult {
  const QuickCaptureProcessResult({
    required this.processed,
    required this.failed,
  });

  final int processed;
  final int failed;

  bool get hadWork => processed > 0 || failed > 0;
}