import 'package:archiveme_mobile/config/screenshot_mode.dart';
import 'package:archiveme_mobile/config/screenshot_sample_data.dart';
import 'package:archiveme_mobile/features/activation/activation_tracker.dart';
import 'package:archiveme_mobile/features/pattern_memory/habit_proof_engine.dart';
import 'package:archiveme_mobile/features/pattern_memory/habit_proof_model.dart';
import 'package:archiveme_mobile/features/pattern_memory/habit_proof_store.dart';
import 'package:archiveme_mobile/features/pattern_memory/pattern_memory_model.dart';
import 'package:archiveme_mobile/features/pattern_memory/pattern_memory_store.dart';
import 'package:archiveme_mobile/features/pattern_memory/pattern_next_action_engine.dart';
import 'package:archiveme_mobile/features/pattern_memory/pattern_next_action_model.dart';
import 'package:archiveme_mobile/features/pattern_memory/pattern_next_action_store.dart';
import 'package:archiveme_mobile/features/pattern_memory/pattern_progress_engine.dart';
import 'package:archiveme_mobile/features/pattern_memory/pattern_progress_model.dart';
import 'package:archiveme_mobile/features/pattern_memory/pattern_progress_store.dart';
import 'package:archiveme_mobile/features/pattern_memory/pattern_share_recap_engine.dart';
import 'package:archiveme_mobile/features/pattern_memory/pattern_share_recap_model.dart';
import 'package:archiveme_mobile/features/pattern_memory/weekly_pattern_recap_engine.dart';
import 'package:archiveme_mobile/features/pattern_memory/weekly_pattern_recap_model.dart';
import 'package:archiveme_mobile/features/pattern_memory/weekly_pattern_recap_store.dart';
import 'package:archiveme_mobile/features/tomorrow_return/tomorrow_check_in_coordinator.dart';
import 'package:archiveme_mobile/features/tomorrow_return/tomorrow_check_in_model.dart';
import 'package:archiveme_mobile/services/app_services.dart';

/// Connects completed check-ins to the evolving pattern memory thread.
abstract class PatternMemoryCoordinator {
  PatternMemoryCoordinator._();

  static const _defaultPrompt =
      'Tomorrow, check whether this pattern shows up again.';
  static const PatternProgressEngine _progressEngine = PatternProgressEngine();
  static const PatternNextActionEngine _nextActionEngine =
      PatternNextActionEngine();
  static const HabitProofEngine _habitProofEngine = HabitProofEngine();
  static const WeeklyPatternRecapEngine _weeklyRecapEngine =
      WeeklyPatternRecapEngine();
  static const PatternShareRecapEngine _shareRecapEngine =
      PatternShareRecapEngine();

  static PatternMemoryStore _store() =>
      PatternMemoryStore(AppServices.instance.prefs);

  static PatternProgressStore _progressStore() =>
      PatternProgressStore(AppServices.instance.prefs);

  static PatternNextActionStore _nextActionStore() =>
      PatternNextActionStore(AppServices.instance.prefs);

  static HabitProofStore _habitProofStore() =>
      HabitProofStore(AppServices.instance.prefs);

  static WeeklyPatternRecapStore _weeklyRecapStore() =>
      WeeklyPatternRecapStore(AppServices.instance.prefs);

  static Future<PatternMemory?> loadActive() async {
    if (ScreenshotMode.enabled) {
      return ScreenshotSampleData.patternMemorySample;
    }
    return _store().loadActive();
  }

  /// Latest progress payoff for the active memory, if any.
  static Future<PatternProgressMoment?> loadLatestProgress() async {
    if (ScreenshotMode.enabled) {
      return ScreenshotSampleData.patternProgressSample;
    }
    final moment = await _progressStore().loadLatest();
    if (moment == null || !moment.shouldShow) return null;
    return moment;
  }

  /// The latest "next useful check" for the active memory, if any.
  static Future<PatternNextAction?> loadLatestNextAction() async {
    if (ScreenshotMode.enabled) {
      return ScreenshotSampleData.patternNextActionSample;
    }
    return _nextActionStore().loadLatest();
  }

