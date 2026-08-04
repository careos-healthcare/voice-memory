import 'dart:math';

typedef RetryRandomDouble = double Function();

class RetryPolicy {
  final int maxAttempts;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffFactor;
  final RetryRandomDouble? randomDouble;

  const RetryPolicy({
    this.maxAttempts = 5,
    this.initialDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(minutes: 5),
    this.backoffFactor = 2.0,
    this.randomDouble,
  });

  /// Calculates delay with full jitter for attempt [attemptNumber] (1-indexed).
  Duration calculateDelay(int attemptNumber) {
    if (attemptNumber <= 0) return Duration.zero;

    final exponentialMs =
        initialDelay.inMilliseconds * pow(backoffFactor, attemptNumber - 1);
    final cappedMs = min(
      exponentialMs.toDouble(),
      maxDelay.inMilliseconds.toDouble(),
    );

    // Full jitter randomizes delay between 0 and calculated capped ceiling.
    final jitter = (randomDouble ?? Random().nextDouble)();
    if (jitter < 0 || jitter >= 1) {
      throw StateError('Retry jitter must be in the range [0, 1).');
    }
    final jitteredMs = jitter * cappedMs;
    return Duration(milliseconds: jitteredMs.toInt());
  }

  bool shouldRetry(int attemptCount) => attemptCount < maxAttempts;
}
