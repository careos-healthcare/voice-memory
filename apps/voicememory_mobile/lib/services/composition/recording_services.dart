import 'dart:io';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import '../../audio/recording_service.dart';
import '../../features/capture_api_retry/capture_api_retry_queue.dart';
import '../../features/processing_preferences/processing_preferences.dart';
import '../../features/processing_preferences/processing_preferences_store.dart';
import '../../features/remote_transcription/remote_transcription_disclosure.dart';
import '../../features/transcription_queue/transcription_ledger.dart';
import '../../features/transcription_queue/transcription_queue_executor.dart';
import '../../features/transcription_queue/transcription_queue_foreground_coordinator.dart';
import '../../features/transcription_queue/transcription_work_scheduler.dart';
import '../../features/voice_capture/transcription/on_device_transcription_engine.dart';
import '../../security/app_lock_service.dart';
import '../../storage/private_data_encryption_key_store.dart';
import '../capture_attest_service.dart';
import '../capture_pipeline_service.dart';
import '../local_storage/encrypted_audio_file_store.dart';
import '../local_storage/encrypted_sqlite_text_codec.dart';
import '../privacy/audio_vault_service.dart';
import 'archive_services.dart';
import 'core_services.dart';
import 'privacy_services.dart';
import 'v1_composition_config.dart';

enum _LazyRecordingState { idle, creating, ready, disposed }

final class RecordingServices {
  RecordingServices._({
    required this.attest,
    required this.pipeline,
    required this.captureApiRetryQueue,
    required this.transcriptionWorkScheduler,
    required this.transcriptionLedger,
    required this.transcriptionQueueExecutor,
    required this.transcriptionQueueForegroundCoordinator,
    required this.onDeviceTranscription,
    required this._recordingFactory,
  });

  final CaptureAttestService attest;
  final CapturePipelineService pipeline;
  final CaptureApiRetryQueue captureApiRetryQueue;
  final TranscriptionWorkScheduler transcriptionWorkScheduler;
  final TranscriptionLedger transcriptionLedger;
  final TranscriptionQueueExecutor transcriptionQueueExecutor;
  final TranscriptionQueueForegroundCoordinator
  transcriptionQueueForegroundCoordinator;

  /// The single on-device engine shared by the capture pipeline and the
  /// post-capture local transcription choice.
  final OnDeviceTranscriptionEngine onDeviceTranscription;
  final RecordingService Function() _recordingFactory;

  RecordingService? _recording;
  _LazyRecordingState _recordingState = _LazyRecordingState.idle;

  bool get isRecordingServiceCreated =>
      _recordingState == _LazyRecordingState.ready;

  RecordingService get recording {
    final existing = _recording;
    if (existing != null) return existing;
    if (_recordingState == _LazyRecordingState.creating) {
      throw StateError('Recording service construction cycle detected.');
    }
    if (_recordingState == _LazyRecordingState.disposed) {
      throw StateError('Recording services have been disposed.');
    }
    _recordingState = _LazyRecordingState.creating;
    try {
      final created = _recordingFactory();
      _recording = created;
      _recordingState = _LazyRecordingState.ready;
      return created;
    } on Object {
      _recordingState = _LazyRecordingState.idle;
      rethrow;
    }
  }

