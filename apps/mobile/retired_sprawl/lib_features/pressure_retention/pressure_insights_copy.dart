/// Consumer-facing copy for the pressure insights surface.
///
/// Strong "pressure loop" language is reserved for 2+ logged moments so a
/// single entry never reads like a confirmed pattern.
class PressureInsightsCopy {
  PressureInsightsCopy._();

  static const minEntriesForLoopLanguage = 2;

  static bool hasStrongLoopEvidence(int entryCount) =>
      entryCount >= minEntriesForLoopLanguage;

  static const String screenTitleStrong = 'Your pressure loop';
  static const String pageTitleStrong = 'What your pressure loop looks like';
  static const String visibilityCardTitleStrong =
      'Your pressure loop, this week';
  static const String weeklyRecapTitleStrong = 'Weekly pressure recap';

  static const String screenTitleEarly = 'Early pressure signal';
  static const String pageTitleEarly = 'What may be repeating';
  static const String visibilityCardTitleEarly = 'What you noticed this week';
  static const String weeklyRecapTitleEarly = 'This week so far';
  static const String addMomentCtaEarly = 'Add another moment';

  static String screenTitle(int entryCount) =>
      hasStrongLoopEvidence(entryCount) ? screenTitleStrong : screenTitleEarly;

  static String pageTitle(int entryCount) =>
      hasStrongLoopEvidence(entryCount) ? pageTitleStrong : pageTitleEarly;

  static String visibilityCardTitle(int entryCount) =>
      hasStrongLoopEvidence(entryCount)
      ? visibilityCardTitleStrong
      : visibilityCardTitleEarly;

  static String weeklyRecapTitle(int entryCount) =>
      hasStrongLoopEvidence(entryCount)
      ? weeklyRecapTitleStrong
      : weeklyRecapTitleEarly;
}