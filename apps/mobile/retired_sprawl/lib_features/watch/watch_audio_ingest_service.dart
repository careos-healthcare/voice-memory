import 'dart:async';

import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/recording/recording_dependencies.dart' show CapturePipelineService;
import 'package:archiveme_mobile/features/watch/watch_audio_capture.dart';
import 'package:archiveme_mobile/features/watch/watch_audio_ingest_store.dart';
import 'package:archiveme_mobile/services/capture_pipeline_service.dart';
import 'package:flutter/foundation.dart';

enum WatchIngestEventKind { success, failure }

class WatchIngestEvent {
  const WatchIngestEvent._({
    required this.kind,
    this.result,
    this.capture,
    this.message,
  });

  factory WatchIngestEvent.success(CapturePipelineResult result) =>
      WatchIngestEvent._(kind: WatchIngestEventKind.success, result: result);

  factory WatchIngestEvent.failure(
    WatchAudioCapture capture,
    String message,
  ) => WatchIngestEvent._(
    kind: WatchIngestEventKind.failure,
    capture: capture,
    message: message,
  );

  final WatchIngestEventKind kind;
  final CapturePipelineResult? result;
  final WatchAudioCapture? capture;
  final String? message;
}

/// Serializes watch inbox files through [CapturePipelineService.runWatchCapture].
class WatchAudioIngestService {
  WatchAudioIngestService({
    required this._store, this._pipeline,
  });

  final CapturePipelineService? _pipeline;
  final WatchAudioIngestStore _store;
  final StreamController<WatchIngestEvent> _events =
      StreamController<WatchIngestEvent>.broadcast();
  final List<WatchAudioCapture> _queue = [];
  bool _processing = false;

  /// Test override for pipeline ingest without network/transcription setup.
  @visibleForTesting
  Future<CapturePipelineResult> Function({
    required String audioFilePath,
    int? durationSeconds,
  })?
  watchCaptureRunner;

  Stream<WatchIngestEvent> get events => _events.stream;

  Future<void> enqueue(WatchAudioCapture capture) async {
    if (await _store.isProcessed(capture.ingestKey)) return;
    _queue.add(capture);
    await _drainQueue();
  }

  Future<void> enqueueAll(Iterable<WatchAudioCapture> captures) async {
    for (final capture in captures) {
      if (await _store.isProcessed(capture.ingestKey)) continue;
      _queue.add(capture);
    }
    await _drainQueue();
  }

  Future<void> _drainQueue() async {
    if (_processing) return;
    _processing = true;
    try {
      while (_queue.isNotEmpty) {
        final capture = _queue.removeAt(0);
        if (await _store.isProcessed(capture.ingestKey)) continue;
        try {
          final result = watchCaptureRunner != null
              ? await watchCaptureRunner!(
                audioFilePath: capture.path,
                durationSeconds: capture.durationSeconds,
              )
              : (await _pipeline!.runWatchCapture(
                audioFilePath: capture.path,
                durationSeconds: capture.durationSeconds,
              )).getOrThrow();
          await _store.markProcessed(capture.ingestKey);
          _events.add(WatchIngestEvent.success(result));
        } catch (error, stackTrace) {
          AppLogger.debug('[WatchIngest] failed ${capture.path}: $error\n$stackTrace');
          _events.add(
            WatchIngestEvent.failure(
              capture,
              error is CapturePipelineFailure
                  ? error.message
                  : 'Watch recording could not be saved.',
            ),
          );
        }
      }
    } finally {
      _processing = false;
    }
  }

  void dispose() {
    unawaited(_events.close());
  }
}