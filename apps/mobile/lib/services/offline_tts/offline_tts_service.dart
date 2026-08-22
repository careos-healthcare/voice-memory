import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/audio/playback_service.dart';
import 'package:archiveme_mobile/services/offline_tts/offline_tts_backend.dart';
import 'package:archiveme_mobile/services/offline_tts/offline_tts_config.dart';
import 'package:archiveme_mobile/services/offline_tts/sherpa_onnx_tts_backend.dart';
import 'package:archiveme_mobile/services/offline_tts/stub_offline_tts_backend.dart';

/// Loads an ONNX voice model and streams PCM chunks into [PlaybackService].
final class OfflineTtsService {
  OfflineTtsService({
    OfflineTtsBackend? backend,
    PlaybackService? playback,
    OfflineTtsProgressCallback? onPcmChunk,
  })  : _backend = backend ?? _defaultBackend(),
        _playback = playback,
        _onPcmChunk = onPcmChunk;

  final OfflineTtsBackend _backend;
  PlaybackService? _playback;
  final OfflineTtsProgressCallback? _onPcmChunk;

  /// Attaches a [PlaybackService] configured for [sampleRateHz] after [loadModel].
  void bindPlayback(PlaybackService playback) {
    _playback = playback;
  }

  OfflineTtsConfig? _config;
  StreamSubscription<OfflineTtsPcmChunk>? _activeSynthesis;
  Completer<OfflineTtsSpeakResult>? _activeSpeakCompleter;
  DateTime? _activeSpeakStartedAt;
  var _activeChunkCount = 0;
  var _activeTotalPcmBytes = 0;
  var _activeSampleRateHz = 0;
  var _speakGeneration = 0;

  bool get isLoaded => _backend.isLoaded;

  int get sampleRateHz => _backend.sampleRateHz;

  int get numSpeakers => _backend.numSpeakers;

  static OfflineTtsBackend _defaultBackend() {
    if (offlineTtsNativeRuntimeSupported()) {
      return SherpaOnnxTtsBackend();
    }
    return StubOfflineTtsBackend();
  }

  /// Builds a [PlaybackService] whose live PCM sample rate matches [sampleRateHz].
  static PlaybackService createPlayback({
    required int sampleRateHz,
    bool testMode = false,
  }) {
    return PlaybackService.create(
      testMode: testMode,
      livePcmSampleRateHz: sampleRateHz,
    );
  }

  /// Creates a service when the VITS model and token files exist.
  static Future<OfflineTtsService?> tryCreate({
    required String modelPath,
    required String tokensPath,
    String lexiconPath = '',
    String dataDir = '',
    OfflineTtsBackend? backend,
    PlaybackService? playback,
    OfflineTtsProgressCallback? onPcmChunk,
  }) async {
    for (final path in [
      modelPath,
      tokensPath,
      if (lexiconPath.isNotEmpty) lexiconPath,
      if (dataDir.isNotEmpty) dataDir,
    ]) {
      if (!await File(path).exists()) {
        return null;
      }
    }

    final service = OfflineTtsService(
      backend: backend,
      playback: playback,
      onPcmChunk: onPcmChunk,
    );
    await service.loadModel(
      OfflineTtsConfig(
        vitsModelPath: modelPath,
        tokensPath: tokensPath,
        lexiconPath: lexiconPath,
        dataDir: dataDir,
      ),
    );
    return service;
  }

  Future<void> loadModel(OfflineTtsConfig config) async {
    _config = config;
    await _backend.load(config);
  }

  /// Synthesizes [text] and streams PCM16 chunks to playback as they are generated.
  Future<OfflineTtsSpeakResult> speak(
    String text, {
    int? speakerId,
    double? speed,
    bool bargeIn = true,
  }) async {
    await stop(bargeIn: bargeIn);
    final generation = _speakGeneration;

    final playback = _playback;
    if (playback != null) {
      await playback.prepareLiveSession();
    }

    final startedAt = DateTime.now();
    _activeSpeakStartedAt = startedAt;
    _activeChunkCount = 0;
    _activeTotalPcmBytes = 0;
    _activeSampleRateHz = _backend.sampleRateHz;

    final completer = Completer<OfflineTtsSpeakResult>();
    _activeSpeakCompleter = completer;

    void completeActiveSpeak() {
      if (completer.isCompleted) {
        return;
      }
      completer.complete(
        OfflineTtsSpeakResult(
          sampleRateHz: _activeSampleRateHz,
          totalPcmBytes: _activeTotalPcmBytes,
          chunkCount: _activeChunkCount,
          duration: DateTime.now().difference(startedAt),
        ),
      );
    }

    _activeSynthesis = _backend
        .synthesize(
          OfflineTtsSpeakRequest(
            text: text,
            speakerId: speakerId,
            speed: speed,
          ),
        )
        .listen(
      (chunk) {
        if (generation != _speakGeneration) {
          return;
        }

        _activeSampleRateHz = chunk.sampleRateHz;
        if (chunk.pcmBytes.isNotEmpty) {
          _activeChunkCount++;
          _activeTotalPcmBytes += chunk.pcmBytes.length;
          _onPcmChunk?.call(chunk);
          playback?.feedLivePcm(chunk.pcmBytes);
        }

        if (chunk.isFinal) {
          completeActiveSpeak();
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      },
      onDone: completeActiveSpeak,
      cancelOnError: true,
    );

    return completer.future.whenComplete(() {
      if (identical(_activeSpeakCompleter, completer)) {
        _activeSpeakCompleter = null;
        _activeSpeakStartedAt = null;
      }
    });
  }

  /// Stops active synthesis and optionally flushes queued playback PCM.
  Future<void> stop({bool bargeIn = true}) async {
    _speakGeneration++;

    final completer = _activeSpeakCompleter;
    final startedAt = _activeSpeakStartedAt;
    if (completer != null && !completer.isCompleted) {
      completer.complete(
        OfflineTtsSpeakResult(
          sampleRateHz: _activeSampleRateHz,
          totalPcmBytes: _activeTotalPcmBytes,
          chunkCount: _activeChunkCount,
          duration: DateTime.now().difference(startedAt ?? DateTime.now()),
        ),
      );
    }
    _activeSpeakCompleter = null;
    _activeSpeakStartedAt = null;

    await _activeSynthesis?.cancel();
    _activeSynthesis = null;

    final backend = _backend;
    if (backend is SherpaOnnxTtsBackend) {
      backend.requestCancel();
    } else if (backend is StubOfflineTtsBackend) {
      backend.requestCancel();
    }

    if (bargeIn) {
      await _playback?.flushLivePcm();
    }
  }

  Future<void> dispose() async {
    await stop();
    _config = null;
    await _backend.dispose();
  }
}
