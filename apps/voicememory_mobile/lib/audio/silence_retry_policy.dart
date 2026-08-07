import 'dart:async';

import '../features/voice_capture/audio/audio_level_monitor.dart';
import '../features/voice_capture/audio/audio_silence_retry.dart';

/// Stateful silence-retry policy: initial capture window, dB thresholds, and
/// one-shot retry tracking for plugin capture on iOS physical devices.
class SilenceRetryPolicy {
  SilenceRetryPolicy({
    Duration initialWindow = AudioSilenceRetryPolicy.initialWindow,
    double retryThresholdDb = AudioSilenceRetryPolicy.retryThresholdDb,
    double silentThresholdDb = AudioLevelSummary.silentThresholdDb,
  }) : _initialWindow = initialWindow,
       _retryThresholdDb = retryThresholdDb,
       _silentThresholdDb = silentThresholdDb;

  final Duration _initialWindow;
  final double _retryThresholdDb;
  final double _silentThresholdDb;

  bool _retryAttempted = false;
  Timer? _scheduledCheck;

  Duration get initialWindow => _initialWindow;

  double get retryThresholdDb => _retryThresholdDb;

  double get silentThresholdDb => _silentThresholdDb;

  bool get retryAttempted => _retryAttempted;

  void resetForNewCapture() {
    _retryAttempted = false;
    cancelScheduledCheck();
  }

  void cancelScheduledCheck() {
    _scheduledCheck?.cancel();
    _scheduledCheck = null;
  }

  void dispose() => cancelScheduledCheck();

  void scheduleInitialSilenceCheck(Future<void> Function() onWindowElapsed) {
    cancelScheduledCheck();
    _scheduledCheck = Timer(_initialWindow, () {
      unawaited(onWindowElapsed());
    });
  }

  bool shouldRetryForInitialSilence({
    required bool isIosPhysical,
    required double maxDbInInitialWindow,
  }) {
    return AudioSilenceRetryPolicy.shouldRetryInitialSilence(
      isIosPhysical: isIosPhysical,
      retryAlreadyAttempted: _retryAttempted,
      maxDbInInitialWindow: maxDbInInitialWindow,
      thresholdDb: _retryThresholdDb,
    );
  }

  bool evaluateLikelySilent({required int sampleCount, required double maxDb}) {
    return sampleCount == 0 || maxDb < _silentThresholdDb;
  }

  /// Marks the single allowed retry as consumed. Returns false if already used.
  bool commitRetryAttempt() {
    if (_retryAttempted) return false;
    _retryAttempted = true;
    return true;
  }
}
