import 'app_feature_flags.dart';
import 'screenshot_mode.dart';

/// QA previews for the archive differentiation layer.
///
/// `--dart-define=ARCHIVE_BELIEF_PREVIEW=true`
/// `--dart-define=EVIDENCE_TIMELINE_PREVIEW=true`
/// `--dart-define=WEEKLY_REVIEW_PREVIEW=true`
abstract class ArchiveDifferentiationPreview {
  ArchiveDifferentiationPreview._();

  static const bool archiveBelief = AppFeatureFlags.archiveBeliefPreview;

  static const bool evidenceTimeline = AppFeatureFlags.evidenceTimelinePreview;

  static const bool weeklyReview = AppFeatureFlags.weeklyReviewPreview;

  static bool get forceArchiveBelief =>
      archiveBelief ||
      (ScreenshotMode.enabled &&
          ScreenshotMode.screenshotJourneyReflectionCount >= 2);

  static bool get forceWeeklyReview =>
      weeklyReview ||
      (ScreenshotMode.enabled &&
          ScreenshotMode.screenshotJourneyReflectionCount >= 3);
}
