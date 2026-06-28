import '../activation/returning_user_today.dart';
import '../daily_archive_exercise/daily_archive_exercise_models.dart';
import '../todays_question/todays_question_models.dart';
import 'record_empty_archive_gates.dart';

/// Which single guidance card may appear on the Record tab ready state.
class RecordHomeSurfacePolicy {
  const RecordHomeSurfacePolicy({
    this.showDailyMapPrompt = false,
    this.showReturningUserToday = false,
    this.showNextMomentPrompt = false,
    this.showTodaysOneQuestion = false,
  });

  final bool showDailyMapPrompt;
  final bool showReturningUserToday;
  final bool showNextMomentPrompt;
  final bool showTodaysOneQuestion;

  int get guidanceCardCount =>
      (showDailyMapPrompt ? 1 : 0) +
      (showReturningUserToday ? 1 : 0) +
      (showNextMomentPrompt ? 1 : 0) +
      (showTodaysOneQuestion ? 1 : 0);

  /// Record stays capture-first: one lightweight prompt, review lives on Patterns.
  static RecordHomeSurfacePolicy resolve({
    required bool isReady,
    required bool loaded,
    required int entryCount,
    required bool screenshotMode,
    DailyArchiveExerciseResult? dailyArchiveExercise,
    ReturningUserToday? returningUserToday,
    TodaysQuestionResult? todaysOneQuestion,
  }) {
    if (!isReady || !loaded || screenshotMode) {
      return const RecordHomeSurfacePolicy();
    }

    final mapWouldShow = dailyArchiveExercise != null &&
        dailyArchiveExercise.showOnRecord &&
        RecordEmptyArchiveGates.showDailyArchiveExerciseOnRecord(
          loaded: loaded,
          entryCount: entryCount,
        );

    if (mapWouldShow) {
      return const RecordHomeSurfacePolicy(showDailyMapPrompt: true);
    }

    final archiveReviewReady =
        returningUserToday?.stage == ReturningUserTodayStage.fivePlus;

    if (archiveReviewReady) {
      return const RecordHomeSurfacePolicy(showReturningUserToday: true);
    }

    final questionWouldShow = todaysOneQuestion != null &&
        todaysOneQuestion.showOnRecord &&
        RecordEmptyArchiveGates.showTodaysQuestionOnRecord(
          loaded: loaded,
          entryCount: entryCount,
        );

    if (questionWouldShow) {
      return const RecordHomeSurfacePolicy(showTodaysOneQuestion: true);
    }

    if (returningUserToday != null) {
      return const RecordHomeSurfacePolicy(showReturningUserToday: true);
    }

    return const RecordHomeSurfacePolicy();
  }
}
