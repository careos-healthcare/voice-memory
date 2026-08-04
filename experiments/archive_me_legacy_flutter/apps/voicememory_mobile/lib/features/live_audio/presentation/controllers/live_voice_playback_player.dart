import 'dart:async';

import 'package:flutter/foundation.dart';

enum PlaybackState { stopped, playing, paused }

class LiveVoicePlaybackPlayer extends ChangeNotifier {
  PlaybackState _state = PlaybackState.stopped;
  Duration _position = Duration.zero;
  Duration _totalDuration = Duration.zero;
  Timer? _ticker;

  PlaybackState get state => _state;
  Duration get position => _position;
  Duration get totalDuration => _totalDuration;
  bool get isPlaying => _state == PlaybackState.playing;

  static Duration durationForPcm16LeBytes(
    List<int> pcmBytes, {
    int sampleRateHz = 24000,
    int numChannels = 1,
  }) {
    if (pcmBytes.isEmpty || sampleRateHz <= 0 || numChannels <= 0) {
      return Duration.zero;
    }
    final bytesPerSample = 2 * numChannels;
    final sampleCount = pcmBytes.length ~/ bytesPerSample;
    if (sampleCount <= 0) return Duration.zero;
    final microseconds = (sampleCount / sampleRateHz * 1000000).round();
    return Duration(microseconds: microseconds);
  }

  void loadSession({required Duration totalDuration}) {
    _totalDuration = totalDuration;
    _position = Duration.zero;
    _state = PlaybackState.stopped;
    notifyListeners();
  }

  void updateTotalDuration(Duration totalDuration) {
    if (totalDuration <= _totalDuration) return;
    _totalDuration = totalDuration;
    if (_position > _totalDuration) {
      _position = _totalDuration;
    }
    notifyListeners();
  }

  void play() {
    if (_totalDuration == Duration.zero) return;
    _state = PlaybackState.playing;
    notifyListeners();

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_position >= _totalDuration) {
        pause();
        _position = _totalDuration;
      } else {
        _position += const Duration(milliseconds: 50);
      }
      notifyListeners();
    });
  }

  void pause() {
    _state = PlaybackState.paused;
    _ticker?.cancel();
    notifyListeners();
  }

  void seek(Duration newPosition) {
    if (newPosition <= Duration.zero) {
      _position = Duration.zero;
    } else if (newPosition >= _totalDuration) {
      _position = _totalDuration;
    } else {
      _position = newPosition;
    }
    notifyListeners();
  }

  void stop() {
    _state = PlaybackState.stopped;
    _position = Duration.zero;
    _ticker?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
