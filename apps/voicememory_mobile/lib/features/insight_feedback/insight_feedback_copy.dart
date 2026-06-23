/// Calm copy for user-confirmed insight feedback.
import 'insight_feedback_models.dart';

abstract final class InsightFeedbackCopy {
  InsightFeedbackCopy._();

  static const prompt = 'Does this fit?';
  static const fits = 'This fits';
  static const notQuite = 'Not quite';
  static const tooEarly = 'Too early to say';
  static const saveAsWatchTheme = 'Save as watch theme';
  static const openWatchlistCta = 'Open Watchlist';

  static const savedLocally = 'Saved locally.';
  static const localOnlyNote =
      'This only changes your local archive experience.';
  static const signalNotFact =
      'ArchiveMe will treat this as a signal, not a fact.';

  static const supportSectionTitle = 'User-confirmed insights';
  static const supportSectionBody =
      'On Then vs Now and Archive Clarity, you can say whether an insight fits. '
      'Feedback stays on this device and never includes private entry text.';

  static const betaOutcomesLabel = 'Insight feedback captured';
  static const betaOutcomesNone = 'None yet';
  static const betaOutcomesSome = 'Yes';

  static String latestChoiceLabel(InsightFeedbackChoice choice) => switch (choice) {
        InsightFeedbackChoice.fits => fits,
        InsightFeedbackChoice.notQuite => notQuite,
        InsightFeedbackChoice.tooEarly => tooEarly,
        InsightFeedbackChoice.saveAsWatchTheme => saveAsWatchTheme,
      };

  static String trustSummaryLabel({
    required int fitsCount,
    required int notQuiteCount,
    required int tooEarlyCount,
  }) {
    if (fitsCount + notQuiteCount + tooEarlyCount <= 0) {
      return 'No insight feedback saved yet.';
    }
    return 'Local insight feedback: $fitsCount fit, $notQuiteCount not quite, '
        '$tooEarlyCount too early.';
  }

  static List<String> get allVisibleStrings => [
        prompt,
        fits,
        notQuite,
        tooEarly,
        saveAsWatchTheme,
        openWatchlistCta,
        savedLocally,
        localOnlyNote,
        signalNotFact,
        supportSectionTitle,
        supportSectionBody,
        betaOutcomesLabel,
        betaOutcomesNone,
        betaOutcomesSome,
        trustSummaryLabel(fitsCount: 2, notQuiteCount: 1, tooEarlyCount: 1),
        latestChoiceLabel(InsightFeedbackChoice.fits),
      ];
}
