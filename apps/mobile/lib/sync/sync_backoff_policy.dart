/// Exponential backoff for sync retries (outbox rows and push attempts).
class SyncBackoffPolicy {
  const SyncBackoffPolicy({
    this.initialDelay = const Duration(milliseconds: 250),
    this.maxDelay = const Duration(seconds: 8),
    this.maxAttempts = 5,
    this.multiplier = 2,
  });

  final Duration initialDelay;
  final Duration maxDelay;
  final int maxAttempts;
  final int multiplier;

  Duration delayForAttempt(int attempt) {
    if (attempt <= 1) return initialDelay;
    final scaledMs =
        initialDelay.inMilliseconds * _pow(multiplier, attempt - 1);
    final cappedMs = scaledMs > maxDelay.inMilliseconds
        ? maxDelay.inMilliseconds
        : scaledMs;
    return Duration(milliseconds: cappedMs);
  }

  DateTime scheduleAfterAttempt(int attempt, {DateTime? from}) {
    final base = from ?? DateTime.now().toUtc();
    return base.add(delayForAttempt(attempt));
  }

  bool hasAttemptsRemaining(int attemptCount) => attemptCount < maxAttempts;

  static int _pow(int base, int exponent) {
    var value = 1;
    for (var i = 0; i < exponent; i++) {
      value *= base;
    }
    return value;
  }
}
