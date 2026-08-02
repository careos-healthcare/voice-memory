import 'dart:async';
import 'dart:io';

import '../processing_preferences/processing_preferences.dart';
import '../../services/capture_pipeline_service.dart';
import '../../storage/journal_store.dart';
import 'transcription_job.dart';
import 'transcription_ledger.dart';

typedef QueueRetryScheduled = Future<void> Function();
typedef QueuePipelineRunner =
    Future<CapturePipelineResult> Function(TranscriptionJob job);
typedef QueueJournalProvider = JournalStore Function();

/// A foreground queue job that reached a durable journal save.
final class TranscriptionQueueCompletion {
  const TranscriptionQueueCompletion({required this.job, required this.result});

  final TranscriptionJob job;
  final CapturePipelineResult result;
}

/// Foreground-first, single-flight executor for durable transcription jobs.
final class TranscriptionQueueExecutor {
  TranscriptionQueueExecutor({
    required this.ledger,
    CapturePipelineService? pipeline,
    QueuePipelineRunner? runPipeline,
    JournalStore? journal,
    QueueJournalProvider? journalProvider,
    this.onRetryScheduled,
  }) : assert(pipeline != null || runPipeline != null),
       assert(journal != null || journalProvider != null),
       _journalProvider = journalProvider ?? (() => journal!),
       _runPipeline =
           runPipeline ??
           ((job) async {
             Future<CapturePipelineResult> run(File audio) => pipeline!.run(
               audioFile: audio,
               durationSeconds: job.durationSeconds,
               entryId: job.entryId,
               createdAt: job.createdAt,
               deferFailedTranscription: true,
               // The shipping Record surface reviews the transcript before
               // the canonical interpretation coordinator may run.
               currentInterpretationChoice:
                   InterpretationPreference.saveWithoutInterpretation,
             );
             final encryptedAudio = ledger.encryptedAudioStore;
             if (encryptedAudio == null) return run(File(job.audioPath));
             return encryptedAudio.withDecryptedFile(File(job.audioPath), run);
           });

  final TranscriptionLedger ledger;
  final QueuePipelineRunner _runPipeline;
  final QueueJournalProvider _journalProvider;
  JournalStore get journal => _journalProvider();
  final QueueRetryScheduled? onRetryScheduled;
  final StreamController<TranscriptionQueueCompletion> _completions =
      StreamController<TranscriptionQueueCompletion>.broadcast(sync: true);

  bool _draining = false;
  bool _paused = false;
  Completer<void>? _drainCompleted;

  bool get isPaused => _paused;

  /// Emits only after the pipeline result and queue completion are durable.
  Stream<TranscriptionQueueCompletion> get completions => _completions.stream;

  void pause() => _paused = true;

  void resume() => _paused = false;

  Future<void> pauseAndWait() async {
    pause();
    await _drainCompleted?.future;
  }

  Future<void> dispose() => _completions.close();

  Future<int> drain({int maxJobs = 8}) async {
    if (_draining || _paused || maxJobs < 1) return 0;
    _draining = true;
    _drainCompleted = Completer<void>();
    var processed = 0;
    try {
      while (!_paused && processed < maxJobs) {
        final job = ledger.acquireLease();
        if (job == null) break;
        await _execute(job);
        processed += 1;
      }
      return processed;
    } finally {
      _draining = false;
      _drainCompleted?.complete();
      _drainCompleted = null;
    }
  }

  Future<void> _execute(TranscriptionJob job) async {
    final token = job.leaseToken;
    if (token == null) return;
    try {
      final existing = await journal.getById(job.entryId);
      final transcript = existing?.transcript.trim();
      if (transcript != null && transcript.isNotEmpty) {
        ledger.complete(id: job.id, leaseToken: token, transcript: transcript);
        await _deleteOwnedAudio(job);
        return;
      }

      final result = await _runPipeline(job);
      ledger.complete(
        id: job.id,
        leaseToken: token,
        transcript: result.entry.transcript,
      );
      await _deleteOwnedAudio(job);
      if (!_completions.isClosed) {
        _completions.add(
          TranscriptionQueueCompletion(job: job, result: result),
        );
      }
    } on StateError {
      // A stale worker must never overwrite a newer lease or delete its audio.
    } on Object catch (error) {
      final current = ledger.getJob(job.id);
      if (current?.leaseToken != token ||
          current?.status != TranscriptionJobStatus.processing) {
        return;
      }
      final updated = ledger.retry(
        id: job.id,
        leaseToken: token,
        error: _sanitizedFailureCode(error),
      );
      if (updated.status == TranscriptionJobStatus.retryWaiting) {
        await onRetryScheduled?.call();
      }
    }
  }

  Future<void> _deleteOwnedAudio(TranscriptionJob job) async {
    final audio = File(job.audioPath);
    if (await audio.exists()) await audio.delete();
  }

  static String _sanitizedFailureCode(Object error) {
    if (error is CapturePipelineFailure) {
      final normalized = error.message
          .toLowerCase()
          .replaceAll(RegExp('[^a-z0-9]+'), '_')
          .replaceAll(RegExp('^_+|_+\$'), '');
      return normalized.isEmpty
          ? 'capture_pipeline_failure'
          : normalized.substring(0, normalized.length.clamp(0, 64));
    }
    if (error is FileSystemException) return 'audio_io_failure';
    if (error is TimeoutException) return 'transcription_timeout';
    return 'transcription_unavailable';
  }
}
