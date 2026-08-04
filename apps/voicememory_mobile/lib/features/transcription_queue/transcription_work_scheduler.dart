/// Scheduling boundary for durable transcription work.
abstract interface class TranscriptionWorkScheduler {
  Future<void> initialize();

  Future<void> schedule();
}

/// Commercial V1 retries while the app owns the foreground lifecycle.
///
/// No native background task, notification, or experimental worker is
/// registered by the shipping composition.
final class ForegroundOnlyTranscriptionScheduler
    implements TranscriptionWorkScheduler {
  const ForegroundOnlyTranscriptionScheduler();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> schedule() async {}
}
