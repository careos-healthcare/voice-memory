import 'dart:async';

import 'package:flutter/foundation.dart';

enum RecordingState { idle, listening, paused, silenceDetected }

/// Partial results and sound levels from a speech recognizer.
abstract class LiveSpeechEngine {
  Future<void> start({
    required void Function(String words) onPartial,
    required void Function(double level) onLevel,
  });

  Future<void> pause();

  Future<void> stop();
}

/// Placeholder until native speech-to-text is the only recognizer.
/// Callers inject a [LiveSpeechEngine] when a partial transcript is available.
class SpeechToTextEngine implements LiveSpeechEngine {
  static const silenceWindow = Duration(milliseconds: 2500);

  @override
  Future<void> start({
    required void Function(String words) onPartial,
    required void Function(double level) onLevel,
  }) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {}
}

class LiveSpeechController extends ChangeNotifier {
  LiveSpeechController({LiveSpeechEngine? engine, this.silenceWindow = const Duration(milliseconds: 2500)})
    : _engine = engine ?? SpeechToTextEngine();

  final LiveSpeechEngine _engine;
  final Duration silenceWindow;

  RecordingState _state = RecordingState.idle;
  String _transcript = '';
  Timer? _silenceTimer;
  var _disposed = false;

  RecordingState get state => _state;
  String get transcript => _transcript;

  Future<void> startListening() async {
    if (_disposed || _state == RecordingState.listening) return;
    _setState(RecordingState.listening);
    await _engine.start(onPartial: _onPartial, onLevel: _onLevel);
  }

  Future<void> pauseListening() async {
    if (_disposed || _state != RecordingState.listening) return;
    _silenceTimer?.cancel();
    _setState(RecordingState.paused);
    await _engine.pause();
  }

  Future<void> stopListening() async {
    if (_disposed) return;
    _silenceTimer?.cancel();
    _setState(RecordingState.idle);
    await _engine.stop();
  }

  void _onPartial(String words) {
    if (_disposed || words == _transcript) return;
    _transcript = words;
    notifyListeners();
  }

  void _onLevel(double level) {
    if (_disposed || _state != RecordingState.listening) return;
    if (level > 0) {
      _silenceTimer?.cancel();
      _silenceTimer = null;
      return;
    }
    _silenceTimer ??= Timer(silenceWindow, () {
      if (_disposed || _state != RecordingState.listening) return;
      _setState(RecordingState.silenceDetected);
    });
  }

  void _setState(RecordingState next) {
    if (_state == next) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _silenceTimer?.cancel();
    unawaited(_engine.stop());
    super.dispose();
  }
}
