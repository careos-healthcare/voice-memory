import 'package:archiveme_mobile/features/activation/returning_user_today.dart';
import 'package:archiveme_mobile/features/daily_archive_exercise/daily_archive_exercise_models.dart';
import 'package:archiveme_mobile/features/record/record_empty_archive_gates.dart';
import 'package:archiveme_mobile/features/todays_question/todays_question_models.dart';

/// Which surfaces may appear on the Record tab ready state.
///
/// Capture always wins: archive, review, and Pro chrome stay off Record.
class RecordHomeSurfacePolicy {
  const RecordHomeSurfacePolicy({
    this.showDailyMapPrompt = false,
    this.showReturningUserToday = false,
    this.showNextMomentPrompt = false,
    this.showTodaysOneQuestion = false,
    this.showStartHereTodayPrompt = false,
    this.showDailyMirrorCard = false,
    this.showWorthCheckingToday = false,
    this.showTrySayingPrompts = false,
    this.showOneSmallRecordingCard = false,
    this.showNextEvidencePrompt = false,
    this.showArchiveProgressCards = false,
    this.showCurrentObjectiveCard = false,
    this.showRetentionStateCard = false,
    this.showDaySevenContinuity = false,
    this.showArchiveReturnChanges = false,
    this.showArchiveDepth = false,
    this.showReturnRitual = false,
    this.showEntryDirectionStarters = false,
    this.showProBridge = false,
  });

  /// Top-of-screen guidance cards (map, review ready, beta question, …).
  final bool showDailyMapPrompt;
  final bool showReturningUserToday;
  final bool showNextMomentPrompt;
  final bool showTodaysOneQuestion;

  /// Optional single starter below capture when no top guidance card shows.
  final bool showStartHereTodayPrompt;

  /// Surfaces hidden from Record ready state.
  final bool showDailyMirrorCard;
  final bool showWorthCheckingToday;
  final bool showTrySayingPrompts;
  final bool showOneSmallRecordingCard;
  final bool showNextEvidencePrompt;
  final bool showArchiveProgressCards;
  final bool showCurrentObjectiveCard;
  final bool showRetentionStateCard;
  final bool showDaySevenContinuity;
  final bool showArchiveReturnChanges;
  final bool showArchiveDepth;
  final bool showReturnRitual;
  final bool showEntryDirectionStarters;
  final bool showProBridge;

  int get guidanceCardCount =>
      (showDailyMapPrompt ? 1 : 0) +
      (showReturningUserToday ? 1 : 0) +
      (showNextMomentPrompt ? 1 : 0) +
      (showTodaysOneQuestion ? 1 : 0);

  int get totalGuidanceCardCount =>
      guidanceCardCount + (showStartHereTodayPrompt ? 1 : 0);

  /// Record stays capture-first: one top prompt at most, optional start-here
  /// below capture, and no archive/review/pro surfaces.
  static RecordHomeSurfacePolicy resolve({
    required bool isReady,
    required bool loaded,
    required int entryCount,
    required bool screenshotMode,
    DailyArchiveExerciseResult? dailyArchiveExercise,
    ReturningUserToday? returningUserToday,
    TodaysQuestionResult? todaysOneQuestion,
    bool hasStartHereSuggestion = false,
  }) {
    if (!isReady || !loaded || screenshotMode) {
      return const RecordHomeSurfacePolicy();
    }

    final mapWouldShow =
        dailyArchiveExercise != null &&
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

    final questionWouldShow =
        todaysOneQuestion != null &&
        todaysOneQuestion.showOnRecord &&
        RecordEmptyArchiveGates.showTodaysQuestionOnRecord(
          loaded: loaded,
          entryCount: entryCount,
        );

    if (questionWouldShow) {
      return const RecordHomeSurfacePolicy(showTodaysOneQuestion: true);
    }

    if (hasStartHereSuggestion) {
      return const RecordHomeSurfacePolicy(showStartHereTodayPrompt: true);
    }

    return const RecordHomeSurfacePolicy();
  }
}