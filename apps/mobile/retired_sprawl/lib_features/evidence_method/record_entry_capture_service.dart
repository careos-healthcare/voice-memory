import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/core/di/app_provider_container.dart';
import 'package:archiveme_mobile/core/di/network_providers.dart';
import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/evidence_method/record_entry_config.dart';
import 'package:archiveme_mobile/features/live_audio/domain/models/live_audio_session_config.dart';
import 'package:archiveme_mobile/features/live_audio/domain/models/live_server_event.dart';
import 'package:archiveme_mobile/features/live_audio/domain/services/live_audio_transcript_collector.dart';
import 'package:archiveme_mobile/features/live_audio/infrastructure/live_audio_session_api_client.dart';
import 'package:archiveme_mobile/features/live_audio/infrastructure/live_audio_websocket_client.dart';
import 'package:archiveme_mobile/features/live_audio/infrastructure/record_live_pcm16_capture_source.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/services/audio_encryption_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/storage/app_storage_paths.dart';

/// Hold-to-record live audio capture for the Evidence Method vertical slice.
class RecordEntryCaptureService {
  RecordEntryCaptureService({
    LiveAudioSessionApiClient? sessionApi,
    LiveAudioWebSocketClient? webSocketClient,
    RecordLivePcm16CaptureSource? captureSource,
    AudioEncryptionService? audioEncryptionService,
  }) : _sessionApi =
           sessionApi ??
           RepositoryLiveAudioSessionClient(
             appProviderContainer.read(liveAudioRepositoryProvider),
           ),
       _webSocketClient = webSocketClient ?? LiveAudioWebSocketClient(),
       _captureSource = captureSource ?? RecordLivePcm16CaptureSource(),
       _audioEncryptionService =
           audioEncryptionService ?? AudioEncryptionService();

  final LiveAudioSessionApiClient _sessionApi;
  final LiveAudioWebSocketClient _webSocketClient;
  final RecordLivePcm16CaptureSource _captureSource;
  final AudioEncryptionService _audioEncryptionService;
  final LiveAudioTranscriptCollector _transcripts = LiveAudioTranscriptCollector();

  StreamSubscription<LiveServerEvent>? _eventsSubscription;
  RandomAccessFile? _pcmBackupSink;
  File? _pcmBackupFile;
  String? _entryId;
  var _active = false;
  var _backgroundPaused = false;

  bool get isActive => _active;

  Future<void> beginHold() async {
    if (_active) return;
    _active = true;
    _backgroundPaused = false;
    _entryId = JournalSyncIds.newOfflineEntryId();
    _transcripts.reset();

    await _openPcmBackup(_entryId!);

    final captureToken = await AppServices.instance.attest.ensureCaptureToken();
    final minted = await _sessionApi.mintSession(captureToken: captureToken);
    final session = _withWebSocketOverride(
      minted,
      RecordEntryConfig.liveAudioWebSocketUrl,
    );

    _eventsSubscription = _webSocketClient.serverEvents.listen(
      _transcripts.ingest,
    );

    await _webSocketClient.connect(session);
    await _waitForSetupComplete();

    await _captureSource.start(
      onChunk: _handlePcmChunk,
    );
  }

  Future<RecordEntryCaptureResult> endHold() async {
    if (!_active) {
      throw StateError('Record entry capture is not active.');
    }

    try {
      if (_backgroundPaused) {
        await resumeAfterBackground();
      }

      await _captureSource.stop();
      if (_webSocketClient.setupComplete) {
        _webSocketClient.sendAudioStreamEnd();
      }
      await _waitForFinalTranscript();
      await _webSocketClient.disconnect();

      final transcript = _transcripts.bestTranscript.trim();
      if (transcript.isEmpty) {
        throw RecordEntryCaptureException(
          'No speech was detected. Hold the button and speak clearly.',
        );
      }

      final encryptedFile = await _encryptPcmBackupIfPresent();

      return RecordEntryCaptureResult(
        entryId: _entryId!,
        transcript: transcript,
        encryptedAudioPath: encryptedFile?.path,
      );
    } finally {
      await _eventsSubscription?.cancel();
      _eventsSubscription = null;
      _active = false;
      _backgroundPaused = false;
    }
  }

  Future<void> cancel() async {
    if (!_active) return;
    try {
      await _captureSource.stop();
      await _webSocketClient.disconnect();
    } finally {
      await _eventsSubscription?.cancel();
      _eventsSubscription = null;
      await _closePcmBackup(deleteFile: true);
      _active = false;
      _backgroundPaused = false;
      _transcripts.reset();
    }
  }

