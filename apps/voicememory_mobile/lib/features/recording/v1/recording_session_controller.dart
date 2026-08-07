import 'dart:async';

/// Owns recording-duration ticks independently from presentation state.
class RecordingSessionController {
  int _seconds = 0;
  StreamSubscription<int>? _durationSubscription;

  int get seconds => _seconds;

  void bindDuration(
    Stream<int> duration, {
    required void Function(int) onTick,
  }) {
    unawaited(_durationSubscription?.cancel());
    _durationSubscription = duration.listen((value) {
      _seconds = value;
      onTick(value);
    });
  }

  void resetTimer() {
    _seconds = 0;
  }

  Future<void> dispose() async {
    await _durationSubscription?.cancel();
    _durationSubscription = null;
  }
}
