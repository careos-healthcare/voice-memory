import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/services/offline_tts/offline_tts_backend.dart';
import 'package:archiveme_mobile/services/offline_tts/offline_tts_config.dart';
import 'package:archiveme_mobile/services/offline_tts/offline_tts_pcm_converter.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// ONNX offline TTS via `package:sherpa_onnx`.
final class SherpaOnnxTtsBackend implements OfflineTtsBackend {
  SherpaOnnxTtsBackend({this.onFloatChunk});

  final OfflineTtsFloatChunkCallback? onFloatChunk;

  OfflineTtsConfig? _config;
  sherpa.OfflineTts? _tts;
  var _bindingsInitialized = false;
  var _cancelRequested = false;

  @override
  bool get isLoaded => _tts != null;

  @override
  int get sampleRateHz => _tts?.sampleRate ?? 0;

  @override
  int get numSpeakers => _tts?.numSpeakers ?? 0;

  @override
  Future<void> load(OfflineTtsConfig config) async {
    await dispose();
    _ensureModelPathsExist(config);

    if (!_bindingsInitialized) {
      sherpa.initBindings();
      _bindingsInitialized = true;
    }

    final sherpaConfig = sherpa.OfflineTtsConfig(
      model: sherpa.OfflineTtsModelConfig(
        vits: sherpa.OfflineTtsVitsModelConfig(
          model: config.vitsModelPath,
          tokens: config.tokensPath,
          lexicon: config.lexiconPath,
          dataDir: config.dataDir,
          noiseScale: config.noiseScale,
          noiseScaleW: config.noiseScaleW,
          lengthScale: config.lengthScale,
        ),
        numThreads: config.numThreads,
        debug: config.debug,
        provider: config.provider,
      ),
      silenceScale: config.silenceScale,
    );

    _config = config;
    _tts = sherpa.OfflineTts(sherpaConfig);
  }

  @override
  Stream<OfflineTtsPcmChunk> synthesize(OfflineTtsSpeakRequest request) {
    final tts = _tts;
    final config = _config;
    if (tts == null || config == null) {
      throw StateError('SherpaOnnxTtsBackend.load must be called first.');
    }

    final trimmed = request.text.trim();
    if (trimmed.isEmpty) {
      throw OfflineTtsException('Cannot synthesize empty text.');
    }

    final controller = StreamController<OfflineTtsPcmChunk>();
    _cancelRequested = false;

    Future<void> run() async {
      try {
        final generationConfig = sherpa.OfflineTtsGenerationConfig(
          sid: request.speakerId ?? config.speakerId,
          speed: request.speed ?? config.speed,
          silenceScale: config.silenceScale,
        );

        final audio = tts.generateWithConfig(
          text: trimmed,
          config: generationConfig,
          onProgress: (samples, progress) {
            if (_cancelRequested) {
              return 1;
            }
            if (samples.isEmpty) {
              return 0;
            }

            onFloatChunk?.call(samples);
            final pcmBytes = float32SamplesToPcm16LeBytes(samples);
            if (!controller.isClosed) {
              controller.add(
                OfflineTtsPcmChunk(
                  pcmBytes: pcmBytes,
                  sampleRateHz: tts.sampleRate,
                  progress: progress.clamp(0.0, 1.0),
                ),
              );
            }
            return 0;
          },
        );

        if (!controller.isClosed) {
          controller.add(
            OfflineTtsPcmChunk(
              pcmBytes: const [],
              sampleRateHz: audio.sampleRate == 0 ? tts.sampleRate : audio.sampleRate,
              progress: 1,
              isFinal: true,
            ),
          );
          await controller.close();
        }
      } catch (error, stackTrace) {
        if (!controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      }
    }

    unawaited(run());
    return controller.stream;
  }

  void requestCancel() {
    _cancelRequested = true;
  }

  @override
  Future<void> dispose() async {
    _config = null;
    _tts?.free();
    _tts = null;
    _cancelRequested = false;
  }

  void _ensureModelPathsExist(OfflineTtsConfig config) {
    for (final path in [
      config.vitsModelPath,
      config.tokensPath,
      if (config.lexiconPath.isNotEmpty) config.lexiconPath,
      if (config.dataDir.isNotEmpty) config.dataDir,
    ]) {
      final kind = FileSystemEntity.typeSync(path);
      if (kind == FileSystemEntityType.notFound) {
        throw OfflineTtsException('Offline TTS asset missing: $path');
      }
    }
  }
}

/// Returns true when sherpa-onnx native bindings are likely available.
bool offlineTtsNativeRuntimeSupported() {
  if (Platform.environment.containsKey('FLUTTER_TEST')) {
    return false;
  }
  return Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isLinux ||
      Platform.isWindows;
}
