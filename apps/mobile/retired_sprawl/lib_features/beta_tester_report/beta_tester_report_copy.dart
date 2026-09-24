import 'package:archiveme_mobile/features/beta_tester_report/beta_tester_report_model.dart';

/// Beta-first report copy — safe summaries only, no transcript text.
abstract final class BetaTesterReportCopy {
  BetaTesterReportCopy._();

  static const corePositioning =
      'Your first Thoughtprint report shows what returned, what changed, what faded, what you corrected, and what Thoughtprint is still unsure about.';

  static const title = 'Your first Thoughtprint report';

  static const subtitle = 'Built from moments you saved.';

  static const whatReturnedHeading = 'What returned';
  static const whatChangedHeading = 'What changed';
  static const whatFadedHeading = 'What faded';
  static const whatYouCorrectedHeading = 'What you corrected';
  static const stillUnsureHeading = 'What Thoughtprint is still unsure about';

  static const whatReturnedBody =
      'Thoughtprint has started to see what may be coming back.';

  static const whatChangedBody =
      'Thoughtprint is watching whether this feels different than before.';

  static const whatFadedBody =
      'Some older evidence may matter less if it has not returned.';

  static const whatYouCorrectedBody =
      'Your corrections change how Thoughtprint treats the timeline.';

  static const stillUnsureBody =
      'Thoughtprint needs more real moments before treating this as strong evidence.';

  static const footer = 'No single moment proves the whole story.';

  static const betaFeedbackLine =
      'Your feedback helps improve what Thoughtprint shows next.';

  static String headingFor(BetaTesterReportSectionId section) =>
      switch (section) {
        BetaTesterReportSectionId.whatReturned => whatReturnedHeading,
        BetaTesterReportSectionId.whatChanged => whatChangedHeading,
        BetaTesterReportSectionId.whatFaded => whatFadedHeading,
        BetaTesterReportSectionId.whatYouCorrected => whatYouCorrectedHeading,
        BetaTesterReportSectionId.stillUnsure => stillUnsureHeading,
      };

  static String bodyFor(BetaTesterReportSectionId section) => switch (section) {
    BetaTesterReportSectionId.whatReturned => whatReturnedBody,
    BetaTesterReportSectionId.whatChanged => whatChangedBody,
    BetaTesterReportSectionId.whatFaded => whatFadedBody,
    BetaTesterReportSectionId.whatYouCorrected => whatYouCorrectedBody,
    BetaTesterReportSectionId.stillUnsure => stillUnsureBody,
  };

  static const List<BetaTesterReportSectionId> sectionOrder = [
    BetaTesterReportSectionId.whatReturned,
    BetaTesterReportSectionId.whatChanged,
    BetaTesterReportSectionId.whatFaded,
    BetaTesterReportSectionId.whatYouCorrected,
    BetaTesterReportSectionId.stillUnsure,
  ];

  static List<String> allVisibleStrings() => [
    corePositioning,
    title,
    subtitle,
    whatReturnedHeading,
    whatChangedHeading,
    whatFadedHeading,
    whatYouCorrectedHeading,
    stillUnsureHeading,
    whatReturnedBody,
    whatChangedBody,
    whatFadedBody,
    whatYouCorrectedBody,
    stillUnsureBody,
    footer,
    betaFeedbackLine,
  ];
}