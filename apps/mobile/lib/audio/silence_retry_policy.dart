import 'dart:async';

import 'package:archiveme_mobile/audio/hardware_audio_config.dart';

/// Stateful silence-retry policy driven exclusively by [HardwareAudioConfig].
class SilenceRetryPolicy {
  SilenceRetryPolicy(this._config);

  final HardwareAudioConfig _config;

  bool _retryAttempted = false;
  Timer? _scheduledCheck;

  Duration get initialWindow => _config.silenceRetryInitialWindow;

  double get retryThresholdDb => _config.silenceRetryThresholdDb;

  double get silentThresholdDb => _config.captureSilentThresholdDb;

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
    if (!_config.schedulesCaptureSilenceRetry) return;
    cancelScheduledCheck();
    _scheduledCheck = Timer(_config.silenceRetryInitialWindow, () {
      unawaited(onWindowElapsed());
    });
  }

  Future<bool> shouldRetryForInitialSilence({
    required double maxDbInInitialWindow,
  }) async {
    if (!await _config.captureSilenceRetryEligible()) return false;
    if (_retryAttempted) return false;
    if (!maxDbInInitialWindow.isFinite) return true;
    return maxDbInInitialWindow < _config.silenceRetryThresholdDb;
  }

  bool evaluateLikelySilent({required int sampleCount, required double maxDb}) {
    return sampleCount == 0 || maxDb < _config.captureSilentThresholdDb;
  }

  /// Marks the single allowed retry as consumed. Returns false if already used.
  bool commitRetryAttempt() {
    if (_retryAttempted) return false;
    _retryAttempted = true;
    return true;
  }
}
