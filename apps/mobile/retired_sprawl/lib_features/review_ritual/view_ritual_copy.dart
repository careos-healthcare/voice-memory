import 'package:archiveme_mobile/features/review_ritual/view_ritual_models.dart';

/// Calm copy for local review ritual setup — no pressure or reminders.
abstract final class ReviewRitualCopy {
  ReviewRitualCopy._();

  static const route = '/review-ritual';
  static const archiveHomeRoute = '/archive-belief';
  static const weeklyReviewRoute = '/weekly-archive-review';

  static const eyebrow = 'Review ritual';
  static const screenTitle = 'Review ritual';
  static const chooseIntro =
      'Choose when you usually want to review your archive.';
  static const noRemindersLine =
      'No reminders are sent yet. This just gives your archive a rhythm.';
  static const focusIntro =
      'Your review focuses on what repeated, what changed, and what to watch next.';
  static const savedLocally = 'Saved locally.';
  static const changeAnytime = 'You can change this anytime.';

  static const chooseReviewTimeCta = 'Choose review time';
  static const openReviewRitualCta = 'Open review ritual';
  static const saveRitualCta = 'Save review ritual';
  static const openWeeklyReviewCta = 'Open weekly review';
  static const openArchiveHomeCta = 'Open Archive Home';

  static const focusRepeated = 'What repeated';
  static const focusChanged = 'What changed';
  static const focusWatchNext = 'What to watch next';

  static const daySunday = 'Sunday';
  static const daypartMorning = 'Sunday morning';
  static const daypartAfternoon = 'Sunday afternoon';
  static const daypartEvening = 'Sunday evening';

  static const insufficientHelper =
      'Save more moments first. Your ritual will be ready when there is enough to compare.';

  static const cardHeadlineUnset = 'Give your archive a weekly review rhythm.';
  static const cardSummaryUnset =
      'Choose when you usually review and what to look for.';
  static const cardHeadlineSet =
      'Your weekly review rhythm is saved locally in ArchiveMe.';
  static const cardSummarySet =
      'Your ritual stays on this device — no reminders sent yet.';

  static const supportSectionTitle = 'Review ritual';
  static const supportSectionBody =
      'Set a calm weekly review rhythm for your local archive. '
      'No push notifications or uploads.';

  static const helpSectionTitle = 'Review ritual';
  static const helpSectionBullet =
      'Open Review ritual to choose when and how you review your archive locally.';

  static const screenshotSummary =
      'Example review rhythm only — no private data.';

  static String daypartLabel(ReviewRitualDaypart daypart) => switch (daypart) {
    ReviewRitualDaypart.morning => daypartMorning,
    ReviewRitualDaypart.afternoon => daypartAfternoon,
    ReviewRitualDaypart.evening => daypartEvening,
  };

  static String focusSummary({
    required bool focusRepeated,
    required bool focusChanged,
    required bool focusWatchNext,
  }) {
    final parts = <String>[
      if (focusRepeated) ReviewRitualCopy.focusRepeated,
      if (focusChanged) ReviewRitualCopy.focusChanged,
      if (focusWatchNext) ReviewRitualCopy.focusWatchNext,
    ];
    if (parts.isEmpty) return focusIntro;
    return parts.join(', ');
  }

  static String ritualSummary({
    required ReviewRitualDaypart daypart,
    required bool focusRepeated,
    required bool focusChanged,
    required bool focusWatchNext,
  }) =>
      '${daypartLabel(daypart)} · ${focusSummary(focusRepeated: focusRepeated, focusChanged: focusChanged, focusWatchNext: focusWatchNext)}';

  static List<String> get allVisibleStrings => [
    eyebrow,
    screenTitle,
    chooseIntro,
    noRemindersLine,
    focusIntro,
    savedLocally,
    changeAnytime,
    chooseReviewTimeCta,
    openReviewRitualCta,
    saveRitualCta,
    openWeeklyReviewCta,
    openArchiveHomeCta,
    focusRepeated,
    focusChanged,
    focusWatchNext,
    daySunday,
    daypartMorning,
    daypartAfternoon,
    daypartEvening,
    insufficientHelper,
    cardHeadlineUnset,
    cardSummaryUnset,
    cardHeadlineSet,
    cardSummarySet,
    supportSectionTitle,
    supportSectionBody,
    helpSectionTitle,
    helpSectionBullet,
    screenshotSummary,
    ritualSummary(
      daypart: ReviewRitualDaypart.evening,
      focusRepeated: true,
      focusChanged: true,
      focusWatchNext: true,
    ),
  ];
}