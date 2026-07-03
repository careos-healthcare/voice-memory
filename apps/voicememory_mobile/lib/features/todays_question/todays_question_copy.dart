import '../activation/weekly_archive_review.dart';
import '../daily_question/adaptive_daily_question_copy.dart';

/// Calm copy for today's one question on Record.
abstract final class TodaysQuestionCopy {
  TodaysQuestionCopy._();

  static const route = '/todays-one-question';
  static const recordRoute = '/record';
  static const betaFeedbackRoute = '/beta-feedback';
  static const archiveHomeRoute = '/archive-belief';

  static const eyebrow = "Today's one question";
  static const helperText = 'One useful moment is enough.';

  static const saveMomentCta = 'Save this moment';
  static const saveComparisonCta = 'Save comparison';
  static const saveThemeEvidenceCta = 'Save theme evidence';
  static const openBetaFeedbackCta = 'Open beta feedback';
  static const recordAnswerCta = 'Record answer';
  static const typeAnswerCta = 'Type an answer';
  static const backToRecordCta = 'Back to Record';
  static const viewQuestionCta = "View today's question";

  static const futureArchiveQuestion =
      'What should your future archive remember from today?';
  static const comparisonQuestion = 'What felt similar or different today?';
  static const betaFeedbackQuestion =
      'Did ArchiveMe show anything useful after your first few moments?';
  static const watchThemeQuestion =
      'Where did your watch theme show up today?';
  static const reviewChangeQuestion =
      'What changed since your earlier moments?';

  static const fullScreenWhy =
      'This gives ArchiveMe one clean moment to compare later.';

  static const screenshotTitle = "Today's one question (sample)";
  static const screenshotQuestion =
      'What would be useful to compare later?';
  static const screenshotHelper =
      'Example only — no private data.';

  static const supportSectionTitle = "Today's one question";
  static const supportSectionBody =
      'Open Record to see one calm, evidence-based question that helps you '
      'know what to save next. Nothing is uploaded.';

  static const rotatedQuestions = [
    'What repeated today?',
    'What felt different today?',
    'What did you almost avoid?',
    'What decision came up again?',
    'What would be useful to compare later?',
    'What did you notice before reacting?',
  ];

  static String weeklyReviewRoute({required bool weeklyReviewAvailable}) =>
      weeklyReviewAvailable
          ? WeeklyArchiveReviewNavigation.route
          : archiveHomeRoute;

  static List<String> get allVisibleStrings => [
        eyebrow,
        helperText,
        saveMomentCta,
        saveComparisonCta,
        saveThemeEvidenceCta,
        openBetaFeedbackCta,
        recordAnswerCta,
        typeAnswerCta,
        backToRecordCta,
        viewQuestionCta,
        futureArchiveQuestion,
        comparisonQuestion,
        betaFeedbackQuestion,
        watchThemeQuestion,
        reviewChangeQuestion,
        fullScreenWhy,
        screenshotTitle,
        screenshotQuestion,
        screenshotHelper,
        supportSectionTitle,
        supportSectionBody,
        ...rotatedQuestions,
        ...AdaptiveDailyQuestionCopy.allVisibleStrings,
      ];
}
