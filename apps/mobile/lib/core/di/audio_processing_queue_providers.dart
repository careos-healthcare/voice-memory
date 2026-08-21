import 'dart:async';

import 'package:archiveme_mobile/audio/recording_service.dart';
import 'package:archiveme_mobile/core/di/storage_providers.dart';
import 'package:archiveme_mobile/services/audio_processing_queue_service.dart';
import 'package:archiveme_mobile/storage/audio/local_audio_storage_service.dart';
import 'package:archiveme_mobile/storage/sqlite/audio_processing_queue_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final localAudioStorageServiceProvider = Provider<LocalAudioStorageService>(
  (ref) => LocalAudioStorageService(),
);

final audioProcessingQueueRepositoryProvider =
    Provider<AudioProcessingQueueRepository>(
  (ref) => AudioProcessingQueueRepository(ref.watch(appSqliteDatabaseProvider)),
);

final audioProcessingQueueServiceProvider = Provider<AudioProcessingQueueService>(
  (ref) => AudioProcessingQueueService(
    storage: ref.watch(localAudioStorageServiceProvider),
    repository: ref.watch(audioProcessingQueueRepositoryProvider),
  ),
);

/// Enqueues completed recordings into hybrid local storage + SQLite.
final audioProcessingQueueListenerProvider = Provider<void>((ref) {
  ref.listen(recordingServiceProvider, (previous, next) {
    final completion = next.recordingCompletion;
    if (completion == null) return;
    if (previous?.recordingCompletion == completion) return;

    unawaited(Future<void>(() async {
      try {
        await ref.read(audioProcessingQueueServiceProvider).enqueueRecording(
          sourceFile: completion.file,
          durationMs: completion.durationMs,
        );
      } finally {
        ref.read(recordingServiceProvider.notifier).acknowledgeRecordingCompletion();
      }
    }));
  });
});