  /// The latest "why this is useful" proof, if it should be shown.
  static Future<HabitProofMoment?> loadLatestHabitProof() async {
    if (ScreenshotMode.enabled) {
      return ScreenshotSampleData.habitProofSample;
    }
    final proof = await _habitProofStore().loadLatest();
    if (proof == null || !proof.shouldShow) return null;
    return proof;
  }

  /// The latest weekly recap for the active memory, if it should be shown.
  static Future<WeeklyPatternRecap?> loadLatestWeeklyRecap() async {
    if (ScreenshotMode.enabled) {
      return ScreenshotSampleData.weeklyPatternRecapSample;
    }
    final recap = await _weeklyRecapStore().loadLatest();
    if (recap == null || !recap.shouldShow) return null;
    return recap;
  }

  /// Builds a simple, keepable text recap from the current pattern story.
  static Future<PatternShareRecap> buildShareRecap() async {
    if (ScreenshotMode.enabled) {
      return ScreenshotSampleData.patternShareRecapSample;
    }
    final memory = await loadActive();
    final progress = await loadLatestProgress();
    final action = await loadLatestNextAction();
    final weekly = await loadLatestWeeklyRecap();
    return _shareRecapEngine.build(
      memory: memory,
      progress: progress,
      action: action,
      weekly: weekly,
    );
  }

  /// Builds an update from a completed check-in and folds it into memory.
  static Future<PatternMemory?> recordCheckInCompletion({
    required TomorrowCheckIn completed,
    String reflectionText = '',
    DateTime? now,
  }) async {
    if (ScreenshotMode.enabled) return null;
    final option = completed.selectedOption;
    if (option == null) return null;

    final update = PatternMemoryUpdate(
      checkInId: completed.id,
      resultHint: PatternMemoryResultHint.normalize(option.comparisonHint),
      reflectionText: reflectionText,
      createdAt: now ?? DateTime.now(),
    );

    final memory = await _store().applyUpdate(
      update,
      patternTitle: completed.patternTitle,
    );

    if (memory.checkInCount <= 1) {
      ActivationTracker.trackPatternMemoryCreated();
    } else {
      ActivationTracker.trackPatternMemoryUpdated();
    }

    final progress = await _maybeBuildProgress(memory);
    final action = await _maybeBuildNextAction(memory, progress);
    await _maybeBuildHabitProof(memory, progress, action);
    await _maybeBuildWeeklyRecap(memory, progress, action, now: now);
    return memory;
  }

  /// Builds the "what changed" payoff once enough check-ins exist.
  ///
  /// De-duplicates so the same memory + check-in count never creates twice.
  /// Returns the moment when it should be shown, otherwise null.
  static Future<PatternProgressMoment?> _maybeBuildProgress(
    PatternMemory memory,
  ) async {
    final moment = _progressEngine.build(memory);
    if (!moment.shouldShow) return null;

    final store = _progressStore();
    final existing = await store.loadLatest();
    if (existing == null || existing.id != moment.id) {
      await store.saveLatest(moment);
      await store.appendHistory(moment);
      ActivationTracker.trackPatternProgressMomentCreated();
    }
    return moment;
  }

  /// Builds the one simple next action from memory + progress.
  ///
  /// De-duplicates on the action id (memory + check-in count + action type).
  static Future<PatternNextAction> _maybeBuildNextAction(
    PatternMemory memory,
    PatternProgressMoment? progress,
  ) async {
    final action = _nextActionEngine.build(memory, progress);
    final store = _nextActionStore();
    final existing = await store.loadLatest();
    if (existing != null && existing.id == action.id) return action;

    await store.saveLatest(action);
    await store.appendHistory(action);
    ActivationTracker.trackPatternNextActionCreated();
    return action;
  }

