import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/returning_user_today.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/features/daily_archive_exercise/daily_archive_exercise_copy.dart';
import 'package:voicememory_mobile/features/daily_archive_exercise/daily_archive_exercise_models.dart';
import 'package:voicememory_mobile/features/record/record_home_surface_policy.dart';
import 'package:voicememory_mobile/features/todays_question/todays_question_copy.dart';
import 'package:voicememory_mobile/features/todays_question/todays_question_models.dart';

const _mapExercise = DailyArchiveExerciseResult(
  kind: DailyArchiveExerciseKind.comparisonMaterial,
  title: DailyArchiveExerciseCopy.recordLabel,
  prompt: 'prompt',
  hint: 'hint',
  primaryCtaLabel: DailyArchiveExerciseCopy.saveMomentCta,
  primaryRoute: DailyArchiveExerciseCopy.recordRoute,
  showOnArchiveHome: true,
  showOnRecord: true,
);

const _returningReviewReady = ReturningUserToday(
  stage: ReturningUserTodayStage.fivePlus,
  title: VisibleArchiveProofCopy.returningUserFivePlusTitle,
  body: VisibleArchiveProofCopy.returningUserFivePlusBody,
  primaryCta: VisibleArchiveProofCopy.returningUserViewReviewCta,
  secondaryCta: VisibleArchiveProofCopy.returningUserAddMomentCta,
  primaryAction: ReturningUserTodayAction.viewReview,
  secondaryAction: ReturningUserTodayAction.addMoment,
);

const _returningTwoEntries = ReturningUserToday(
  stage: ReturningUserTodayStage.two,
  title: VisibleArchiveProofCopy.returningUserTwoTitle,
  body: VisibleArchiveProofCopy.returningUserTwoBody,
  primaryCta: VisibleArchiveProofCopy.returningUserAddMomentCta,
  secondaryCta: VisibleArchiveProofCopy.returningUserViewArchiveCta,
  primaryAction: ReturningUserTodayAction.addMoment,
  secondaryAction: ReturningUserTodayAction.viewArchive,
);

const _todaysQuestion = TodaysQuestionResult(
  questionId: TodaysQuestionId.rotated,
  eyebrow: TodaysQuestionCopy.eyebrow,
  questionText: 'What felt different today?',
  helperText: TodaysQuestionCopy.helperText,
  primaryCtaLabel: TodaysQuestionCopy.recordAnswerCta,
  primaryRoute: TodaysQuestionCopy.recordRoute,
  suggestedCaptureMode: TodaysQuestionCaptureMode.voice,
  isEmptyState: false,
  isBetaFeedbackPrompt: false,
  showOnRecord: true,
  secondaryCtaLabel: TodaysQuestionCopy.viewQuestionCta,
  secondaryRoute: TodaysQuestionCopy.route,
);

void main() {
  group('RecordHomeSurfacePolicy', () {
    test('prefers map prompt and hides competing guidance cards', () {
      final policy = RecordHomeSurfacePolicy.resolve(
        isReady: true,
        loaded: true,
        entryCount: 5,
        screenshotMode: false,
        dailyArchiveExercise: _mapExercise,
        returningUserToday: _returningReviewReady,
        todaysOneQuestion: _todaysQuestion,
      );

      expect(policy.showDailyMapPrompt, isTrue);
      expect(policy.showReturningUserToday, isFalse);
      expect(policy.showNextMomentPrompt, isFalse);
      expect(policy.showTodaysOneQuestion, isFalse);
      expect(policy.showStartHereTodayPrompt, isFalse);
      expect(policy.guidanceCardCount, 1);
      expect(policy.totalGuidanceCardCount, 1);
    });

    test('never shows archive review and todays question together', () {
      final policy = RecordHomeSurfacePolicy.resolve(
        isReady: true,
        loaded: true,
        entryCount: 6,
        screenshotMode: false,
        dailyArchiveExercise: null,
        returningUserToday: _returningReviewReady,
        todaysOneQuestion: _todaysQuestion,
      );

      expect(policy.showReturningUserToday, isTrue);
      expect(policy.showTodaysOneQuestion, isFalse);
      expect(policy.guidanceCardCount, 1);
    });

    test('never shows next moment prompt on Record', () {
      final policy = RecordHomeSurfacePolicy.resolve(
        isReady: true,
        loaded: true,
        entryCount: 3,
        screenshotMode: false,
        dailyArchiveExercise: null,
        returningUserToday: _returningTwoEntries,
        todaysOneQuestion: null,
      );

      expect(policy.showNextMomentPrompt, isFalse);
      expect(policy.showReturningUserToday, isFalse);
    });

    test(
      'shows todays question only when map and archive review are absent',
      () {
        final policy = RecordHomeSurfacePolicy.resolve(
          isReady: true,
          loaded: true,
          entryCount: 2,
          screenshotMode: false,
          dailyArchiveExercise: null,
          returningUserToday: null,
          todaysOneQuestion: _todaysQuestion,
        );

        expect(policy.showTodaysOneQuestion, isTrue);
        expect(policy.guidanceCardCount, 1);
      },
    );

    test('shows start here only when no top guidance card is available', () {
      final policy = RecordHomeSurfacePolicy.resolve(
        isReady: true,
        loaded: true,
        entryCount: 10,
        screenshotMode: false,
        dailyArchiveExercise: null,
        returningUserToday: null,
        todaysOneQuestion: null,
        hasStartHereSuggestion: true,
      );

      expect(policy.showStartHereTodayPrompt, isTrue);
      expect(policy.guidanceCardCount, 0);
      expect(policy.totalGuidanceCardCount, 1);
    });

    test('hides start here when map prompt wins', () {
      final policy = RecordHomeSurfacePolicy.resolve(
        isReady: true,
        loaded: true,
        entryCount: 10,
        screenshotMode: false,
        dailyArchiveExercise: _mapExercise,
        returningUserToday: null,
        todaysOneQuestion: null,
        hasStartHereSuggestion: true,
      );

      expect(policy.showDailyMapPrompt, isTrue);
      expect(policy.showStartHereTodayPrompt, isFalse);
      expect(policy.totalGuidanceCardCount, 1);
    });

    test('at 10+ entries hides archive review and pro surfaces on Record', () {
      final policy = RecordHomeSurfacePolicy.resolve(
        isReady: true,
        loaded: true,
        entryCount: 12,
        screenshotMode: false,
        dailyArchiveExercise: _mapExercise,
        returningUserToday: _returningReviewReady,
        todaysOneQuestion: _todaysQuestion,
        hasStartHereSuggestion: true,
      );

      expect(policy.showDailyMirrorCard, isFalse);
      expect(policy.showWorthCheckingToday, isFalse);
      expect(policy.showTrySayingPrompts, isFalse);
      expect(policy.showOneSmallRecordingCard, isFalse);
      expect(policy.showDaySevenContinuity, isFalse);
      expect(policy.showArchiveReturnChanges, isFalse);
      expect(policy.showArchiveDepth, isFalse);
      expect(policy.showReturnRitual, isFalse);
      expect(policy.showEntryDirectionStarters, isFalse);
      expect(policy.showProBridge, isFalse);
      expect(policy.showArchiveProgressCards, isFalse);
      expect(policy.showCurrentObjectiveCard, isFalse);
      expect(policy.showRetentionStateCard, isFalse);
    });
  });
}
