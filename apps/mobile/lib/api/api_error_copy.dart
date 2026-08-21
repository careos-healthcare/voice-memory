/// Calm, consumer-facing API and connectivity error copy.
abstract final class ApiErrorCopy {
  ApiErrorCopy._();

  static const String genericFallback =
      'Something went wrong. Please try again in a moment.';

  static const String networkUnreachable =
      'ArchiveMe could not connect right now. Check your connection and try again.';

  static const String requestTimedOut =
      'That took longer than expected. Please try again.';

  static const String purchaseCancelled = 'No purchase was made.';

  static const String signInRequired = 'Sign in to continue.';

  static const String fileTooLarge =
      'This recording is too long to send. Try a shorter one.';

  static const String noSpeechDetected =
      'We did not catch any speech. Try speaking a little longer.';

  static const String tooManyRequests = 'Please wait a moment, then try again.';

  static const String serviceUnavailable =
      'ArchiveMe is temporarily unavailable. Please try again soon.';

  /// When a device cannot reach ArchiveMe — calm copy only, no setup instructions.
  static const String localDeviceConnectionHint =
      'ArchiveMe could not connect from this device. Check that you are online '
      'and try again.';
}