  /// Builds the "why this is useful" proof from the full picture.
  ///
  /// De-duplicates on the proof id (memory + check-in count + proof type).
  static Future<void> _maybeBuildHabitProof(
    PatternMemory memory,
    PatternProgressMoment? progress,
    PatternNextAction? action,
  ) async {
    final proof = _habitProofEngine.build(memory, progress, action);
    if (!proof.shouldShow) return;

    final store = _habitProofStore();
    final existing = await store.loadLatest();
    if (existing != null && existing.id == proof.id) return;

    await store.saveLatest(proof);
    await store.appendHistory(proof);
    ActivationTracker.trackHabitProofCreated();
  }

  /// Builds the weekly recap once enough check-ins exist in the week.
  ///
  /// De-duplicates on the recap id (memory + week start + recap type).
  static Future<void> _maybeBuildWeeklyRecap(
    PatternMemory memory,
    PatternProgressMoment? progress,
    PatternNextAction? action, {
    DateTime? now,
  }) async {
    final recap = _weeklyRecapEngine.build(memory, progress, action, now: now);
    if (!recap.shouldShow) return;

    final store = _weeklyRecapStore();
    final existing = await store.loadLatest();
    if (existing != null && existing.id == recap.id) return;

    await store.saveLatest(recap);
    await store.appendHistory(recap);
    ActivationTracker.trackWeeklyPatternRecapCreated();
  }

  /// Creates tomorrow's check-in from a weekly recap's next question.
  static Future<TomorrowCheckIn?> useWeeklyRecapNext(
    WeeklyPatternRecap recap, {
    DateTime? now,
  }) async {
    if (ScreenshotMode.enabled) return null;
    final question = recap.nextQuestion?.trim() ?? '';
    if (question.isEmpty) return null;

    final title = (await loadActive())?.patternTitle ?? recap.patternTitle;
    final checkIn = await TomorrowCheckInCoordinator.createForTomorrow(
      patternTitle: title,
      specificPrompt: _defaultPrompt,
      checkInQuestion: question,
      now: now,
    );
    return checkIn;
  }

  /// Creates tomorrow's check-in from a habit proof's next line.
  static Future<TomorrowCheckIn?> useHabitProofNext(
    HabitProofMoment proof, {
    DateTime? now,
  }) async {
    if (ScreenshotMode.enabled) return null;
    final question = proof.nextLine?.trim() ?? '';
    if (question.isEmpty) return null;

    final title = (await loadActive())?.patternTitle ?? '';
    final checkIn = await TomorrowCheckInCoordinator.createForTomorrow(
      patternTitle: title,
      specificPrompt: _defaultPrompt,
      checkInQuestion: question,
      now: now,
    );
    return checkIn;
  }

  /// Creates tomorrow's check-in from a next action's question.
  static Future<TomorrowCheckIn?> useNextAction(
    PatternNextAction action, {
    DateTime? now,
  }) async {
    if (ScreenshotMode.enabled) return null;
    if (action.question.trim().isEmpty) return null;

    final title = (await loadActive())?.patternTitle ?? '';
    final checkIn = await TomorrowCheckInCoordinator.createForTomorrow(
      patternTitle: title,
      specificPrompt: _defaultPrompt,
      checkInQuestion: action.question,
      now: now,
    );
    ActivationTracker.trackPatternNextActionUsed();
    return checkIn;
  }

  /// Creates tomorrow's check-in using the memory's next best question.
  static Future<TomorrowCheckIn?> useNextQuestion(
    PatternMemory memory, {
    DateTime? now,
  }) async {
    final question = memory.nextBestQuestion;
    if (question == null || question.trim().isEmpty) return null;
    final checkIn = await TomorrowCheckInCoordinator.createForTomorrow(
      patternTitle: memory.patternTitle,
      specificPrompt: _defaultPrompt,
      checkInQuestion: question,
      now: now,
    );
    ActivationTracker.trackPatternMemoryNextQuestionUsed();
    return checkIn;
  }

  static Future<void> clear() async {
    await _store().clear();
    await _progressStore().clear();
    await _nextActionStore().clear();
    await _habitProofStore().clear();
    await _weeklyRecapStore().clear();
  }
}