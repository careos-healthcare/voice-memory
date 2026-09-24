import 'dart:io';

import 'package:archiveme_mobile/workers/speech_to_text/speech_to_text_worker_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

/// Model files for the on-device sherpa-onnx Whisper recognizer.
class SherpaAsrModels {
  const SherpaAsrModels({
    required this.encoder,
    required this.decoder,
    required this.tokens,
  });

  final String encoder;
  final String decoder;
  final String tokens;
}

/// Serial queue that transcribes an imported file with sherpa-onnx.
class SherpaSpeechQueue {
  SherpaSpeechQueue({
    this.modelDirectory,
    this.recognizeWav,
    this.fallback,
  });

  static final SherpaSpeechQueue instance = SherpaSpeechQueue();

  /// Directory that holds `encoder.onnx`, `decoder.onnx`, and `tokens.txt`.
  final Future<Directory?> Function()? modelDirectory;

  /// Test seam for the native recognizer. Production uses sherpa-onnx.
  final Future<String> Function(String wavPath, SherpaAsrModels models)?
  recognizeWav;

  /// Used when the sherpa models are absent or the file is not a WAV.
  final Future<void> Function(File file)? fallback;

  Future<void> _tail = Future<void>.value();

  Future<void> enqueue(File file) {
    final run = _tail.then((_) => _transcribe(file));
    _tail = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  Future<void> _transcribe(File file) async {
    final models = await _loadModels();
    final wav = p.extension(file.path).toLowerCase() == '.wav';
    if (models != null && wav) {
      try {
        final recognize = recognizeWav ?? _recognizeWithSherpa;
        await recognize(file.path, models);
        return;
      } on Object {
        // The speech worker still transcribes containers sherpa could not open.
      }
    }
    final next = fallback;
    if (next != null) {
      await next(file);
      return;
    }
    await SpeechToTextWorkerService.instance.transcribeAudioFile(file.path);
  }

  Future<SherpaAsrModels?> _loadModels() async {
    final directory = await _modelDirectory();
    if (directory == null) return null;
    final encoder = File(p.join(directory.path, 'encoder.onnx'));
    final decoder = File(p.join(directory.path, 'decoder.onnx'));
    final tokens = File(p.join(directory.path, 'tokens.txt'));
    if (!encoder.existsSync() ||
        !decoder.existsSync() ||
        !tokens.existsSync()) {
      return null;
    }
    return SherpaAsrModels(
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

  Future<String> _recognizeWithSherpa(
    String wavPath,
    SherpaAsrModels models,
  ) async {
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
      if (wave.samples.isEmpty || wave.sampleRate <= 0) {
        throw StateError('sherpa wave was empty');
      }
      final stream = recognizer.createStream();
      try {
        stream.acceptWaveform(
          samples: wave.samples,
          sampleRate: wave.sampleRate,
        );
        recognizer.decode(stream);
        return recognizer.getResult(stream).text;
      } finally {
        stream.free();
      }
    } finally {
      recognizer.free();
    }
  }
}
