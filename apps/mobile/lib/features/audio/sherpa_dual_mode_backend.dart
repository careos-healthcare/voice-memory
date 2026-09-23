import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/features/audio/dual_mode_audio_timing.dart';
import 'package:archiveme_mobile/features/capture/vad/webrtc_vad_engine.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

/// Model files for the sherpa-onnx passive recognizer and interactive VAD.
class SherpaDualModeConfig {
  const SherpaDualModeConfig({
    this.sileroVadModel = '',
    this.tokens = '',
    this.encoder = '',
    this.decoder = '',
    this.joiner = '',
  });

  final String sileroVadModel;
  final String tokens;
  final String encoder;
  final String decoder;
  final String joiner;

  bool get hasVadModel =>
      sileroVadModel.isNotEmpty && File(sileroVadModel).existsSync();

  bool get hasRecognizer =>
      tokens.isNotEmpty &&
      encoder.isNotEmpty &&
      decoder.isNotEmpty &&
      joiner.isNotEmpty &&
      File(tokens).existsSync() &&
      File(encoder).existsSync() &&
      File(decoder).existsSync() &&
      File(joiner).existsSync();
}

/// Optional sherpa-onnx VAD and streaming recognizer for the dual-mode engine.
class SherpaDualModeBinding {
  const SherpaDualModeBinding({this.isSpeech, this.transcribe});

  final bool Function(Float32List samples)? isSpeech;
  final Future<String> Function(Float32List samples)? transcribe;
}

SherpaDualModeBinding bindSherpaDualMode([
  SherpaDualModeConfig config = const SherpaDualModeConfig(),
]) {
  final vad = SherpaOnnxSpeechProbe.tryCreate(config);
  final recognizer = SherpaOnnxStreamTranscriber.tryCreate(config);
  return SherpaDualModeBinding(
    isSpeech: vad?.isSpeech,
    transcribe: recognizer?.transcribe,
  );
}

/// Energy VAD used when a sherpa silero model is not installed.
abstract final class WebRtcSpeechProbe {
  static bool isSpeech(Float32List samples) {
    if (samples.isEmpty) return false;
    final pcm = Int16List(samples.length);
    for (var i = 0; i < samples.length; i++) {
      final scaled = (samples[i] * 32767).round();
      pcm[i] = scaled.clamp(-32768, 32767);
    }
    return WebRtcVadEngine.isSpeechPcm16(
      pcm,
      sampleRateHz: DualModeAudioTiming.sampleRateHz,
    );
  }
}

/// Sherpa silero VAD. A pause longer than 1.2s closes a speech segment.
class SherpaOnnxSpeechProbe {
  SherpaOnnxSpeechProbe._(this._vad);

  final VoiceActivityDetector _vad;

  static SherpaOnnxSpeechProbe? tryCreate(SherpaDualModeConfig config) {
    if (!config.hasVadModel) return null;
    try {
      initBindings();
      final pauseSeconds = DualModeAudioTiming.pause.inMilliseconds / 1000;
      final vad = VoiceActivityDetector(
        config: VadModelConfig(
          sileroVad: SileroVadModelConfig(
            model: config.sileroVadModel,
            minSilenceDuration: pauseSeconds,
          ),
          debug: false,
        ),
        bufferSizeInSeconds: DualModeAudioTiming.rollingWindow.inSeconds
            .toDouble(),
      );
      return SherpaOnnxSpeechProbe._(vad);
    } on Object {
      return null;
    }
  }

  bool isSpeech(Float32List samples) {
    _vad.acceptWaveform(samples);
    final speech = _vad.isDetected();
    while (!_vad.isEmpty()) {
      _vad.pop();
    }
    return speech;
  }

  void dispose() => _vad.free();
}

/// Streaming sherpa-onnx recognizer for a finished note or speech turn.
class SherpaOnnxStreamTranscriber {
  SherpaOnnxStreamTranscriber._(this._recognizer);

  final OnlineRecognizer _recognizer;

  static SherpaOnnxStreamTranscriber? tryCreate(SherpaDualModeConfig config) {
    if (!config.hasRecognizer) return null;
    try {
      initBindings();
      final recognizer = OnlineRecognizer(
        OnlineRecognizerConfig(
          model: OnlineModelConfig(
            transducer: OnlineTransducerModelConfig(
              encoder: config.encoder,
              decoder: config.decoder,
              joiner: config.joiner,
            ),
            tokens: config.tokens,
          ),
          rule2MinTrailingSilence:
              DualModeAudioTiming.pause.inMilliseconds / 1000,
        ),
      );
      return SherpaOnnxStreamTranscriber._(recognizer);
    } on Object {
      return null;
    }
  }

  Future<String> transcribe(Float32List samples) async {
    final stream = _recognizer.createStream();
    try {
      stream
        ..acceptWaveform(
          samples: samples,
          sampleRate: DualModeAudioTiming.sampleRateHz,
        )
        ..inputFinished();
      while (_recognizer.isReady(stream)) {
        _recognizer.decode(stream);
      }
      return _recognizer.getResult(stream).text.trim();
    } finally {
      stream.free();
    }
  }

  void dispose() => _recognizer.free();
}
