import 'dart:io';

import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/whisper_kit_channel.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

/// On-device Whisper for a finished recording.
///
/// iOS is asked first through [WhisperKitChannel]. A WAV file with sherpa-onnx
/// Whisper weights under documents/`sherpa_asr` is the second reader. Anything
/// else returns null so the router can use the cloud endpoint.
class OnDeviceWhisperEngine {
  OnDeviceWhisperEngine({WhisperKitChannel? channel, this.modelDirectory})
    : _channel = channel ?? WhisperKitChannel();

  final WhisperKitChannel _channel;

  /// Test seam for the sherpa model directory.
  final Future<Directory?> Function()? modelDirectory;

  Future<bool> iosModelReady() async {
    try {
      return await _channel.modelReady();
    } on Object {
      return false;
    }
  }

  Future<bool> sherpaModelsPresent() async {
    final models = await _loadModels();
    return models != null;
  }

  Future<String?> transcribe(
    File audioFile,
    ConfirmedSpeechLocale locale,
  ) async {
    if (!audioFile.existsSync()) return null;
    try {
      final fromChannel = await _channel.transcribeFile(
        audioPath: audioFile.path,
        localeIdentifier: locale.identifier,
      );
      if (fromChannel != null) return fromChannel;
    } on Object {
      // The channel is absent on desktop tests and on builds whose engine
      // is not linked. Sherpa below is the other on-device reader.
    }
    if (!locale.identifier.toLowerCase().startsWith('en')) return null;
    if (p.extension(audioFile.path).toLowerCase() != '.wav') return null;
    final models = await _loadModels();
    if (models == null) return null;
    try {
      return _recognizeWav(audioFile.path, models);
    } on Object {
      return null;
    }
  }

  Future<_SherpaWhisperModels?> _loadModels() async {
    final directory = await _modelDirectory();
    if (directory == null || !directory.existsSync()) return null;
    final encoder = File(p.join(directory.path, 'encoder.onnx'));
    final decoder = File(p.join(directory.path, 'decoder.onnx'));
    final tokens = File(p.join(directory.path, 'tokens.txt'));
    if (!encoder.existsSync() ||
        !decoder.existsSync() ||
        !tokens.existsSync()) {
      return null;
    }
    return _SherpaWhisperModels(
      encoder: encoder.path,
      decoder: decoder.path,
      tokens: tokens.path,
    );
  }

  Future<Directory?> _modelDirectory() async {
    final override = modelDirectory;
    if (override != null) return override();
    try {
      final root = await getApplicationDocumentsDirectory();
      return Directory(p.join(root.path, 'sherpa_asr'));
    } on Object {
      return null;
    }
  }

  String? _recognizeWav(String wavPath, _SherpaWhisperModels models) {
    initBindings();
    final recognizer = OfflineRecognizer(
      OfflineRecognizerConfig(
        model: OfflineModelConfig(
          whisper: OfflineWhisperModelConfig(
            encoder: models.encoder,
            decoder: models.decoder,
            language: 'en',
            task: 'transcribe',
          ),
          tokens: models.tokens,
          modelType: 'whisper',
          debug: false,
        ),
      ),
    );
    try {
      final wave = readWave(wavPath);
      if (wave.samples.isEmpty || wave.sampleRate <= 0) return null;
      final stream = recognizer.createStream();
      try {
        stream.acceptWaveform(
          samples: wave.samples,
          sampleRate: wave.sampleRate,
        );
        recognizer.decode(stream);
        final text = recognizer.getResult(stream).text.trim();
        if (text.isEmpty) return null;
        return text;
      } finally {
        stream.free();
      }
    } finally {
      recognizer.free();
    }
  }
}

class _SherpaWhisperModels {
  const _SherpaWhisperModels({
    required this.encoder,
    required this.decoder,
    required this.tokens,
  });

  final String encoder;
  final String decoder;
  final String tokens;
}
