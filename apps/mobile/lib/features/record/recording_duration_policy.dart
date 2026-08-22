import 'package:archiveme_mobile/product/consumer_ui_copy.dart';

/// Low-friction voice capture standard for the main Record flow.
abstract final class RecordingDurationPolicy {
  RecordingDurationPolicy._();

  /// Local safety ceiling applied equally to every user-owned recording.
  static const maxSeconds = 300;
  static String get processingLabel => ConsumerUiCopy.recordSubtitle;

  static bool shouldAutoStop(
    int elapsedSeconds, {
    int maxDurationSeconds = maxSeconds,
  }) => elapsedSeconds >= maxDurationSeconds;
}