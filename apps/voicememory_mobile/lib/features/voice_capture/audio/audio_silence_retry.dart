/// Pure policy for iOS physical silence retry during capture.
abstract class AudioSilenceRetryPolicy {
  AudioSilenceRetryPolicy._();

  static const double retryThresholdDb = -50;
  static const Duration initialWindow = Duration(seconds: 2);

  static bool shouldRetryInitialSilence({
    required bool isIosPhysical,
    required bool retryAlreadyAttempted,
    required double maxDbInInitialWindow,
    double thresholdDb = retryThresholdDb,
  }) {
    if (!isIosPhysical || retryAlreadyAttempted) return false;
    if (!maxDbInInitialWindow.isFinite) return true;
    return maxDbInInitialWindow < thresholdDb;
  }

  static bool shouldSkipRetry({
    required bool isIosPhysical,
    required bool retryAlreadyAttempted,
    required double maxDbInInitialWindow,
    double thresholdDb = retryThresholdDb,
  }) {
    return !shouldRetryInitialSilence(
      isIosPhysical: isIosPhysical,
      retryAlreadyAttempted: retryAlreadyAttempted,
      maxDbInInitialWindow: maxDbInInitialWindow,
      thresholdDb: thresholdDb,
    );
  }
}
