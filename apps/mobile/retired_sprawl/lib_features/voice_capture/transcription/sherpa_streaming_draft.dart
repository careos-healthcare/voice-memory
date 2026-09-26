import 'dart:typed_data';

import 'package:archiveme_mobile/features/voice_capture/transcription/streaming_speech_model.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

/// Streaming Zipformer fed from the recorder's PCM. No microphone of its own.
class SherpaStreamingDraft {
  OnlineRecognizer? _recognizer;
  OnlineStream? _stream;
  var _last = '';

  bool start({StreamingSpeechModel? model}) {
    final files = model;
    if (files == null || !files.isReady) return false;
    try {
      initBindings();
      final recognizer = OnlineRecognizer(
        OnlineRecognizerConfig(
          model: OnlineModelConfig(
            transducer: OnlineTransducerModelConfig(
              encoder: files.pathFor('encoder.onnx'),
              decoder: files.pathFor('decoder.onnx'),
              joiner: files.pathFor('joiner.onnx'),
            ),
            tokens: files.pathFor('tokens.txt'),
            modelType: 'zipformer2',
          ),
        ),
      );
      _recognizer = recognizer;
      _stream = recognizer.createStream();
      _last = '';
      return true;
    } on Object {
      stop();
      return false;
    }
  }

  /// Returns a new partial, or null when the text has not changed.
  String? acceptPcm16(Uint8List pcm) {
    final recognizer = _recognizer;
    final stream = _stream;
    if (recognizer == null || stream == null || pcm.length < 2) return null;
    final samples = Float32List(pcm.length ~/ 2);
    for (var i = 0; i < samples.length; i++) {
      final lo = pcm[i * 2];
      final hi = pcm[i * 2 + 1];
      var value = lo | (hi << 8);
      if (value >= 0x8000) value -= 0x10000;
      samples[i] = value / 32768.0;
    }
    stream.acceptWaveform(samples: samples, sampleRate: 16000);
    while (recognizer.isReady(stream)) {
      recognizer.decode(stream);
    }
    final text = recognizer.getResult(stream).text.trim();
    if (text.isEmpty || text == _last) return null;
    _last = text;
    return text;
  }

  void stop() {
    _stream?.free();
    _stream = null;
    _recognizer?.free();
    _recognizer = null;
    _last = '';
  }
}