  static Future<RecordingServices> create(
    CoreServices core,
    PrivacyServices privacy,
    ArchiveServices archive,
    V1CompositionConfig config,
  ) async {
    final scheduler = const ForegroundOnlyTranscriptionScheduler();
    final attest = CaptureAttestService(
      authApi: core.authApi,
      voiceApi: core.voiceCaptureApi,
      deviceIds: core.deviceIds,
      tokenCache: core.tokenCache,
    );
    final processingPreferences = ProcessingPreferencesStore(
      prefs: () => core.prefs,
      archiveId: () => archive.identity.archiveId,
    );
    Future<bool> isRemoteOperationAuthorized(
      CaptureApiRetryOperation operation,
    ) async {
      try {
        final preferences = await processingPreferences.read();
        final purpose = switch (operation) {
          CaptureApiRetryOperation.transcribe =>
            RemoteProcessingPurpose.transcription,
          CaptureApiRetryOperation.analyze =>
            RemoteProcessingPurpose.interpretation,
        };
        final choiceAllows = switch (operation) {
          CaptureApiRetryOperation.transcribe =>
            preferences.transcription !=
                    TranscriptionPreference.saveWithoutTranscript &&
                preferences.transcription !=
                    TranscriptionPreference.onThisDevice,
          CaptureApiRetryOperation.analyze =>
            preferences.interpretation ==
                    InterpretationPreference.generatePossibleRead ||
                preferences.interpretation ==
                    InterpretationPreference.askEachTime,
        };
        if (!choiceAllows) return false;
        return (await core.remoteTranscriptionDisclosure.check(
          purpose: purpose,
        )).isAccepted;
      } on Object {
        return false;
      }
    }

    late final TranscriptionWorkScheduler schedulerForRetry;
    final retryQueue = CaptureApiRetryQueue(
      manifestFile: File('${config.basePath}/capture_api_retry_queue.enc'),
      keyStore: config.testMode
          ? InMemoryPrivateDataEncryptionKeyStore()
          : SecurePrivateDataEncryptionKeyStore(secure: core.secureStorage),
      api: core.voiceCaptureApi,
      attest: attest,
      journalStore: archive.journalStore,
      audioVault: privacy.audioVault,
      explainabilityHistoryStore: archive.explainabilityHistoryStore,
      connectivityChanges: config.testMode
          ? const Stream<List<ConnectivityResult>>.empty()
          : Connectivity().onConnectivityChanged,
      onRetryScheduled: () => schedulerForRetry.schedule(),
      isRemoteOperationAuthorized: isRemoteOperationAuthorized,
      canDrain: config.testMode
          ? () async => true
          : () async =>
                WidgetsBinding.instance.lifecycleState ==
                    AppLifecycleState.resumed &&
                !await AppLockService.instance.isLocked(),
    );
    schedulerForRetry = scheduler;
    final onDeviceTranscription =
        config.onDeviceTranscription ?? WhisperOnDeviceTranscriptionEngine();
    final pipeline = CapturePipelineService(
      api: core.voiceCaptureApi,
      attest: attest,
      journalStore: archive.journalStore,
      onDeviceTranscription: onDeviceTranscription,
      transcriptionConnectivity: config.transcriptionConnectivity,
      retryQueue: retryQueue,
      explainabilityHistoryStore: archive.explainabilityHistoryStore,
      audioVault: privacy.audioVault,
      processingPreferences: processingPreferences,
      remoteDisclosure: core.remoteTranscriptionDisclosure,
    );
    await AudioVaultJournalMigrator(
      privacy.audioVault,
    ).migrateAndRecover(journalStore: archive.journalStore);

    final Future<List<int>> Function() audioKeyProvider = config.testMode
        ? InMemoryPrivateDataEncryptionKeyStore().ensureKey
        : SecurePrivateDataEncryptionKeyStore(
            secure: core.secureStorage,
          ).ensureKey;
    final ledger = await TranscriptionLedger.open(
      directory: Directory('${config.basePath}/transcription_queue'),
      textCodec: privacy.biometricVault?.isEnabled == true
          ? EncryptedSqliteTextCodec(privacy.biometricVault!.requireKeyBytes)
          : null,
      encryptedAudioStore: EncryptedAudioFileStore(
        keyProvider: () async => Uint8List.fromList(await audioKeyProvider()),
      ),
    );
    final executor = TranscriptionQueueExecutor(
      ledger: ledger,
      pipeline: pipeline,
      journalProvider: () => archive.journalStore,
      onRetryScheduled: scheduler.schedule,
    );
    final foreground = TranscriptionQueueForegroundCoordinator(
      executor: executor,
      connectivityChanges: config.testMode
          ? const Stream<List<ConnectivityResult>>.empty()
          : null,
    );
    return RecordingServices._(
      attest: attest,
      pipeline: pipeline,
      captureApiRetryQueue: retryQueue,
      transcriptionWorkScheduler: scheduler,
      transcriptionLedger: ledger,
      transcriptionQueueExecutor: executor,
      transcriptionQueueForegroundCoordinator: foreground,
      onDeviceTranscription: onDeviceTranscription,
      recordingFactory: () =>
          config.recording ??
          RecordingService(
            testMode: config.testMode,
            temporaryAudioOwner:
                'archive:${archive.journalStore.ownerArchiveId}',
          ),
    );
  }

  Future<void> startForegroundOwnership() async {
    await transcriptionWorkScheduler.initialize();
    transcriptionQueueForegroundCoordinator.start();
  }

  Future<void> pauseForAccountTransition() =>
      transcriptionQueueExecutor.pauseAndWait();

  void resumeAfterAccountTransition() {
    transcriptionQueueExecutor.resume();
  }

  Future<void> dispose() async {
    _recordingState = _LazyRecordingState.disposed;
    _recording?.dispose();
    await captureApiRetryQueue.dispose();
    await transcriptionQueueForegroundCoordinator.dispose();
    await transcriptionQueueExecutor.dispose();
    await transcriptionLedger.close();
  }
}
