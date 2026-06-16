import '../../config/screenshot_mode.dart';
import '../../config/screenshot_sample_data.dart';
import '../../models/journal_entry.dart';
import '../../services/app_services.dart';
import '../tomorrow_return/active_pattern_thread_coordinator.dart';
import '../tomorrow_return/active_pattern_thread_engine.dart';
import '../tomorrow_return/active_pattern_thread_model.dart';
import '../tomorrow_return/change_summary_model.dart';
import '../tomorrow_return/return_comparison_model.dart';
import '../tomorrow_return/return_streak_model.dart';
import '../activation/activation_tracker.dart';
import '../tomorrow_return/watch_for_coordinator.dart';
import '../tomorrow_return/watch_for_model.dart';
import '../tomorrow_return/watch_for_prompt_engine.dart';
import '../tomorrow_return/watch_for_prompt_model.dart';
import '../tomorrow_return/tomorrow_check_in_coordinator.dart';
import '../tomorrow_return/watch_for_store.dart';
import '../tomorrow_return/weekly_pattern_recap_engine.dart';
import 'first_session_pattern_engine.dart';
import 'first_session_pattern_model.dart';
import 'pattern_correction_learning_coordinator.dart';

/// First-session detection and accepting tomorrow's watch-for + thread.
abstract class FirstSessionCoordinator {
  FirstSessionCoordinator._();

  static const _engine = FirstSessionPatternEngine();
  static const _threadEngine = ActivePatternThreadEngine();
  static const _watchForPromptEngine = WatchForPromptEngine();

  static WatchForStore _watchStore() =>
      WatchForStore(AppServices.instance.prefs);

  static Future<bool> isFirstSession({int? reflectionCount}) async {
    if (ScreenshotMode.enabled && ScreenshotMode.recordFirstSessionPreview) {
      return true;
    }
    if (reflectionCount != null && reflectionCount > 2) return false;

    final thread = await ActivePatternThreadCoordinator.loadCurrentThread();
    if (thread != null) return false;

    final store = _watchStore();
    final completed = await store.readLatestCompleted();
    if (completed != null && completed.status == WatchForStatus.checked) {
      return false;
    }
    final history = await store.readHistory();
    if (history.isNotEmpty) return false;

    return reflectionCount == null || reflectionCount <= 2;
  }

  static bool shouldShowMinimalPatterns({
    required int reflectionCount,
    ReturnComparison? comparison,
    ReturnStreak? streak,
    WatchForItem? watchCompleted,
    ChangeSummary? changeSummary,
    WeeklyPatternRecap? weeklyRecap,
  }) {
    if (ScreenshotMode.enabled && ScreenshotMode.patternsFirstThreePreview) {
      return true;
    }
    if (ScreenshotMode.enabled && ScreenshotMode.patternsFirstSessionPreview) {
      return true;
    }
    return reflectionCount < 3;
  }

  static Future<FirstSessionPattern> buildFromEntry(
    JournalEntry entry, {
    int alternativeIndex = 0,
  }) async {
    if (ScreenshotMode.enabled) {
      return ScreenshotSampleData.firstSessionPatternSample;
    }
    final boosts =
        await PatternCorrectionLearningCoordinator.preferredCategoryBoosts();
    return _engine.build(
      entry,
      alternativeIndex: alternativeIndex,
      preferredCategoryBoosts: boosts,
    );
  }

  static Future<ActivePatternThread> acceptForTomorrow(
    FirstSessionPattern pattern, {
    DateTime? now,
    String? correctionLearningId,
    String reflectionText = '',
    String? sourceReflectionId,
    String? selectedVariantId,
    String? checkInQuestionOverride,
  }) async {
    if (ScreenshotMode.enabled) {
      return ScreenshotSampleData.activePatternThreadSample;
    }

    final clock = now ?? DateTime.now();
    final basePrompt = _watchForPromptEngine.build(
      pattern: pattern,
      reflectionText: reflectionText,
      now: clock,
    );
    final prompt = selectedVariantId != null
        ? basePrompt.withSelectedVariant(selectedVariantId)
        : basePrompt;
    final watchItem = _watchForPromptEngine.toWatchForItem(
      prompt,
      now: clock,
      sourceReflectionId: sourceReflectionId,
    );
    final override = checkInQuestionOverride?.trim();
    final finalWatch = override != null && override.isNotEmpty
        ? watchItem.copyWith(checkInQuestion: override)
        : watchItem;
    await WatchForCoordinator.acceptSuggestedWatchFor(finalWatch);
    final threadPreview = await seedActiveThread(
      pattern,
      watchPrompt: prompt,
      checkInQuestionOverride: override,
      now: clock,
    );
    await TomorrowCheckInCoordinator.createFromWatchFor(
      finalWatch,
      sourcePatternThreadId: threadPreview.id,
      now: clock,
    );
    await ActivationTracker.trackWatchForPromptAccepted(
      strength: prompt.strength.id,
    );
    await ActivationTracker.trackFirstPatternAccepted();
    if (correctionLearningId != null && correctionLearningId.isNotEmpty) {
      await PatternCorrectionLearningCoordinator.markUsedForNextPrompt(
        correctionLearningId,
      );
    }
    return threadPreview;
  }

  static Future<ActivePatternThread> seedActiveThread(
    FirstSessionPattern pattern, {
    WatchForPrompt? watchPrompt,
    String? checkInQuestionOverride,
    DateTime? now,
  }) async {
    final clock = now ?? DateTime.now();
    final prompt =
        watchPrompt ??
        _watchForPromptEngine.build(pattern: pattern, now: clock);
    final override = checkInQuestionOverride?.trim();
    final nextQuestion = override != null && override.isNotEmpty
        ? override
        : (prompt.checkInQuestion.isNotEmpty
              ? prompt.checkInQuestion
              : _threadEngine.nextPromptFor(
                  status: ActivePatternThreadStatus.active,
                  watchForText: prompt.shortPrompt,
                  needsOneMoreMoment: false,
                ));
    final thread = ActivePatternThread(
      id: 'thread_${clock.microsecondsSinceEpoch}',
      title: pattern.title,
      createdAt: clock,
      updatedAt: clock,
      watchForText: prompt.shortPrompt,
      chips: prompt.chips.take(3).toList(),
      status: ActivePatternThreadStatus.active,
      daysActive: 1,
      lastResult: WatchForResult.none,
      nextPrompt: nextQuestion,
      recentMoments: pattern.sourceTextPreview.isNotEmpty
          ? [pattern.sourceTextPreview]
          : const [],
    );
    await ActivePatternThreadCoordinator.writeCurrentForFirstSession(thread);
    return thread;
  }
}

// Need ReturnComparison etc - fix imports in coordinator
