import 'package:archiveme_mobile/features/activation/weekly_archive_review.dart';
import 'package:archiveme_mobile/features/review_ritual/view_ritual_copy.dart';
import 'package:archiveme_mobile/features/review_ritual/view_ritual_gates.dart';
import 'package:archiveme_mobile/features/review_ritual/view_ritual_models.dart';

/// Deterministic review ritual summaries — metadata only.
class ReviewRitualEngine {
  const ReviewRitualEngine();

  ReviewRitualResult build(ReviewRitualInput input) {
    if (input.sampleMode) {
      return _sampleResult(input.weeklyReviewAvailable);
    }

    final insufficientEntries =
        input.realSavedMomentCount < 3 && !input.weeklyReviewAvailable;
    final showOnArchiveHome = ReviewRitualGates.showOnArchiveHome(
      realSavedMomentCount: input.realSavedMomentCount,
      weeklyReviewAvailable: input.weeklyReviewAvailable,
      sampleMode: input.sampleMode,
    );
    final ritual = input.ritual;
    final hasRitual = ritual?.isConfigured == true;

    if (!showOnArchiveHome) {
      return ReviewRitualResult.empty;
    }

    final summaryLabel = hasRitual
        ? ReviewRitualCopy.ritualSummary(
            daypart: ritual!.selectedDaypart,
            focusRepeated: ritual.focusRepeated,
            focusChanged: ritual.focusChanged,
            focusWatchNext: ritual.focusWatchNext,
          )
        : ReviewRitualCopy.chooseIntro;

    final helperText = insufficientEntries
        ? ReviewRitualCopy.insufficientHelper
        : ReviewRitualCopy.noRemindersLine;

    final weeklyReviewReady =
        input.weeklyReviewAvailable && !insufficientEntries;

    return ReviewRitualResult(
      hasRitual: hasRitual,
      showOnArchiveHome: true,
      hasCard: true,
      summaryLabel: summaryLabel,
      helperText: helperText,
      privacyLine: ReviewRitualCopy.noRemindersLine,
      cardHeadline: hasRitual
          ? ReviewRitualCopy.cardHeadlineSet
          : ReviewRitualCopy.cardHeadlineUnset,
      cardSummary: hasRitual
          ? ReviewRitualCopy.cardSummarySet
          : ReviewRitualCopy.cardSummaryUnset,
      primaryCtaLabel: weeklyReviewReady
          ? ReviewRitualCopy.openWeeklyReviewCta
          : hasRitual
          ? ReviewRitualCopy.openReviewRitualCta
          : ReviewRitualCopy.chooseReviewTimeCta,
      primaryRoute: weeklyReviewReady
          ? WeeklyArchiveReviewNavigation.route
          : ReviewRitualCopy.route,
      secondaryCtaLabel: ReviewRitualCopy.openReviewRitualCta,
      secondaryRoute: ReviewRitualCopy.route,
      weeklyReviewAvailable: input.weeklyReviewAvailable,
      insufficientEntries: insufficientEntries,
    );
  }

  ReviewRitualResult _sampleResult(bool weeklyReviewAvailable) {
    return ReviewRitualResult(
      hasRitual: true,
      showOnArchiveHome: false,
      hasCard: true,
      summaryLabel: ReviewRitualCopy.ritualSummary(
        daypart: ReviewRitualDaypart.evening,
        focusRepeated: true,
        focusChanged: true,
        focusWatchNext: false,
      ),
      helperText: ReviewRitualCopy.noRemindersLine,
      privacyLine: ReviewRitualCopy.noRemindersLine,
      cardHeadline: ReviewRitualCopy.eyebrow,
      cardSummary: ReviewRitualCopy.screenshotSummary,
      primaryCtaLabel: ReviewRitualCopy.openReviewRitualCta,
      primaryRoute: ReviewRitualCopy.route,
      secondaryCtaLabel: ReviewRitualCopy.openWeeklyReviewCta,
      secondaryRoute: WeeklyArchiveReviewNavigation.route,
      weeklyReviewAvailable: weeklyReviewAvailable,
      insufficientEntries: false,
    );
  }
}