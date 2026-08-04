import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

abstract interface class AudioDigestSpeaker {
  Future<void> initialize({
    required VoidCallback onStarted,
    required VoidCallback onCompleted,
    required ValueChanged<String> onError,
  });

  Future<void> speak(String narrative);

  Future<void> stop();

  Future<void> dispose();
}

/// Native text-to-speech adapter used by archive audio digests.
class FlutterTtsAudioDigestSpeaker implements AudioDigestSpeaker {
  FlutterTtsAudioDigestSpeaker({FlutterTts? textToSpeech})
    : _textToSpeech = textToSpeech ?? FlutterTts();

  final FlutterTts _textToSpeech;

  @override
  Future<void> initialize({
    required VoidCallback onStarted,
    required VoidCallback onCompleted,
    required ValueChanged<String> onError,
  }) async {
    _textToSpeech
      ..setStartHandler(onStarted)
      ..setCompletionHandler(onCompleted)
      ..setCancelHandler(onCompleted)
      ..setErrorHandler((message) => onError(message.toString()));
    await _textToSpeech.setLanguage('en-US');
    await _textToSpeech.setSpeechRate(0.46);
    await _textToSpeech.setPitch(1);
    await _textToSpeech.awaitSpeakCompletion(true);
  }

  @override
  Future<void> speak(String narrative) async {
    await _textToSpeech.stop();
    await _textToSpeech.speak(narrative);
  }

  @override
  Future<void> stop() async {
    await _textToSpeech.stop();
  }

  @override
  Future<void> dispose() => stop();
}
