import 'package:archiveme_mobile/config/screenshot_mode.dart';

/// QA previews for the archive differentiation layer.
///
/// `--dart-define=ARCHIVE_BELIEF_PREVIEW=true`
/// `--dart-define=EVIDENCE_TIMELINE_PREVIEW=true`
/// `--dart-define=WEEKLY_REVIEW_PREVIEW=true`
abstract class ArchiveDifferentiationPreview {
  ArchiveDifferentiationPreview._();

  static const bool archiveBelief = bool.fromEnvironment(
    'ARCHIVE_BELIEF_PREVIEW',
  );

  static const bool evidenceTimeline = bool.fromEnvironment(
    'EVIDENCE_TIMELINE_PREVIEW',
  );

  static const bool weeklyReview = bool.fromEnvironment(
    'WEEKLY_REVIEW_PREVIEW',
  );

  static bool get forceArchiveBelief =>
      archiveBelief ||
      (ScreenshotMode.enabled &&
          ScreenshotMode.screenshotJourneyReflectionCount >= 2);

  static bool get forceWeeklyReview =>
      weeklyReview ||
      (ScreenshotMode.enabled &&
          ScreenshotMode.screenshotJourneyReflectionCount >= 3);
}