  /// Stops the microphone stream and encrypts buffered PCM to local disk.
  Future<File?> pauseForBackground() async {
    if (!_active || _backgroundPaused) {
      return _pcmBackupFile;
    }

    await _captureSource.stop();
    _backgroundPaused = true;

    if (_webSocketClient.setupComplete) {
      _webSocketClient.sendAudioStreamEnd();
    }

    return _encryptPcmBackupIfPresent();
  }

  /// Restarts microphone streaming after a background pause.
  Future<void> resumeAfterBackground() async {
    if (!_active || !_backgroundPaused) {
      return;
    }

    await _captureSource.start(onChunk: _handlePcmChunk);
    _backgroundPaused = false;
  }

  void dispose() {
    unawaited(cancel());
    _captureSource.dispose();
  }

  void _handlePcmChunk(List<int> chunk) {
    _webSocketClient.sendPcm16kChunk(chunk);
    _appendPcmBackup(chunk);
  }

  Future<void> _openPcmBackup(String entryId) async {
    await _closePcmBackup(deleteFile: true);
    final dir = await AppStoragePaths.temporaryDirectory();
    _pcmBackupFile = File('${dir.path}/record_entry_$entryId.pcm');
    _pcmBackupSink = await _pcmBackupFile!.open(mode: FileMode.write);
  }

  void _appendPcmBackup(List<int> chunk) {
    _pcmBackupSink?.writeFromSync(chunk);
  }

  Future<void> _closePcmBackup({required bool deleteFile}) async {
    try {
      await _pcmBackupSink?.flush();
      await _pcmBackupSink?.close();
    } catch (e, stackTrace) {
      AppLogger.error('Unhandled error caught', error: e, stackTrace: stackTrace);
      // Best-effort cleanup.
    }
    _pcmBackupSink = null;

    if (deleteFile && _pcmBackupFile != null) {
      try {
        if (await _pcmBackupFile!.exists()) {
          await _pcmBackupFile!.delete();
        }
      } catch (e, stackTrace) {
        AppLogger.error('Unhandled error caught', error: e, stackTrace: stackTrace);
        // Best-effort cleanup.
      }
    }
    _pcmBackupFile = null;
  }

  Future<File?> _encryptPcmBackupIfPresent() async {
    final rawFile = _pcmBackupFile;
    await _closePcmBackup(deleteFile: false);
    if (rawFile == null || !await rawFile.exists()) {
      return null;
    }
    if (await rawFile.length() == 0) {
      await rawFile.delete();
      return null;
    }

    return _audioEncryptionService.encryptAudioFile(rawFile);
  }

  Future<void> _waitForSetupComplete() async {
    if (_webSocketClient.setupComplete) return;

    final completer = Completer<void>();
    late StreamSubscription<LiveServerEvent> subscription;
    final timer = Timer(const Duration(seconds: 15), () {
      if (!completer.isCompleted) {
        completer.completeError(
          RecordEntryCaptureException('Timed out waiting for live audio setup.'),
        );
      }
    });

    subscription = _webSocketClient.serverEvents.listen((event) {
      if (event is LiveSetupCompleteEvent && !completer.isCompleted) {
        completer.complete();
      }
      if (event is LiveServerErrorEvent && !completer.isCompleted) {
        completer.completeError(
          RecordEntryCaptureException(event.message),
        );
      }
    });

    try {
      await completer.future;
    } finally {
      await subscription.cancel();
      timer.cancel();
    }
  }

  Future<void> _waitForFinalTranscript() async {
    const timeout = Duration(seconds: 5);
    final deadline = DateTime.now().add(timeout);
    var lastTranscript = _transcripts.bestTranscript;

    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      final current = _transcripts.bestTranscript;
      if (current.isNotEmpty && current == lastTranscript) {
        return;
      }
      lastTranscript = current;
    }
  }

  LiveAudioSessionConfig _withWebSocketOverride(
    LiveAudioSessionConfig session,
    String webSocketUrl,
  ) {
    return LiveAudioSessionConfig(
      sessionId: session.sessionId,
      sessionToken: session.sessionToken,
      proxyWebSocketUrl: webSocketUrl,
      expiresAt: session.expiresAt,
      model: session.model,
      inputAudioMimeType: session.inputAudioMimeType,
      outputAudioMimeType: session.outputAudioMimeType,
      vaultRecoverySecret: session.vaultRecoverySecret,
    );
  }
}

class RecordEntryCaptureResult {
  const RecordEntryCaptureResult({
    required this.entryId,
    required this.transcript,
    this.encryptedAudioPath,
  });

  final String entryId;
  final String transcript;
  final String? encryptedAudioPath;
}

class RecordEntryCaptureException implements Exception {
  RecordEntryCaptureException(this.message);
  final String message;

  @override
  String toString() => message;
}