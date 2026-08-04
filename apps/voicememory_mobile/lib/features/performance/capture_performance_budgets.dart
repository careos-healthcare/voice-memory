import 'capture_span.dart';

/// Capture latency budgets, each derived from a measurement rather than a wish.
///
/// Every value comes from the `measured spans` group in
/// `test/capture_performance_test.dart`, run four times on the host Dart VM
/// under `flutter test` (Flutter 3.44.6 / Dart 3.12.2, Apple M2 Pro, macOS 26.1,
/// debug semantics, no device). `docs/current/PERFORMANCE_REPORT.md` records the
/// raw samples per run, the environment, and what the harness contributes.
///
/// A budget is the catalogued band boundary at or immediately above the worst
/// measured p95, so a regression trips the guard before it could change the band
/// a user's session reports. No budget here claims a physical-device number:
/// none was measured.
abstract final class CapturePerformanceBudgets {
  /// Measured host p50 10-15 ms, p95 200-255 ms. Every p95 sample is the first
  /// mount in the process, which pays one-time JIT warm-up.
  static const Duration appLaunchToRecordInteractive = Duration(
    milliseconds: 500,
  );

  /// Measured host p50 0 ms, p95 2-3 ms: the tap only awaits the recorder.
  static const Duration recordTapToRecording = Duration(milliseconds: 200);

  /// Measured host p50 29-39 ms, p95 116-180 ms for the encrypted vault write
  /// plus the journal commit.
  static const Duration stopTapToEncryptedPersistence = Duration(
    milliseconds: 200,
  );

  /// Measured host p50 18-21 ms, p95 29-37 ms between the committed save and the
  /// transcript being on screen.
  static const Duration saveToTranscriptVisible = Duration(milliseconds: 200);

  /// Measured host p50 18-21 ms, p95 29-37 ms, from the same samples: the
  /// observation is already on the saved entry, so it paints with the
  /// transcript.
  static const Duration saveToFirstValidObservation = Duration(
    milliseconds: 200,
  );

  static Duration budgetFor(CaptureSpan span) => switch (span) {
    CaptureSpan.appLaunchToRecordInteractive => appLaunchToRecordInteractive,
    CaptureSpan.recordTapToRecording => recordTapToRecording,
    CaptureSpan.stopTapToEncryptedPersistence => stopTapToEncryptedPersistence,
    CaptureSpan.saveToTranscriptVisible => saveToTranscriptVisible,
    CaptureSpan.saveToFirstValidObservation => saveToFirstValidObservation,
  };

  static bool withinBudget(CaptureSpan span, Duration measured) =>
      measured <= budgetFor(span);
}
