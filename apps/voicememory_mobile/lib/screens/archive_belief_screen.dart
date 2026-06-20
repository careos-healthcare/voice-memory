import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/archive_mobile_spacing.dart';
import '../config/screenshot_mode.dart';
import '../config/force_screenshot_repeat_card.dart';
import '../config/screenshot_sample_data.dart';
import '../design/empty_archive_experience.dart';
import '../features/archive_reactivity/archive_delta.dart';
import '../features/archive_reactivity/archive_full_loop_log.dart';
import '../features/archive_reactivity/archive_lens.dart';
import '../features/archive_reactivity/archive_lens_return_result.dart';
import '../features/archive_reactivity/archive_wow_moment.dart';
import '../features/archive_evidence/archive_belief_correction_store.dart';
import '../features/archive_evidence/archive_belief_thread_model.dart';
import '../features/archive_evidence/archive_intelligence_tier.dart';
import '../features/archive_evidence/archive_intelligence_tier_resolver.dart';
import '../features/archive_evidence/archive_evidence.dart';
import '../features/onboarding/record_return_pro_store.dart';
import '../features/archive_beliefs/archive_belief_models.dart';
import '../features/archive_beliefs/archive_beliefs_presenter.dart';
import '../features/archive_clean/archive_clean_section_engine.dart';
import '../features/archive_clean/archive_clean_section_model.dart';
import '../features/archive_compression/archive_compression_coordinator.dart';
import '../features/archive_compression/archive_compression_model.dart';
import '../features/archive_memory/archive_evolution_coordinator.dart';
import '../features/archive_memory/archive_evolution_model.dart';
import '../features/archive_memory/archive_memory_summary_coordinator.dart';
import '../features/archive_memory/archive_memory_summary_model.dart';
import '../features/archive_beliefs/belief_change_timeline.dart';
import '../features/archive_growth/archive_growth_service.dart';
import '../features/discover/discover_local.dart';
import '../features/first25/first25_user_metrics.dart';
import '../features/insights/archive_insight.dart';
import '../features/insights/archive_insights_engine.dart';
import '../models/journal_entry.dart';
import '../product/consumer_ui_copy.dart';
import '../services/app_services.dart';
import '../startup/startup_light_mode.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_typography.dart';
import '../widgets/archive/archive_beliefs_dashboard.dart';
import '../widgets/archive/archive_insight_card.dart';
import '../widgets/patterns/patterns_deep_links.dart';
import '../features/tomorrow_return/change_summary_model.dart';
import '../features/tomorrow_return/return_comparison_coordinator.dart';
import '../features/tomorrow_return/return_comparison_model.dart';
import '../features/tomorrow_return/return_retention_coordinator.dart';
import '../features/tomorrow_return/return_streak_model.dart';
import '../features/tomorrow_return/weekly_pattern_recap_engine.dart';
import '../features/tomorrow_return/tomorrow_commitment_coordinator.dart';
import '../features/tomorrow_return/tomorrow_commitment_model.dart';
import '../features/archive_reactivity/archive_lens_return_hook_reminder.dart';
import '../features/archive_reactivity/archive_belief_surface.dart';
import '../features/archive_reactivity/archive_belief_specificity.dart';
import '../features/archive_reactivity/archive_change_timeline.dart';
import '../features/archive_reactivity/archive_daily_pattern_check_in.dart';
import '../features/archive_reactivity/archive_daily_pattern_check_in_store.dart';
import '../features/archive_reactivity/archive_emerging_pattern_radar.dart';
import '../features/archive_reactivity/archive_loop_experiment.dart';
import '../features/archive_reactivity/archive_loop_experiment_store.dart';
import '../features/archive_reactivity/archive_personal_pattern_manual.dart';
import '../features/archive_reactivity/archive_positive_pattern_detector.dart';
import '../features/archive_reactivity/archive_return_value_proof.dart';
import '../features/archive_reactivity/archive_return_value_proof_store.dart';
import '../features/archive_reactivity/archive_thought_map.dart';
import '../features/archive_reactivity/archive_thought_map_evidence.dart';
import '../features/archive_reactivity/archive_thought_map_node_edits.dart';
import '../features/patterns/transcript_evidence_extractor.dart';
import '../features/loop_map/loop_map_primary_surface.dart';
import '../navigation/main_shell_tabs.dart';
import '../features/onboarding/archive_loop_onboarding.dart';
import '../screens/archive_loop_onboarding_screen.dart';
import '../features/activation/activation_tracker.dart';
import '../features/activation/first_loop_activation_coordinator.dart';
import '../features/activation/first_loop_activation_model.dart';
import '../features/activation/first_three_journey_coordinator.dart';
import '../features/activation/first_three_journey_engine.dart';
import '../features/activation/first_three_journey_model.dart';
import '../features/export/private_recap_engine.dart';
import '../features/first_session/first_session_coordinator.dart';
import '../features/archive_review/archive_range_review_engine.dart';
import '../features/archive_review/archive_range_review_model.dart';
import '../features/monthly_review/monthly_pattern_review_engine.dart';
import '../features/monthly_review/monthly_pattern_review_model.dart';
import '../features/monthly_review/monthly_pattern_review_store.dart';
import '../features/moments/key_moment_model.dart';
import '../features/moments/key_moment_store.dart';
import '../features/pattern_map/pattern_map_engine.dart';
import '../features/patterns/patterns_stack_policy.dart';
import '../features/patterns/pattern_display_cache_cleanup.dart';
import '../features/patterns/pattern_display_copy_gate.dart';
import '../features/patterns/pattern_intelligence_pipeline.dart';
import '../features/patterns/patterns_human_copy.dart';
import '../features/patterns/patterns_tab_stability.dart';
import '../features/pattern_profile/pattern_profile_engine.dart';
import '../features/pattern_memory/pattern_memory_store.dart';
import '../features/perspective/kinder_angle_model.dart';
import '../features/pattern_memory/habit_proof_model.dart';
import '../features/pattern_memory/pattern_memory_coordinator.dart';
import '../features/pattern_memory/pattern_memory_model.dart';
import '../features/pattern_memory/pattern_next_action_model.dart';
import '../features/pattern_memory/pattern_progress_model.dart';
import '../features/pattern_memory/pattern_share_recap_model.dart';
import '../features/pattern_memory/weekly_pattern_recap_model.dart' as wkrecap;
import '../features/tomorrow_return/active_pattern_thread_coordinator.dart';
import '../features/tomorrow_return/active_pattern_thread_model.dart';
import '../features/tomorrow_return/tomorrow_check_in_coordinator.dart';
import '../features/tomorrow_return/tomorrow_check_in_model.dart';
import '../features/tomorrow_return/watch_for_coordinator.dart';
import '../features/tomorrow_return/watch_for_model.dart';
import '../widgets/patterns/pattern_profile_card.dart';
import '../widgets/patterns/archive_compression_card.dart';
import '../widgets/patterns/archive_clean_view_card.dart';
import '../widgets/patterns/archive_evolution_timeline_card.dart';
import '../widgets/patterns/archive_memory_empty_preview_card.dart';
import '../widgets/patterns/archive_memory_summary_card.dart';
import '../widgets/patterns/first_loop_state_card.dart';
import '../widgets/patterns/habit_proof_card.dart';
import '../widgets/patterns/weekly_recap_card.dart' as weekly_recap_card;
import '../widgets/patterns/pattern_share_recap_card.dart';
import '../widgets/patterns/missed_check_in_reason_prompt.dart';
import '../widgets/patterns/pattern_next_action_card.dart';
import '../widgets/patterns/archive_range_review_card.dart';
import '../widgets/patterns/monthly_pattern_review_card.dart';
import '../widgets/patterns/pattern_memory_card.dart';
import '../widgets/patterns/pattern_progress_card.dart';
import '../features/objective/current_objective_engine.dart';
import '../features/objective/current_objective_model.dart';
import '../features/retention/retention_state_engine.dart';
import '../features/retention/retention_state_model.dart';
import '../widgets/objective/current_objective_card.dart';
import '../widgets/retention/retention_state_card.dart';
import '../widgets/patterns/patterns_check_in_status_card.dart';
import '../widgets/quick_help/quick_help_button.dart';
import '../widgets/record/kinder_angle_card.dart';
import '../widgets/record/perspective_shift_card.dart';
import '../widgets/patterns/patterns_come_back_tomorrow_card.dart';
import '../widgets/patterns/patterns_first_archive_view.dart';
import '../widgets/patterns/patterns_empty_view.dart';
import '../widgets/patterns/change_summary_card.dart';
import '../widgets/patterns/return_comparison_card.dart';
import '../widgets/patterns/return_streak_card.dart';
import '../widgets/patterns/tomorrow_return_status_card.dart';
import '../widgets/patterns/weekly_pattern_recap_card.dart';
import '../widgets/patterns/active_pattern_thread_card.dart';
import '../widgets/activation/third_session_archive_usefulness_card.dart';
import '../widgets/patterns/archive_latest_change_strip.dart';
import '../widgets/patterns/archive_return_value_proof_card.dart';
import '../widgets/patterns/archive_belief_surface_card.dart';
import '../widgets/patterns/archive_change_timeline_card.dart';
import '../widgets/patterns/archive_daily_pattern_check_in_card.dart';
import '../widgets/patterns/archive_emerging_pattern_radar_card.dart';
import '../widgets/patterns/archive_loop_experiment_card.dart';
import '../widgets/patterns/archive_loop_experiment_result_card.dart';
import '../widgets/patterns/archive_personal_pattern_manual_card.dart';
import '../widgets/patterns/archive_return_value_result_card.dart';
import '../widgets/patterns/loop_map_primary_surface_card.dart';
import '../widgets/patterns/archive_lens_top_insight_card.dart';
import '../widgets/record/archive_lens_return_result_post_save_card.dart';
import '../widgets/patterns/archive_wow_moment_insight_strip.dart';
import '../widgets/patterns/archive_belief_thread_card.dart';
import '../widgets/patterns/archive_oh_wow_moment_card.dart';
import '../widgets/patterns/archive_intelligence_pro_bridge_card.dart';
import '../widgets/patterns/weekly_what_changed_review_card.dart';
import '../billing/archive_entitlement_reader.dart';
import '../widgets/patterns/watch_for_result_card.dart';
import '../features/activation/first_three_session_gates.dart';
import '../features/activation/third_session_archive_usefulness_engine.dart';
import '../features/activation/third_session_archive_usefulness_model.dart';
import '../features/retention/second_session_signal_engine.dart';
import '../widgets/activation/first_three_journey_card.dart';
import '../widgets/export/private_recap_actions.dart';
import '../features/post_save_insight/selected_signal_coordinator.dart';
import '../features/signal_archive/signal_archive_coordinator.dart';
import '../features/signal_archive/signal_archive_navigation.dart';
import '../features/signal_archive/signal_archive_snapshot.dart';
import '../features/signal_archive/signal_corrections_model.dart';
import '../features/post_save_insight/selected_signal_model.dart';
import '../widgets/patterns/patterns_signals_waiting_card.dart';
import '../features/signal_journey/signal_journey_coordinator.dart';
import '../features/signal_journey/signal_journey_model.dart';
import '../features/signal_review/signal_review_coordinator.dart';
import '../features/signal_review/signal_review_model.dart';
import '../features/signal_review/signal_review_navigation.dart';
import '../widgets/signal/archive_home_dashboard.dart';
import '../widgets/signal/archive_watching_card.dart';
import '../widgets/signal/signal_journey_card.dart';
import '../widgets/signal/signal_journey_completion_card.dart';
import '../widgets/signal/signal_review_card.dart';
import '../widgets/record/second_session_comparison_card.dart';

/// Patterns tab — recurring themes dashboard (RECORD → PATTERN → CHANGE).
class ArchiveBeliefScreen extends StatefulWidget {
  const ArchiveBeliefScreen({super.key});

  @override
  State<ArchiveBeliefScreen> createState() => _ArchiveBeliefScreenState();
}

class _ArchiveBeliefScreenState extends State<ArchiveBeliefScreen> {
  List<JournalEntry> _entries = [];
  ArchiveBeliefsSnapshot? _beliefs;
  List<BeliefChangeTimelineItem> _changing = const [];
  ArchiveInsightsSnapshot _insights = ArchiveInsightsSnapshot.empty;
  TomorrowCommitment? _commitment;
  TomorrowCommitmentDisplayState _commitmentState =
      TomorrowCommitmentDisplayState.hidden;
  ReturnComparison? _returnComparison;
  ReturnStreak? _returnStreak;
  ChangeSummary? _changeSummary;
  WeeklyPatternRecap? _weeklyRecap;
  WatchForItem? _watchForCompleted;
  ActivePatternThread? _activePatternThread;
  FirstThreeJourneyModel? _firstThreeJourney;
  SelectedSignalRecord? _selectedSignal;
  SignalArchiveSnapshot? _signalArchiveSnapshot;
  SignalJourney? _signalJourney;
  SignalReview? _signalReview;
  TomorrowCheckIn? _checkInDueToday;
  TomorrowCheckIn? _checkInCompletedRecently;
  TomorrowCheckIn? _missedCheckInForDiagnosis;
  TomorrowCheckIn? _activeCheckInForTomorrow;
  TomorrowCheckIn? _recentMissedCheckIn;
  bool _retentionDismissed = false;
  PatternMemory? _patternMemory;
  MonthlyPatternReview? _monthlyReview;
  ArchiveRangeReview? _rangeReview;
  PatternProgressMoment? _patternProgress;
  PatternNextAction? _patternNextAction;
  HabitProofMoment? _habitProof;
  wkrecap.WeeklyPatternRecap? _patternWeeklyRecap;
  PatternShareRecap? _patternShareRecap;
  ArchiveMemorySummary? _archiveMemory;
  ArchiveEvolutionTimeline? _archiveTimeline;
  List<KeyMoment> _keyMoments = const [];
  List<ArchiveMomentGroup> _compressionGroups = const [];
  FirstLoopActivationState _firstLoop = FirstLoopActivationState.empty;
  bool _showArchiveLoopOnboardingBanner = false;
  bool _loading = true;
  bool _reloadScheduled = false;
  bool _patternsInitialLoadScheduled = false;
  bool _patternsInitialLoadComplete = false;
  bool _hasNavigationShellHost = false;
  bool _archiveIsPro = false;
  bool _proBridgeResolved = false;
  ArchiveDelta? _latestArchiveDelta;
  ArchiveWowMoment? _latestArchiveWowMoment;
  ArchiveLensInsight? _latestArchiveLens;
  ArchiveLensReturnResult? _latestReturnResult;
  ArchiveReturnValueProof? _pendingReturnValueProof;
  ArchiveReturnValueProof? _completedReturnValueProof;
  LoopMapPrimarySurfaceModel? _loopMapPrimarySurface;
  ArchiveThoughtMap? _loopMapThoughtMap;
  ArchiveEmergingPatternRadar? _emergingPatternRadar;
  ArchiveLoopExperiment? _suggestedLoopExperiment;
  ArchiveLoopExperiment? _completedLoopExperiment;
  bool _hasPositivePatternSignal = false;
  ArchivePersonalPatternManual? _personalPatternManual;
  ArchiveDailyPatternCheckIn? _dailyPatternCheckIn;
  ArchiveChangeTimeline? _changeTimeline;
  ArchiveBeliefSurface? _beliefSurface;
  static const _tierResolver = ArchiveIntelligenceTierResolver();

  ArchiveIntelligenceTier get _archiveIntelligenceTier =>
      _tierResolver.resolveSync(isPro: _archiveIsPro);

  @override
  void initState() {
    super.initState();
    if (ForceScreenshotRepeatCard.enabled) {
      _loading = false;
      return;
    }
    if (ScreenshotMode.enabled) {
      _applyScreenshotSample();
      unawaited(_refreshCompressionGroups());
      return;
    }
    final peek = peekJournalEntriesSync(AppServices.instance.journalStore);
    _entries = peek;
    if (peek.isEmpty || peek.length == 1) {
      _loading = false;
    }
    if (StartupLightMode.shouldDeferPatternsInitialLoad) {
      _loading = false;
      StartupLightMode.logArchiveEnginesSkipped('initial_launch');
    } else {
      _load();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedulePatternsInitialLoadIfVisible();
  }

  /// Indexed-stack mounts Patterns off-screen — defer heavy engines until the
  /// branch is active (or this screen is hosted standalone in widget tests).
  void _schedulePatternsInitialLoadIfVisible() {
    if (_patternsInitialLoadComplete ||
        _patternsInitialLoadScheduled ||
        ForceScreenshotRepeatCard.enabled ||
        ScreenshotMode.enabled) {
      return;
    }

    final shell = StatefulNavigationShell.maybeOf(context);
    if (shell != null) {
      _hasNavigationShellHost = true;
    }

    if (StartupLightMode.shouldDeferPatternsInitialLoad) {
      if (shell != null && shell.currentIndex != MainShellTabIndex.map) return;
      if (shell == null && _hasNavigationShellHost) return;
    }

    _patternsInitialLoadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _patternsInitialLoadScheduled = false;
      if (!mounted || _patternsInitialLoadComplete) return;

      final activeShell = StatefulNavigationShell.maybeOf(context);
      if (StartupLightMode.shouldDeferPatternsInitialLoad) {
        if (activeShell != null) {
          if (activeShell.currentIndex != MainShellTabIndex.map) return;
        } else if (_hasNavigationShellHost) {
          return;
        }
      }

      _patternsInitialLoadComplete = true;
      unawaited(_load());
    });
  }

  void _applyScreenshotSample() {
    if (ScreenshotMode.archiveCompressionPreview) {
      setState(() {
        _entries = const [];
        _beliefs = ScreenshotSampleData.beliefsSnapshot;
        _changing = const [];
        _insights = ArchiveInsightsSnapshot.empty;
        _commitment = null;
        _commitmentState = TomorrowCommitmentDisplayState.hidden;
        _patternMemory = ScreenshotSampleData.patternMemorySample;
        _keyMoments = ScreenshotSampleData.archiveCompressionMomentsSample;
        _archiveMemory = ScreenshotSampleData.archiveMemorySummarySample;
        _archiveTimeline = ScreenshotSampleData.archiveEvolutionTimelineSample;
        _monthlyReview = null;
        _patternWeeklyRecap = null;
        _patternShareRecap = null;
        _checkInCompletedRecently = null;
        _loading = false;
      });
      return;
    }
    if (ScreenshotMode.feedbackPreview) {
      setState(() {
        _entries = const [];
        _beliefs = ScreenshotSampleData.beliefsSnapshot;
        _changing = const [];
        _insights = ArchiveInsightsSnapshot.empty;
        _commitment = null;
        _commitmentState = TomorrowCommitmentDisplayState.hidden;
        _patternMemory = ScreenshotSampleData.patternMemorySample;
        _keyMoments = ScreenshotSampleData.archiveCleanKeyMomentsSample;
        _archiveMemory = ScreenshotSampleData.archiveMemorySummarySample;
        _archiveTimeline = ScreenshotSampleData.archiveEvolutionTimelineSample;
        _monthlyReview = null;
        _patternWeeklyRecap = null;
        _patternShareRecap = null;
        _checkInCompletedRecently = null;
        _loading = false;
      });
      return;
    }
    if (ScreenshotMode.patternsCleanPreview) {
      setState(() {
        _entries = const [];
        _beliefs = ScreenshotSampleData.beliefsSnapshot;
        _changing = const [];
        _insights = ArchiveInsightsSnapshot.empty;
        _commitment = null;
        _commitmentState = TomorrowCommitmentDisplayState.hidden;
        _patternMemory = ScreenshotSampleData.patternMemorySample;
        _keyMoments = ScreenshotSampleData.archiveCleanKeyMomentsSample;
        _archiveMemory = ScreenshotSampleData.archiveMemorySummarySample;
        _archiveTimeline = ScreenshotSampleData.archiveEvolutionTimelineSample;
        _monthlyReview = null;
        _patternWeeklyRecap = null;
        _patternShareRecap = null;
        _checkInCompletedRecently = null;
        _loading = false;
      });
      return;
    }
    if (ScreenshotMode.archiveReviewPreview) {
      final moments = ScreenshotSampleData.archiveReviewMomentsSample;
      setState(() {
        _entries = const [];
        _beliefs = ScreenshotSampleData.beliefsSnapshot;
        _changing = const [];
        _insights = ArchiveInsightsSnapshot.empty;
        _commitment = null;
        _commitmentState = TomorrowCommitmentDisplayState.hidden;
        _patternMemory = ScreenshotSampleData.patternMemorySample;
        _keyMoments = moments;
        _archiveMemory = ScreenshotSampleData.archiveMemorySummarySample;
        _archiveTimeline = ScreenshotSampleData.archiveEvolutionTimelineSample;
        _rangeReview = _buildRangeReview(
          keyMoments: moments,
          patternMemory: ScreenshotSampleData.patternMemorySample,
          archiveTimeline: ScreenshotSampleData.archiveEvolutionTimelineSample,
        );
        _monthlyReview = null;
        _checkInCompletedRecently = null;
        _loading = false;
      });
      return;
    }
    if (ScreenshotMode.archiveCleanPreview) {
      setState(() {
        _entries = const [];
        _beliefs = ScreenshotSampleData.beliefsSnapshot;
        _changing = const [];
        _insights = ArchiveInsightsSnapshot.empty;
        _commitment = null;
        _commitmentState = TomorrowCommitmentDisplayState.hidden;
        _keyMoments = ScreenshotSampleData.archiveCleanKeyMomentsSample;
        _archiveMemory = ScreenshotSampleData.archiveMemorySummarySample;
        _archiveTimeline = ScreenshotSampleData.archiveEvolutionTimelineSample;
        _checkInCompletedRecently =
            ScreenshotSampleData.tomorrowCheckInCompletedSample;
        _loading = false;
      });
      return;
    }
    final journeyCount = ScreenshotMode.screenshotJourneyReflectionCount;
    if (journeyCount >= 0) {
      setState(() {
        _entries = const [];
        _beliefs = journeyCount >= 3
            ? ScreenshotSampleData.beliefsSnapshot
            : null;
        _changing = const [];
        _insights = ArchiveInsightsSnapshot.empty;
        _commitment = null;
        _commitmentState = TomorrowCommitmentDisplayState.hidden;
        _returnComparison = journeyCount >= 3
            ? ScreenshotSampleData.returnComparisonSample
            : null;
        _returnStreak = journeyCount >= 3
            ? ScreenshotSampleData.returnStreakSample
            : null;
        _changeSummary = journeyCount >= 3
            ? ScreenshotSampleData.changeSummarySample
            : null;
        _weeklyRecap = journeyCount >= 3
            ? ScreenshotSampleData.weeklyRecapSample
            : null;
        _watchForCompleted = journeyCount >= 3
            ? ScreenshotSampleData.watchForCompletedSample
            : null;
        _activePatternThread = journeyCount >= 1
            ? ScreenshotSampleData.activePatternThreadSample
            : null;
        _firstThreeJourney = ScreenshotSampleData.firstThreeJourneyForCount(
          journeyCount,
        );
        _loading = false;
      });
      return;
    }
    if (ScreenshotMode.patternsFirstSessionPreview) {
      setState(() {
        _entries = const [];
        _beliefs = null;
        _changing = const [];
        _insights = ArchiveInsightsSnapshot.empty;
        _commitment = null;
        _commitmentState = TomorrowCommitmentDisplayState.hidden;
        _returnComparison = null;
        _returnStreak = null;
        _changeSummary = null;
        _weeklyRecap = null;
        _watchForCompleted = null;
        _activePatternThread = ScreenshotSampleData.activePatternThreadSample;
        _firstThreeJourney = ScreenshotSampleData.firstThreeJourneyForCount(1);
        _loading = false;
      });
      return;
    }
    final sample = ScreenshotSampleData.beliefsSnapshot;
    final previewDay = DateTime.now();
    final commitment = ScreenshotSampleData.tomorrowCommitmentForPreview(
      previewDay,
    );
    setState(() {
      _entries = const [];
      _beliefs = sample;
      _changing = ScreenshotSampleData.changingStories;
      _insights = ScreenshotSampleData.insightsSnapshot;
      _commitment = commitment;
      _commitmentState = commitment.displayState(previewDay);
      _returnComparison = ScreenshotSampleData.returnComparisonSample;
      _returnStreak = ScreenshotSampleData.returnStreakSample;
      _changeSummary = ScreenshotSampleData.changeSummarySample;
      _weeklyRecap = ScreenshotSampleData.weeklyRecapSample;
      _watchForCompleted = ScreenshotSampleData.watchForCompletedSample;
      _activePatternThread = ScreenshotSampleData.activePatternThreadSample;
      _firstThreeJourney = ScreenshotSampleData.firstThreeJourneyForCount(3);
      _archiveMemory = ScreenshotMode.positioningRescuePreview
          ? null
          : ScreenshotSampleData.archiveMemorySummarySample;
      _archiveTimeline = ScreenshotSampleData.archiveEvolutionTimelineSample;
      _loading = false;
    });
  }

  Future<void> _load() async {
    if (ScreenshotMode.enabled) {
      _applyScreenshotSample();
      return;
    }
    try {
      await _loadPatternsData();
    } catch (e, st) {
      PatternsTabStability.logBuildFailed('load:$e');
      if (kDebugMode) {
        debugPrint('$st');
      }
      if (!mounted) return;
      setState(() {
        _beliefs = null;
        _loading = false;
      });
    }
  }

  Future<void> _loadPatternsData() async {
    await ArchiveBeliefCorrectionStore.ensureLoaded();
    final isPro = await ArchiveEntitlementReader.forAccessCheck().isPro;
    final recordReturnPro = await RecordReturnProStore.instance().load();
    final latestDelta =
        await ArchiveDeltaStore(AppServices.instance.prefs).read();
    final latestWowMoment =
        await ArchiveWowMomentStore(AppServices.instance.prefs).read();
    final entries = await AppServices.instance.journal.loadAll();
    final latestLens = await ArchiveLensStore(
      AppServices.instance.prefs,
    ).readValidForEntries(entries.map((e) => e.id).toSet());
    ArchiveLensReturnResult? latestReturnResult;
    try {
      latestReturnResult =
          await ArchiveLensReturnResultStore(AppServices.instance.prefs).latest();
    } catch (_) {
      ArchiveLensReturnResultResolver.logSkipped('patterns_load_failed');
    }
    if (!mounted) return;

    if (entries.isEmpty) {
      final loopMapPrimarySurface = await _resolveLoopMapPrimarySurface(entries);
      setState(() {
        _entries = entries;
        _beliefs = null;
        _changing = const [];
        _insights = ArchiveInsightsSnapshot.empty;
        _loopMapPrimarySurface = loopMapPrimarySurface;
        _loading = false;
      });
      First25UserMetrics.trackArchiveOpened(surface: 'archive_beliefs_empty');
      return;
    }

    if (entries.length == 1) {
      final loopMapPrimarySurface = await _resolveLoopMapPrimarySurface(entries);
      setState(() {
        _archiveIsPro = isPro;
        _proBridgeResolved = recordReturnPro.proBridgeResolved;
        _entries = entries;
        _beliefs = null;
        _changing = const [];
        _insights = ArchiveInsightsSnapshot.empty;
        _loopMapPrimarySurface = loopMapPrimarySurface;
        _loading = false;
      });
      First25UserMetrics.trackArchiveOpened(
        surface: 'archive_beliefs_first_entry',
      );
      return;
    }

    if (isIntentionalEmptyArchive(entries)) {
      final loopMapPrimarySurface = await _resolveLoopMapPrimarySurface(entries);
      setState(() {
        _archiveIsPro = isPro;
        _proBridgeResolved = recordReturnPro.proBridgeResolved;
        _entries = entries;
        _beliefs = null;
        _changing = const [];
        _insights = ArchiveInsightsSnapshot.empty;
        _loopMapPrimarySurface = loopMapPrimarySurface;
        _loading = false;
      });
      First25UserMetrics.trackArchiveOpened(surface: 'archive_beliefs_empty');
      return;
    }

    final baselineRaw = await AppServices.instance.prefs.discoverBaseline;
    final baselineMap = baselineRaw?.map(
      (k, v) => MapEntry(k, (v as num).toInt()),
    );
    final feed = DiscoverLocalEngine.build(
      entries: entries,
      baselineThemes: baselineMap,
    );
    final growth = await ArchiveGrowthService.load();
    final beliefs = ArchiveBeliefsPresenter.build(
      entries: entries,
      archiveV1: growth.archiveV1,
      discoverFeed: feed,
    );
    final insights = const ArchiveInsightsEngine().build(
      entries: entries,
      discoverFeed: feed,
      currentBelief: beliefs.current.isNotEmpty
          ? beliefs.current.first.statement
          : null,
    );

    await ReturnComparisonCoordinator.acknowledgePatternsOpened();
    await PatternDisplayCacheCleanup.runOnceIfNeeded();

    final commitment = await TomorrowCommitmentCoordinator.load();
    final commitmentState = commitment == null
        ? TomorrowCommitmentDisplayState.hidden
        : commitment.displayState(DateTime.now());
    final comparison = await ReturnComparisonCoordinator.loadLatest();
    final streak = await ReturnRetentionCoordinator.loadStreak();
    final changeSummary = await ReturnRetentionCoordinator.loadChangeSummary();
    final weeklyRecap = await ReturnRetentionCoordinator.loadWeeklyRecap();
    final watchForCompleted = await WatchForCoordinator.loadLatestCompleted();
    final activeThreadRaw =
        await ActivePatternThreadCoordinator.loadCurrentThread();
    final activeThread =
        PatternDisplayCopyGate.sanitizeActiveThread(activeThreadRaw);
    final journey = await FirstThreeJourneyCoordinator.load();
    final selectedSignal = await SelectedSignalCoordinator.loadCurrent();
    final signalArchiveSnapshot = await SignalArchiveCoordinator.load();
    final signalJourney = await SignalJourneyCoordinator.loadActive();
    SignalReview? signalReview;
    if (signalJourney != null && signalJourney.supportingCount >= 3) {
      signalReview = await SignalReviewCoordinator.loadForActiveJourney();
    }
    final checkInDue = await TomorrowCheckInCoordinator.loadDueToday();
    final missedDiagnosis = checkInDue == null
        ? await TomorrowCheckInCoordinator.loadMissedNeedingReason()
        : null;
    final checkInClosed = checkInDue == null && missedDiagnosis == null
        ? await TomorrowCheckInCoordinator.loadRecentlyCompleted()
        : null;
    final recentMissed = checkInDue == null && missedDiagnosis == null
        ? await TomorrowCheckInCoordinator.loadRecentMissed()
        : null;
    final activeCheckIn = await TomorrowCheckInCoordinator.loadActive();
    final tomorrowKey = tomorrowCheckInDateKey(
      DateTime.now().add(const Duration(days: 1)),
    );
    TomorrowCheckIn? activeForTomorrow;
    if (activeCheckIn != null &&
        !activeCheckIn.isCompleted &&
        activeCheckIn.targetDate == tomorrowKey) {
      activeForTomorrow = activeCheckIn;
    }
    final patternMemory = await PatternMemoryCoordinator.loadActive();
    final patternProgress = await PatternMemoryCoordinator.loadLatestProgress();
    final patternNextAction =
        await PatternMemoryCoordinator.loadLatestNextAction();
    final habitProof = await PatternMemoryCoordinator.loadLatestHabitProof();
    final patternWeeklyRecap =
        await PatternMemoryCoordinator.loadLatestWeeklyRecap();
    final canShareRecap =
        patternWeeklyRecap != null ||
        patternProgress != null ||
        (patternMemory != null && patternMemory.checkInCount >= 2);
    final patternShareRecap = canShareRecap
        ? await PatternMemoryCoordinator.buildShareRecap()
        : null;
    final firstLoop = await FirstLoopActivationCoordinator.load();
    final showOnboardingBanner =
        await ArchiveLoopOnboardingCoordinator.shouldShowOptionalBanner(
      entryCount: entries.length,
    );
    final monthlyReview = await _buildMonthlyReview(patternMemory);
    final archiveMemory = await ArchiveMemorySummaryCoordinator.refresh();
    final archiveTimeline = await ArchiveEvolutionCoordinator.refresh();
    final keyMoments = await KeyMomentStore.instance().loadAll();
    final compressionGroups = await ArchiveCompressionCoordinator.loadGroups();
    final rangeReview = _buildRangeReview(
      keyMoments: keyMoments,
      patternMemory: patternMemory,
      archiveTimeline: archiveTimeline,
    );

    if (!mounted) return;
    final loopMapPrimarySurface = await _resolveLoopMapPrimarySurface(entries);
    ArchiveReturnValueProof? pendingReturnValueProof;
    ArchiveReturnValueProof? completedReturnValueProof;
    if (AppServices.isInitialized) {
      final proofStore = ArchiveReturnValueProofStore(
        AppServices.instance.prefs,
      );
      pendingReturnValueProof = await proofStore.latestPending();
      completedReturnValueProof = await proofStore.latestCompleted();
    }
    final emergingPatternRadar = _resolveEmergingPatternRadar(
      entries,
      completedReturnProof: completedReturnValueProof,
    );
    final loopExperimentState = await _loadLoopExperimentState(
      entries,
      completedReturnProof: completedReturnValueProof,
      radar: emergingPatternRadar,
    );
    final personalPatternManual = _resolvePersonalPatternManual(
      entries,
      radar: emergingPatternRadar,
      completedReturnProof: completedReturnValueProof,
      completedLoopExperiment: loopExperimentState.completed,
      positiveSignals: ArchivePositivePatternDetector.detectFromTranscripts(
        entries: entries
            .where((entry) => entry.transcript.trim().isNotEmpty)
            .map((entry) => (entryId: entry.id, transcript: entry.transcript))
            .toList(),
      ),
    );
    final dailyPatternCheckIn = await _loadDailyCheckInState(
      entries,
      radar: emergingPatternRadar,
      pendingReturnProof: pendingReturnValueProof,
      completedReturnProof: completedReturnValueProof,
      completedLoopExperiment: loopExperimentState.completed,
      personalPatternManual: personalPatternManual,
    );
    final acceptedLoopExperiment = AppServices.isInitialized
        ? await ArchiveLoopExperimentStore(AppServices.instance.prefs)
            .latestAccepted()
        : null;
    final changeTimeline = _resolveChangeTimeline(
      entries,
      radar: emergingPatternRadar,
      completedReturnProof: completedReturnValueProof,
      acceptedLoopExperiment: acceptedLoopExperiment,
      completedLoopExperiment: loopExperimentState.completed,
      dailyCheckIn: dailyPatternCheckIn,
      personalPatternManual: personalPatternManual,
    );
    final beliefSurface = _resolveBeliefSurface(
      entries: entries,
      beliefs: beliefs,
      changeTimeline: changeTimeline,
      completedReturnProof: completedReturnValueProof,
      latestLens: latestLens,
      latestReturnResult: latestReturnResult,
    );
    setState(() {
      _archiveIsPro = isPro;
      _proBridgeResolved = recordReturnPro.proBridgeResolved;
      _latestArchiveDelta = latestDelta;
      _latestArchiveWowMoment = latestWowMoment;
      _latestArchiveLens = latestLens;
      _latestReturnResult = latestReturnResult;
      _pendingReturnValueProof = pendingReturnValueProof;
      _completedReturnValueProof = completedReturnValueProof;
      _entries = entries;
      _firstLoop = firstLoop;
      _showArchiveLoopOnboardingBanner = showOnboardingBanner;
      _loopMapPrimarySurface = loopMapPrimarySurface;
      _emergingPatternRadar = emergingPatternRadar;
      _suggestedLoopExperiment = loopExperimentState.suggested;
      _completedLoopExperiment = loopExperimentState.completed;
      _hasPositivePatternSignal = loopExperimentState.hasPositiveSignal;
      _personalPatternManual = personalPatternManual;
      _dailyPatternCheckIn = dailyPatternCheckIn;
      _changeTimeline = changeTimeline;
      _beliefSurface = beliefSurface;
      _beliefs = beliefs;
      _changing = buildBeliefChangeTimeline(snapshot: beliefs, feed: feed);
      _insights = insights;
      _commitment = commitment;
      _commitmentState = commitmentState;
      _returnComparison = comparison;
      _returnStreak = streak;
      _changeSummary = changeSummary;
      _weeklyRecap = weeklyRecap;
      _watchForCompleted = watchForCompleted?.status == WatchForStatus.checked
          ? watchForCompleted
          : null;
      _activePatternThread = activeThread;
      _firstThreeJourney = journey;
      _selectedSignal = selectedSignal;
      _signalArchiveSnapshot = signalArchiveSnapshot;
      _signalJourney = signalJourney;
      _signalReview = signalReview;
      _checkInDueToday = checkInDue;
      _missedCheckInForDiagnosis = missedDiagnosis;
      _checkInCompletedRecently = checkInClosed;
      _recentMissedCheckIn = recentMissed;
      _activeCheckInForTomorrow = activeForTomorrow;
      _patternMemory = patternMemory;
      _monthlyReview = monthlyReview;
      _patternProgress = patternProgress;
      _patternNextAction = patternNextAction;
      _habitProof = habitProof;
      _patternWeeklyRecap = patternWeeklyRecap;
      _patternShareRecap = patternShareRecap;
      _archiveMemory = archiveMemory;
      _archiveTimeline = archiveTimeline;
      _keyMoments = keyMoments;
      _rangeReview = rangeReview;
      _compressionGroups = compressionGroups;
      _loading = false;
    });
    if (latestLens != null &&
        latestLens.shouldDisplayPatterns &&
        latestReturnResult != null &&
        latestReturnResult.shouldDisplayPatterns) {
      ArchiveFullLoopLog.step('patterns_verified');
    }
    if (rangeReview?.hasEnoughData == true) {
      ActivationTracker.trackArchiveRangeReviewShown();
    }
    First25UserMetrics.trackArchiveOpened(surface: 'archive_beliefs_dashboard');
  }

  Future<void> _refreshCompressionGroups() async {
    final groups = await ArchiveCompressionCoordinator.loadGroups();
    if (!mounted) return;
    setState(() => _compressionGroups = groups);
  }

  Future<void> _onCompressionAction(
    ArchiveMomentGroup group,
    Future<void> Function(ArchiveMomentGroup) action,
  ) async {
    await action(group);
    await _refreshCompressionGroups();
  }

  ArchiveRangeReview? _buildRangeReview({
    required List<KeyMoment> keyMoments,
    PatternMemory? patternMemory,
    ArchiveEvolutionTimeline? archiveTimeline,
  }) {
    if (keyMoments.length < ArchiveRangeReview.minMomentsForReview) {
      return null;
    }
    final now = _archiveCleanNow;
    final map = patternMemory != null
        ? buildPatternMap(memory: patternMemory, moments: keyMoments)
        : null;
    return buildArchiveRangeReview(
      moments: keyMoments,
      now: now,
      memory: patternMemory,
      map: map,
      timeline: archiveTimeline,
    );
  }

  Future<void> _useRangeReviewCheck(String nextCheck) async {
    await TomorrowCheckInCoordinator.createForTomorrow(
      patternTitle: _patternMemory?.patternTitle ?? '',
      specificPrompt: '',
      checkInQuestion: nextCheck,
    );
    ActivationTracker.trackArchiveRangeReviewUseCheckTapped();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tomorrow\u2019s check is set.')),
    );
  }

  /// Builds (and persists) the monthly recap from saved moments and what
  /// ArchiveMe remembers. Returns null when there is not yet enough.
  Future<MonthlyPatternReview?> _buildMonthlyReview(
    PatternMemory? activeMemory,
  ) async {
    if (ScreenshotMode.enabled) return null;
    final moments = await KeyMomentStore.instance().loadAll();
    final history = await PatternMemoryStore(
      AppServices.instance.prefs,
    ).loadHistory();
    final memories = <PatternMemory>[
      ?activeMemory,
      ...history.where((h) => h.id != activeMemory?.id),
    ];
    final now = DateTime.now();
    final completedThisMonth = moments
        .where(
          (m) =>
              m.source == KeyMomentSource.checkIn &&
              m.date.year == now.year &&
              m.date.month == now.month,
        )
        .length;
    final review = buildMonthlyPatternReview(
      moments: moments,
      patternMemories: memories,
      completedCheckInCount: completedThisMonth,
      now: now,
    );
    if (review != null) {
      await MonthlyPatternReviewStore.instance().save(review);
    }
    return review;
  }

  Future<void> _useMonthlyCheck(String nextCheck) async {
    await TomorrowCheckInCoordinator.createForTomorrow(
      patternTitle: _monthlyReview?.keptRepeating ?? '',
      specificPrompt: '',
      checkInQuestion: nextCheck,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved for next month\u2019s check.')),
    );
  }

  Future<void> _usePatternNextAction(PatternNextAction action) async {
    final checkIn = await PatternMemoryCoordinator.useNextAction(action);
    if (!mounted) return;
    if (checkIn != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved for tomorrow\u2019s check.')),
      );
    }
  }

  Future<void> _useHabitProofNext(HabitProofMoment proof) async {
    final checkIn = await PatternMemoryCoordinator.useHabitProofNext(proof);
    if (!mounted) return;
    if (checkIn != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved for tomorrow\u2019s check.')),
      );
    }
  }

  Future<void> _useArchiveTimelineCheck(String nextCheck) async {
    ActivationTracker.trackArchiveTimelineUseCheckTapped();
    await TomorrowCheckInCoordinator.createForTomorrow(
      patternTitle: _archiveTimeline?.patternTitle ?? '',
      specificPrompt: '',
      checkInQuestion: nextCheck,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ConsumerUiCopy.resultNextCheckConfirmation)),
    );
  }

  Future<void> _useArchiveMemoryCheck(String nextCheck) async {
    await TomorrowCheckInCoordinator.createForTomorrow(
      patternTitle: _archiveMemory?.patternTitle ?? '',
      specificPrompt: '',
      checkInQuestion: nextCheck,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved for tomorrow\u2019s check.')),
    );
  }

  Future<void> _usePatternWeeklyRecapNext(
    wkrecap.WeeklyPatternRecap recap,
  ) async {
    final checkIn = await PatternMemoryCoordinator.useWeeklyRecapNext(recap);
    if (!mounted) return;
    if (checkIn != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved for tomorrow\u2019s check.')),
      );
    }
  }

  ArchiveBeliefCardModel? get _strongest {
    final s = _beliefs;
    if (s == null) return null;
    if (s.current.isNotEmpty) return s.current.first;
    if (s.homeBeliefs.isNotEmpty) return s.homeBeliefs.first;
    final all = [
      ...s.current,
      ...s.emerging,
      ...s.changing,
      ...s.hiddenPatterns,
    ];
    return all.isEmpty ? null : all.first;
  }

  int get _patternCount {
    final s = _beliefs;
    if (s == null) return 0;
    return s.current.length +
        s.homeBeliefs.length +
        s.emerging.length +
        s.changing.length +
        s.hiddenPatterns.length;
  }

  bool get _hasArchiveReactivityPatterns =>
      (_latestReturnResult?.shouldDisplayPatterns ?? false) ||
      (_latestArchiveLens?.shouldDisplayPatterns ?? false);

  bool get _hasRenderablePatternInsight =>
      PatternsTabStability.hasRenderablePatternInsight(
        beliefs: _beliefs,
        strongest: _strongest,
      );

  String get _patternsEmptyReason {
    if (isIntentionalEmptyArchive(_entries)) return 'no_evidence_entries';
    return 'null_belief_snapshot_or_field';
  }

  List<Widget> _safeOrderedPatternsStack() {
    try {
      return _orderedPatternsStack();
    } catch (e, st) {
      PatternsTabStability.logBuildFailed('ordered_stack:$e');
      if (kDebugMode) {
        debugPrint('$st');
      }
      return const [];
    }
  }

  List<Widget> _safeLegacyBeliefSections(ArchiveBeliefCardModel strongest) {
    try {
      return _legacyBeliefSections(strongest);
    } catch (e, st) {
      PatternsTabStability.logBuildFailed('legacy_belief_sections:$e');
      if (kDebugMode) {
        debugPrint('$st');
      }
      return const [];
    }
  }

  Widget _buildPatternsNoClearPatternScaffold(
    BuildContext context, {
    required String reason,
  }) {
    PatternsTabStability.logEmptyState(reason);
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: ArchiveMobileSpacing.pagePadding,
            children: _withLoopMapPrimarySurface(
              const [PatternsNoClearPatternView(fillViewport: false)],
            ),
          ),
        ),
      ),
    );
  }

  int get _evidenceReflectionCount => archiveEvidenceReflectionCount(_entries);

  bool get _showEmpty {
    if (ScreenshotMode.patternsFirstSessionPreview) return false;
    if (ScreenshotMode.enabled) return false;
    return _entries.isEmpty;
  }

  bool get _showFirstArchive =>
      !ScreenshotMode.enabled && _entries.length == 1;

  String? get _firstArchiveEntryId {
    if (_entries.isEmpty) return null;
    final sorted = List<JournalEntry>.from(_entries)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return sorted.last.id;
  }

  /// Indexed-stack tabs stay mounted — refresh when journal changed elsewhere.
  ///
  /// Only runs while Patterns is the active shell branch, and reloads in the
  /// background without swapping to the loading scaffold (that swap during tab
  /// transitions was tripping NavigationBar indicator animations).
  void _scheduleReloadIfJournalDrifted() {
    if (ForceScreenshotRepeatCard.enabled) return;
    if (ScreenshotMode.enabled || _loading || _reloadScheduled) return;

    final shell = StatefulNavigationShell.maybeOf(context);
    if (shell != null && shell.currentIndex != MainShellTabIndex.map) return;

    final peekEntries = peekJournalEntriesSync(
      AppServices.instance.journalStore,
    );
    final peekEvidence = archiveEvidenceReflectionCount(peekEntries);
    if (peekEntries.length == _entries.length &&
        peekEvidence == _evidenceReflectionCount) {
      return;
    }

    _reloadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reloadScheduled = false;
      if (!mounted || _loading) return;
      final activeShell = StatefulNavigationShell.maybeOf(context);
      if (activeShell != null &&
          activeShell.currentIndex != MainShellTabIndex.map) {
        return;
      }
      unawaited(_load());
    });
  }

  void _queueJournalDriftCheck() {
    if (_reloadScheduled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scheduleReloadIfJournalDrifted();
    });
  }

  bool get _patternsFirstThreeStack {
    if (ScreenshotMode.patternsFirstThreePreview) return true;
    if (ScreenshotMode.patternsFirstSessionPreview) return true;
    return FirstSessionCoordinator.shouldShowMinimalPatterns(
      reflectionCount: _entries.length,
      comparison: _returnComparison,
      streak: _returnStreak,
      watchCompleted: _watchForCompleted,
      changeSummary: _changeSummary,
      weeklyRecap: _weeklyRecap,
    );
  }

  bool get _patternsHideAdvancedRetention =>
      _patternsFirstThreeStack ||
      FirstThreeJourneyCoordinator.shouldHideAdvancedRetention(_entries.length);

  /// Which first-loop nudge (if any) the Patterns tab should lead with.
  FirstLoopStatePhase? get _firstLoopPhase {
    if (_firstLoop.isComplete) {
      // Keep nudging "come back tomorrow" until they actually return.
      if (_checkInCompletedRecently != null) return null;
      return FirstLoopStatePhase.ready;
    }
    if (!_firstLoop.hasFirstMoment) {
      if (_entries.isEmpty) return FirstLoopStatePhase.recordMoment;
      return null;
    }
    if (_firstLoop.stage.index <
        FirstLoopActivationStage.tomorrowCheckChosen.index) {
      return FirstLoopStatePhase.chooseCheck;
    }
    return null;
  }

  void _goToRecord() => context.go('/record');

  Future<LoopMapPrimarySurfaceModel> _resolveLoopMapPrimarySurface(
    List<JournalEntry> entries,
  ) async {
    if (!AppServices.isInitialized) {
      return LoopMapPrimarySurfaceResolver.resolve(
        onboarding: ArchiveLoopOnboardingState.empty,
      );
    }
    final prefs = AppServices.instance.prefs;
    final loaded = await LoopMapThoughtMapLoader.load(
      entries: entries,
      readLens: () => ArchiveLensStore(prefs).readValidForEntries(
        entries.map((e) => e.id).toSet(),
      ),
      readReturnResult: () =>
          ArchiveLensReturnResultStore(prefs).latest(),
      readPendingHook: () =>
          ArchiveLensReturnHookReminderStore(prefs).latestPending(),
      readOnboarding: () => ArchiveLoopOnboardingCoordinator.load(),
      readEvidence: (mapId) =>
          ArchiveThoughtMapEvidenceStore(prefs).listForMap(mapId),
      readNodeEdits: (mapId) =>
          ArchiveThoughtMapNodeEditStore(prefs).listForMap(mapId),
    );
    _loopMapThoughtMap = loaded.thoughtMap;
    return loaded.surface;
  }

  ArchiveEmergingPatternRadar? _resolveEmergingPatternRadar(
    List<JournalEntry> entries, {
    ArchiveReturnValueProof? completedReturnProof,
  }) {
    final radar = ArchiveEmergingPatternRadarResolver.resolve(
      entries: entries,
      latestThoughtMap: _loopMapThoughtMap,
      latestReturnResult: (completedReturnProof ?? _completedReturnValueProof)
          ?.result,
    );
    final hasFullMap = _loopMapThoughtMap?.hasEnoughEvidence == true;
    final hasReturnResult = _completedReturnValueProof?.result != null;
    final shouldShow = ArchiveEmergingPatternRadarPlacement.shouldShow(
      entryCount: entries.length,
      firstValueRescueActive: false,
      radar: radar,
      hasFullMap: hasFullMap,
      hasReturnResult: hasReturnResult,
    );
    return shouldShow ? radar : null;
  }

  List<Widget> _loopMapEmergingPatternRadarWidgets() {
    final radar = _emergingPatternRadar;
    if (radar == null || !radar.shouldDisplay) return const [];
    return [
      ArchiveEmergingPatternRadarCard(
        radar: radar,
        surface: 'map_tab',
        compact: radar.isLightMode,
      ),
      const SizedBox(height: AppSpacing.lg),
    ];
  }

  Future<
      ({
        ArchiveLoopExperiment? suggested,
        ArchiveLoopExperiment? completed,
        bool hasPositiveSignal,
      })> _loadLoopExperimentState(
    List<JournalEntry> entries, {
    ArchiveReturnValueProof? completedReturnProof,
    ArchiveEmergingPatternRadar? radar,
  }) async {
    if (!AppServices.isInitialized) {
      return (
        suggested: null,
        completed: null,
        hasPositiveSignal: false,
      );
    }
    final positiveSignals = ArchivePositivePatternDetector.detectFromTranscripts(
      entries: entries
          .where((entry) => entry.transcript.trim().isNotEmpty)
          .map((entry) => (entryId: entry.id, transcript: entry.transcript))
          .toList(),
    );
    final resolved = ArchiveLoopExperimentResolver.resolve(
      thoughtMap: _loopMapThoughtMap,
      radar: radar,
      returnResult: completedReturnProof?.result,
      positiveSignals: positiveSignals,
      recentEntries: entries,
    );
    final store = ArchiveLoopExperimentStore(AppServices.instance.prefs);
    if (resolved != null) {
      await store.saveSuggested(resolved);
    }
    return (
      suggested: await store.latestSuggested(),
      completed: await store.latestCompleted(),
      hasPositiveSignal: positiveSignals.isNotEmpty,
    );
  }

  List<Widget> _loopMapExperimentWidgets() {
    final widgets = <Widget>[];

    final completed = _completedLoopExperiment;
    if (completed != null &&
        ArchiveLoopExperimentPlacement.shouldShowResult(
          experiment: completed,
        )) {
      widgets.add(
        ArchiveLoopExperimentResultCard(
          experiment: completed,
          surface: 'map_tab',
        ),
      );
      widgets.add(const SizedBox(height: AppSpacing.lg));
    }

    final suggested = _suggestedLoopExperiment;
    final hasFullMap = _loopMapThoughtMap?.hasEnoughEvidence == true;
    final hasReturnResult = _completedReturnValueProof?.result != null;
    if (suggested != null &&
        ArchiveLoopExperimentPlacement.shouldShowSuggestion(
          entryCount: _entries.length,
          firstValueRescueActive: false,
          experiment: suggested,
          hasFullMap: hasFullMap,
          hasReturnResult: hasReturnResult,
          hasPositiveSignal: _hasPositivePatternSignal,
        )) {
      widgets.add(
        ArchiveLoopExperimentCard(
          experiment: suggested,
          surface: 'map_tab',
          onTryPressed: () => unawaited(_tryLoopExperiment(suggested)),
          onSkipPressed: () => unawaited(_skipLoopExperiment(suggested)),
        ),
      );
      widgets.add(const SizedBox(height: AppSpacing.lg));
    }

    return widgets;
  }

  Future<void> _tryLoopExperiment(ArchiveLoopExperiment experiment) async {
    if (!AppServices.isInitialized) return;
    final store = ArchiveLoopExperimentStore(AppServices.instance.prefs);
    await store.accept(experiment.id);
    ArchiveLoopExperimentLog.started(experimentId: experiment.id);
    if (!mounted) return;
    setState(() => _suggestedLoopExperiment = null);
    context.go(ArchiveLoopExperimentResolver.recordRouteFor(experiment));
  }

  Future<void> _skipLoopExperiment(ArchiveLoopExperiment experiment) async {
    if (!AppServices.isInitialized) return;
    await ArchiveLoopExperimentStore(AppServices.instance.prefs)
        .skip(experiment.id);
    if (!mounted) return;
    setState(() => _suggestedLoopExperiment = null);
  }

  ArchivePersonalPatternManual? _resolvePersonalPatternManual(
    List<JournalEntry> entries, {
    ArchiveEmergingPatternRadar? radar,
    ArchiveReturnValueProof? completedReturnProof,
    ArchiveLoopExperiment? completedLoopExperiment,
    required List<ArchivePositivePatternSignal> positiveSignals,
  }) {
    return ArchivePersonalPatternManualResolver.resolve(
      entries: entries,
      latestThoughtMap: _loopMapThoughtMap,
      latestRadar: radar,
      latestReturnResult: completedReturnProof?.result,
      latestExperimentResult: completedLoopExperiment?.result,
      positiveSignals: positiveSignals,
    );
  }

  Future<ArchiveDailyPatternCheckIn?> _loadDailyCheckInState(
    List<JournalEntry> entries, {
    ArchiveEmergingPatternRadar? radar,
    ArchiveReturnValueProof? pendingReturnProof,
    ArchiveReturnValueProof? completedReturnProof,
    ArchiveLoopExperiment? completedLoopExperiment,
    ArchivePersonalPatternManual? personalPatternManual,
  }) async {
    if (!AppServices.isInitialized) return null;
    final now = DateTime.now();
    final dateKey = ArchiveDailyPatternCheckInResolver.dateKeyFor(now);
    final store = ArchiveDailyPatternCheckInStore(AppServices.instance.prefs);
    final existing = await store.latestForDate(dateKey);
    if (existing != null) {
      if (existing.isSkipped) return null;
      return existing;
    }

    final acceptedLoopExperiment =
        await ArchiveLoopExperimentStore(AppServices.instance.prefs)
            .latestAccepted();
    final positiveSignals = ArchivePositivePatternDetector.detectFromTranscripts(
      entries: entries
          .where((entry) => entry.transcript.trim().isNotEmpty)
          .map((entry) => (entryId: entry.id, transcript: entry.transcript))
          .toList(),
    );
    final resolved = ArchiveDailyPatternCheckInResolver.resolve(
      now: now,
      entries: entries,
      thoughtMap: _loopMapThoughtMap,
      radar: radar,
      latestExperiment: acceptedLoopExperiment,
      latestExperimentResult: completedLoopExperiment?.result,
      pendingReturnProof: pendingReturnProof,
      latestReturnResult: completedReturnProof?.result,
      manual: personalPatternManual,
      positiveSignals: positiveSignals,
    );
    if (resolved == null) return null;
    await store.saveActive(resolved);
    return resolved;
  }

  List<Widget> _loopMapDailyCheckInWidgets() {
    final checkIn = _dailyPatternCheckIn;
    final hasFullMap = _loopMapThoughtMap?.hasEnoughEvidence == true;
    if (!ArchiveDailyPatternCheckInPlacement.shouldShow(
      entryCount: _entries.length,
      firstValueRescueActive: false,
      checkIn: checkIn,
      hasFullMap: hasFullMap,
    )) {
      return const [];
    }

    return [
      ArchiveDailyPatternCheckInCard(
        checkIn: checkIn!,
        surface: 'map_tab',
        onRecordPressed: () {
          ArchiveDailyPatternCheckInLog.started(checkInId: checkIn.id);
          context.go(ArchiveDailyPatternCheckInResolver.recordRouteFor(checkIn));
        },
        onSkipPressed: () => unawaited(_skipDailyCheckIn(checkIn)),
      ),
      const SizedBox(height: AppSpacing.lg),
    ];
  }

  Future<void> _skipDailyCheckIn(ArchiveDailyPatternCheckIn checkIn) async {
    if (!AppServices.isInitialized) return;
    await ArchiveDailyPatternCheckInStore(AppServices.instance.prefs)
        .skip(checkIn.id);
    if (!mounted) return;
    setState(() => _dailyPatternCheckIn = null);
  }

  ArchiveChangeTimeline? _resolveChangeTimeline(
    List<JournalEntry> entries, {
    ArchiveEmergingPatternRadar? radar,
    ArchiveReturnValueProof? completedReturnProof,
    ArchiveLoopExperiment? acceptedLoopExperiment,
    ArchiveLoopExperiment? completedLoopExperiment,
    ArchiveDailyPatternCheckIn? dailyCheckIn,
    ArchivePersonalPatternManual? personalPatternManual,
  }) {
    final positiveSignals = ArchivePositivePatternDetector.detectFromTranscripts(
      entries: entries
          .where((entry) => entry.transcript.trim().isNotEmpty)
          .map((entry) => (entryId: entry.id, transcript: entry.transcript))
          .toList(),
    );
    final latestExperiment = completedLoopExperiment ?? acceptedLoopExperiment;
    return ArchiveChangeTimelineResolver.resolve(
      entries: entries,
      thoughtMap: _loopMapThoughtMap,
      radar: radar,
      latestReturnResult: completedReturnProof?.result,
      latestExperiment: latestExperiment,
      latestExperimentResult: completedLoopExperiment?.result,
      latestDailyCheckIn: dailyCheckIn,
      latestDailyCheckInResult: dailyCheckIn?.result,
      manual: personalPatternManual,
      positiveSignals: positiveSignals,
    );
  }

  ArchiveBeliefSurface? _resolveBeliefSurface({
    required List<JournalEntry> entries,
    required ArchiveBeliefsSnapshot beliefs,
    required ArchiveChangeTimeline? changeTimeline,
    required ArchiveReturnValueProof? completedReturnProof,
    required ArchiveLensInsight? latestLens,
    required ArchiveLensReturnResult? latestReturnResult,
  }) {
    final beliefCard = beliefs.current.isNotEmpty
        ? beliefs.current.first
        : (beliefs.homeBeliefs.isNotEmpty ? beliefs.homeBeliefs.first : null);
    ArchiveBeliefSpecificity? specificity;
    if (beliefCard != null) {
      specificity = ArchiveBeliefSpecificityResolver.resolve(
        ArchiveBeliefSpecificityInput(
          belief: beliefCard,
          entries: entries,
          latestEntry: entries.isNotEmpty ? entries.last : null,
          repeatedPhrases: TranscriptEvidenceExtractor.extractRepeatedPhrases(
            entries.map((e) => e.transcript).toList(),
          ),
          archiveLensInsight: latestLens,
          returnResult: latestReturnResult,
        ),
      );
    }
    return ArchiveBeliefSurfaceResolver.resolve(
      entries: entries,
      thoughtMap: _loopMapThoughtMap,
      changeTimeline: changeTimeline,
      beliefs: beliefs,
      specificity: specificity,
      latestReturnResult: completedReturnProof?.result,
      latestLens: latestLens,
      latestLensReturnResult: latestReturnResult,
    );
  }

  List<Widget> _loopMapBeliefSurfaceWidgets() {
    final surface = _beliefSurface;
    if (!ArchiveBeliefSurfacePlacement.shouldShow(
      entryCount: _entries.length,
      firstValueRescueActive: false,
      surface: surface,
    )) {
      return const [];
    }
    return [
      ArchiveBeliefSurfaceCard(
        surface: surface!,
        onSurface: 'map_tab',
      ),
      const SizedBox(height: AppSpacing.lg),
    ];
  }

  List<Widget> _loopMapProofLoopWidgets() {
    return [
      ..._loopMapBeliefSurfaceWidgets(),
      ..._loopMapChangeTimelineWidgets(),
    ];
  }

  List<Widget> _loopMapChangeTimelineWidgets() {
    final timeline = _changeTimeline;
    final hasFullMap = _loopMapThoughtMap?.hasEnoughEvidence == true;
    if (!ArchiveChangeTimelinePlacement.shouldShow(
      entryCount: _entries.length,
      firstValueRescueActive: false,
      timeline: timeline,
      hasFullMap: hasFullMap,
      radar: _emergingPatternRadar,
      manual: _personalPatternManual,
    )) {
      return const [];
    }

    final prominent = _completedLoopExperiment?.isCompleted == true;
    return [
      ArchiveChangeTimelineCard(
        timeline: timeline!,
        surface: 'map_tab',
        compact: !prominent && timeline.timelineItems.length > 4,
      ),
      const SizedBox(height: AppSpacing.lg),
    ];
  }

  List<Widget> _loopMapPersonalManualWidgets() {
    final manual = _personalPatternManual;
    final hasFullMap = _loopMapThoughtMap?.hasEnoughEvidence == true;
    if (!ArchivePersonalPatternManualPlacement.shouldShow(
      entryCount: _entries.length,
      firstValueRescueActive: false,
      manual: manual,
      hasFullMap: hasFullMap,
    )) {
      return const [];
    }

    return [
      ArchivePersonalPatternManualCard(
        manual: manual!,
        surface: 'map_tab',
        prominent: _completedLoopExperiment?.isCompleted == true,
      ),
      const SizedBox(height: AppSpacing.lg),
    ];
  }

  bool get _loopMapShowsReturnValueProof {
    final surface = _loopMapPrimarySurface;
    if (surface == null) return false;
    return surface.state != LoopMapPrimarySurfaceState.newUser &&
        surface.state != LoopMapPrimarySurfaceState.earlyPreview;
  }

  List<Widget> _loopMapReturnValueProofWidgets() {
    if (!_loopMapShowsReturnValueProof) return const [];

    final widgets = <Widget>[];
    final completed = _completedReturnValueProof;
    if (completed != null && completed.result != null) {
      widgets.add(
        ArchiveReturnValueResultCard(
          proof: completed,
          surface: 'map_tab',
        ),
      );
      widgets.add(const SizedBox(height: AppSpacing.lg));
    }

    final pending = _pendingReturnValueProof;
    if (pending != null && pending.isPending) {
      widgets.add(
        ArchiveReturnValueProofCard(
          proof: pending,
          surface: 'map_tab',
          onSkipPressed: () => unawaited(_skipReturnValueProof(pending)),
        ),
      );
      widgets.add(const SizedBox(height: AppSpacing.lg));
    }
    return widgets;
  }

  Future<void> _skipReturnValueProof(ArchiveReturnValueProof proof) async {
    if (!AppServices.isInitialized) return;
    await ArchiveReturnValueProofStore(AppServices.instance.prefs).clearPending();
    ArchiveReturnValueProofLog.skipped(proofId: proof.id);
    if (!mounted) return;
    setState(() => _pendingReturnValueProof = null);
  }

  List<Widget> _loopMapPrimarySurfaceHeader() {
    final surface = _loopMapPrimarySurface;
    if (surface == null) return const [];
    return [
      LoopMapPrimarySurfaceCard(model: surface),
      const SizedBox(height: AppSpacing.lg),
      ..._loopMapDailyCheckInWidgets(),
      ..._loopMapReturnValueProofWidgets(),
      ..._loopMapProofLoopWidgets(),
      ..._loopMapEmergingPatternRadarWidgets(),
      ..._loopMapExperimentWidgets(),
      ..._loopMapPersonalManualWidgets(),
    ];
  }

  List<Widget> _withLoopMapPrimarySurface(List<Widget> children) {
    final surface = _loopMapPrimarySurface;
    if (surface == null) return children;
    return [
      LoopMapPrimarySurfaceCard(model: surface),
      const SizedBox(height: AppSpacing.lg),
      ..._loopMapDailyCheckInWidgets(),
      ..._loopMapReturnValueProofWidgets(),
      ..._loopMapProofLoopWidgets(),
      ..._loopMapEmergingPatternRadarWidgets(),
      ..._loopMapExperimentWidgets(),
      ..._loopMapPersonalManualWidgets(),
      if (surface.state != LoopMapPrimarySurfaceState.newUser &&
          surface.state != LoopMapPrimarySurfaceState.earlyPreview &&
          children.isNotEmpty) ...[
        const LoopMapArchiveHistoryHeading(),
        const SizedBox(height: AppSpacing.sm),
      ],
      ...children,
    ];
  }

  List<Widget> _orderedArchiveInsightWidgets() {
    final widgets = <Widget>[];
    if (_latestReturnResult != null &&
        _latestReturnResult!.shouldDisplayPatterns) {
      widgets.add(
        ArchiveLensReturnResultPatternsCard(result: _latestReturnResult!),
      );
      widgets.add(const SizedBox(height: AppSpacing.lg));
    }
    if (_latestArchiveLens != null &&
        _latestArchiveLens!.shouldDisplayPatterns) {
      widgets.add(ArchiveLensTopInsightCard(insight: _latestArchiveLens!));
      widgets.add(const SizedBox(height: AppSpacing.lg));
    } else if (_latestArchiveWowMoment != null &&
        _latestArchiveWowMoment!.shouldDisplay) {
      widgets.add(ArchiveWowMomentInsightStrip(moment: _latestArchiveWowMoment!));
      widgets.add(const SizedBox(height: AppSpacing.lg));
    }
    if (_latestArchiveDelta != null && _latestArchiveDelta!.shouldDisplay) {
      widgets.add(ArchiveLatestChangeStrip(delta: _latestArchiveDelta!));
      widgets.add(const SizedBox(height: AppSpacing.lg));
    }
    return widgets;
  }

  List<Widget> _signalArchiveSurfaces() {
    final snapshot = _signalArchiveSnapshot;
    final journey = _signalJourney;
    final review = _signalReview;
    if (journey != null && journey.isActive) {
      return [
        SignalJourneyCard(journey: journey),
        const SizedBox(height: AppSpacing.lg),
      ];
    }
    if (journey != null && journey.isConfirmed) {
      final widgets = <Widget>[];
      if (review != null && review.isShowable) {
        widgets.add(
          SignalReviewCard(
            review: review,
            onConfirm: () async {
              await SignalReviewCoordinator.confirm(reviewId: review.id);
              if (!mounted) return;
              await _load();
            },
            onCorrect: () => SignalReviewNavigation.openFullReview(context),
            onKeepWatching: () async {
              await SignalReviewCoordinator.keepWatching(reviewId: review.id);
              if (!mounted) return;
              await _load();
            },
          ),
        );
      } else {
        widgets.add(SignalJourneyConfirmedCard(journey: journey));
        if (journey.showCompletion) {
          widgets.add(const SizedBox(height: AppSpacing.lg));
          widgets.add(
            SignalJourneyCompletionCard(
              journey: journey,
              onKeepWatching: () async {
                await SignalJourneyCoordinator.acknowledgeCompletion();
                if (!mounted) return;
                await _load();
              },
              onViewPattern: () {},
            ),
          );
        }
      }
      widgets.add(const SizedBox(height: AppSpacing.lg));
      return widgets;
    }
    if (snapshot == null) return const [];
    return [
      ArchiveHomeDashboard(snapshot: snapshot),
      const SizedBox(height: AppSpacing.lg),
      ArchiveWatchingCard(snapshot: snapshot, compact: true),
      const SizedBox(height: AppSpacing.lg),
    ];
  }

  DateTime get _archiveCleanNow => ScreenshotMode.archiveCleanPreview
      ? ScreenshotSampleData.archiveCleanPreviewDay
      : DateTime.now();

  bool get _hasCheckInToday {
    final checkIn = _checkInCompletedRecently;
    if (checkIn?.completedAt case final completed?) {
      return _isSameDay(completed, _archiveCleanNow);
    }
    return _checkInDueToday != null;
  }

  List<ArchiveCleanSection> get _archiveCleanSections =>
      buildArchiveCleanSections(
        keyMoments: _keyMoments,
        memory: _patternMemory,
        summary: _archiveMemory,
        timeline: _archiveTimeline,
        hasCheckInToday: _hasCheckInToday,
        hasCompressionGroups: _compressionGroups.isNotEmpty,
        now: _archiveCleanNow,
      );

  bool get _showArchiveCleanView => _archiveCleanSections.isNotEmpty;

  bool get _showPatternProfile =>
      buildPatternProfile(
        memory: _patternMemory,
        summary: _archiveMemory,
        map: _patternMemory != null
            ? buildPatternMap(memory: _patternMemory!, moments: _keyMoments)
            : null,
        timeline: _archiveTimeline,
        keyMoments: _keyMoments,
      ) !=
      null;

  bool get _hasMemoryNextCheck => _archiveMemory?.hasNextCheck ?? false;

  PatternsStackDecision get _stackDecision {
    final hasStandaloneNextCheck =
        !_hasMemoryNextCheck && _patternNextAction != null;
    return decidePatternsStack(
      hasActiveCheckIn:
          _missedCheckInForDiagnosis != null ||
          _checkInDueToday != null ||
          _checkInCompletedRecently != null,
      hasArchiveMemory: _archiveMemory != null,
      hasNextCheck:
          _hasMemoryNextCheck ||
          hasStandaloneNextCheck ||
          (_archiveTimeline?.hasNextCheck ?? false),
      hasArchiveCleanView: _showArchiveCleanView,
      hasPatternProfile: _showPatternProfile,
      hasRangeReview: _rangeReview?.hasEnoughData ?? false,
      hasArchiveCompression: _compressionGroups.isNotEmpty,
      hasTimeline: _archiveTimeline != null,
      hasProgress:
          _patternProgress != null ||
          _patternNextAction != null ||
          _habitProof != null ||
          _patternMemory != null ||
          _activePatternThread != null,
      hasRecap:
          _monthlyReview != null ||
          _patternWeeklyRecap != null ||
          (!_patternsHideAdvancedRetention &&
              (_weeklyRecap != null ||
                  _changeSummary != null ||
                  _returnComparison != null ||
                  (_returnStreak != null && _returnStreak!.showOnPatterns) ||
                  _watchForCompleted != null)),
      hasShare: _patternShareRecap != null,
      hasAnyMoment: _keyMoments.isNotEmpty || _entries.isNotEmpty,
      hasDueCheckStatusCard: _checkInDueToday != null,
    );
  }

  void _onArchiveCleanSectionTap(ArchiveCleanSection section) {
    context.push(section.route);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Compact, non-dominant entry point into the Key Moments timeline.
  Widget _findAMomentCard() {
    const warmSurface = Color(0xFFFFFBF5);
    const warmBorder = Color(0xFFF5E6D3);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: warmSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: warmBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.bookmark_border, size: 22, color: AppColors.accentPrimary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Find a moment',
                  style: VoiceMemoryTypography.cardTitleStyle().copyWith(
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Revisit useful moments by day.',
                  style: VoiceMemoryTypography.metadataStyle(
                    color: AppColors.textSecondary,
                  ).copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push('/moments'),
            child: const Text('Open key moments'),
          ),
        ],
      ),
    );
  }

  /// Compact, non-dominant entry point into Ask my Archive search.
  Widget _askArchiveCard() {
    const warmSurface = Color(0xFFFFFBF5);
    const warmBorder = Color(0xFFF5E6D3);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: warmSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: warmBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 22, color: AppColors.accentPrimary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ask my Archive',
                  style: VoiceMemoryTypography.cardTitleStyle().copyWith(
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Find what ArchiveMe remembers.',
                  style: VoiceMemoryTypography.metadataStyle(
                    color: AppColors.textSecondary,
                  ).copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push('/ask-archive'),
            child: const Text('Search moments'),
          ),
        ],
      ),
    );
  }

  /// Compact, non-dominant entry point into the Pattern map.
  Widget _patternMapCard() {
    const warmSurface = Color(0xFFFFFBF5);
    const warmBorder = Color(0xFFF5E6D3);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: warmSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: warmBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.hub_outlined, size: 22, color: AppColors.accentPrimary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pattern map',
                  style: VoiceMemoryTypography.cardTitleStyle().copyWith(
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'See what keeps repeating and what helps.',
                  style: VoiceMemoryTypography.metadataStyle(
                    color: AppColors.textSecondary,
                  ).copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push('/pattern-map'),
            child: const Text('Open map'),
          ),
        ],
      ),
    );
  }

  List<Widget> _insightSections() {
    final widgets = <Widget>[];
    void section(String heading, List<ArchiveInsight> items) {
      if (items.isEmpty) return;
      widgets.add(const SizedBox(height: AppSpacing.xl));
      widgets.add(BeliefSectionHeading(title: heading));
      widgets.add(const SizedBox(height: AppSpacing.sm));
      for (final insight in items.take(3)) {
        widgets.add(ArchiveInsightCard(insight: insight));
        widgets.add(const SizedBox(height: AppSpacing.sm));
      }
    }

    section(ConsumerUiCopy.patternsTensionsHeading, _insights.contradictions);
    section(ConsumerUiCopy.patternsEvolutionHeading, _insights.evolution);
    section(ConsumerUiCopy.patternsWorthNoticingHeading, _insights.blindSpots);
    section(
      ConsumerUiCopy.patternsWhatMayComeNextHeading,
      _insights.predictions,
    );
    return widgets;
  }

  List<Widget> _legacyBeliefSections(ArchiveBeliefCardModel strongest) {
    return [
      const BeliefSectionHeading(title: ConsumerUiCopy.patternsHeroHeading),
      const SizedBox(height: AppSpacing.sm),
      ArchiveHeroBeliefCard(
        belief: strongest,
        reflectionsAnalysed:
            _beliefs?.stats.reflectionsAnalysed ?? _entries.length,
      ),
      const SizedBox(height: AppSpacing.lg),
      if (_commitmentState == TomorrowCommitmentDisplayState.hidden)
        const PatternsComeBackTomorrowCard(),
      if (_commitmentState == TomorrowCommitmentDisplayState.hidden)
        const SizedBox(height: AppSpacing.xl),
      const BeliefSectionHeading(title: ConsumerUiCopy.patternsShiftingHeading),
      const SizedBox(height: AppSpacing.sm),
      BeliefChangeStories(items: _changing),
      ..._insightSections(),
      const SizedBox(height: AppSpacing.xl),
      const ArchiveRecordEvidenceCta(),
      const SizedBox(height: AppSpacing.md),
      const PatternsDeepLinks(),
      const SizedBox(height: AppSpacing.lg),
    ];
  }

  List<Widget> _activeCheckInStackWidgets() {
    final widgets = <Widget>[];
    if (_missedCheckInForDiagnosis != null) {
      widgets.add(
        MissedCheckInReasonPrompt(
          checkIn: _missedCheckInForDiagnosis!,
          onAnswered: () => setState(() => _missedCheckInForDiagnosis = null),
        ),
      );
    } else if (_checkInDueToday != null) {
      widgets.add(
        PatternsCheckInStatusCard.waiting(question: _checkInDueToday!.question),
      );
    } else if (_checkInCompletedRecently != null) {
      widgets.add(
        PatternsCheckInStatusCard.closed(completed: _checkInCompletedRecently),
      );
      widgets.add(const SizedBox(height: AppSpacing.lg));
      if (_checkInCompletedRecently!.selectedOptionId == 'heavier') {
        widgets.add(
          KinderAngleCard(
            reflectionText: '',
            patternTitle: _checkInCompletedRecently!.patternTitle,
            specificPrompt: _checkInCompletedRecently!.prompt,
            resultHint: _checkInCompletedRecently!.selectedOptionId ?? 'same',
            trigger: KinderAngleTrigger.genericHardMoment,
            compact: true,
            fromPatterns: true,
          ),
        );
      } else {
        widgets.add(
          PerspectiveShiftCard(
            reflectionText: '',
            resultHint: _checkInCompletedRecently!.selectedOptionId ?? 'same',
            checkInQuestion: _checkInCompletedRecently!.question,
            patternTitle: _checkInCompletedRecently!.patternTitle,
            specificPrompt: _checkInCompletedRecently!.prompt,
            compact: true,
            fromPatterns: true,
          ),
        );
      }
    }
    if (widgets.isNotEmpty) {
      widgets.add(const SizedBox(height: AppSpacing.lg));
    }
    final retention = _patternsRetentionCard();
    if (retention != null) {
      widgets.add(retention);
      widgets.add(const SizedBox(height: AppSpacing.lg));
    }
    return widgets;
  }

  CurrentObjective _buildPatternsObjective() {
    final state = buildRetentionState(
      now: DateTime.now(),
      activeCheckIn: _checkInDueToday ?? _activeCheckInForTomorrow,
      missedCheckIn: _missedCheckInForDiagnosis == null
          ? _recentMissedCheckIn
          : null,
      hasClosedLoopToday:
          _checkInCompletedRecently != null &&
          _activeCheckInForTomorrow == null &&
          _checkInDueToday == null,
      hasChosenNextCheck:
          _retentionDismissed == false &&
          _activeCheckInForTomorrow != null &&
          _checkInDueToday == null,
      latestNextCheck:
          _activeCheckInForTomorrow?.question ??
          _checkInCompletedRecently?.tomorrowsBetterQuestion,
      latestPatternTitle:
          _activeCheckInForTomorrow?.patternTitle ??
          _checkInCompletedRecently?.patternTitle,
      compact: true,
    );
    return buildCurrentObjective(
      retentionState: state,
      activeCheckIn: _checkInDueToday ?? _activeCheckInForTomorrow,
      hasAnyMoment: _keyMoments.isNotEmpty || _entries.isNotEmpty,
      hasClosedLoopToday:
          _checkInCompletedRecently != null &&
          _activeCheckInForTomorrow == null &&
          _checkInDueToday == null,
      hasNextCheckChosen:
          _activeCheckInForTomorrow != null &&
          _checkInDueToday == null &&
          !_retentionDismissed,
      latestNextCheck:
          _activeCheckInForTomorrow?.question ??
          _checkInCompletedRecently?.tomorrowsBetterQuestion,
      latestPatternTitle:
          _activeCheckInForTomorrow?.patternTitle ??
          _checkInCompletedRecently?.patternTitle,
    );
  }

  Widget? _patternsObjectiveCard() {
    if (ScreenshotMode.enabled) {
      if (ScreenshotMode.objectiveDueCheckPreview) {
        return CurrentObjectiveCard(
          objective: ScreenshotSampleData.objectiveDueCheckSample,
          compact: true,
          persistSnapshot: false,
        );
      }
      if (ScreenshotMode.objectiveFirstMomentPreview) {
        return CurrentObjectiveCard(
          objective: ScreenshotSampleData.objectiveFirstMomentSample,
          compact: true,
          persistSnapshot: false,
        );
      }
      if (ScreenshotMode.objectiveNextReadyPreview) {
        return CurrentObjectiveCard(
          objective: ScreenshotSampleData.objectiveNextReadySample,
          compact: true,
          persistSnapshot: false,
        );
      }
    }
    if (!_stackDecision.showCurrentObjectiveCard) return null;
    final objective = _buildPatternsObjective();
    return CurrentObjectiveCard(
      objective: objective,
      compact: true,
      onPrimaryTap: () => _onPatternsObjectivePrimary(objective),
      persistSnapshot: !ScreenshotMode.enabled,
    );
  }

  void _onPatternsObjectivePrimary(CurrentObjective objective) {
    switch (objective.type) {
      case CurrentObjectiveType.doneForToday:
        setState(() => _retentionDismissed = true);
      case CurrentObjectiveType.recordFirstMoment:
      case CurrentObjectiveType.recordAnyMoment:
      case CurrentObjectiveType.answerTodayCheck:
      case CurrentObjectiveType.chooseNextCheck:
        context.go('/record');
    }
  }

  Widget? _patternsRetentionCard() {
    final state = buildRetentionState(
      now: DateTime.now(),
      activeCheckIn: _checkInDueToday ?? _activeCheckInForTomorrow,
      missedCheckIn: _missedCheckInForDiagnosis == null
          ? _recentMissedCheckIn
          : null,
      hasClosedLoopToday:
          _checkInCompletedRecently != null &&
          _activeCheckInForTomorrow == null &&
          _checkInDueToday == null,
      latestNextCheck:
          _activeCheckInForTomorrow?.question ??
          _checkInCompletedRecently?.tomorrowsBetterQuestion,
      latestPatternTitle:
          _activeCheckInForTomorrow?.patternTitle ??
          _checkInCompletedRecently?.patternTitle,
      compact: true,
    );
    if (_retentionDismissed &&
        state.type == RetentionStateType.nextCheckChosen) {
      return null;
    }
    if (retentionStateDuplicatesPatternsCheckInCard(
      type: state.type,
      hasDueCheckStatusCard: _checkInDueToday != null,
      hasMissedPrompt: _missedCheckInForDiagnosis != null,
      hasClosedLoopCard: _checkInCompletedRecently != null,
    )) {
      return null;
    }
    return RetentionStateCard(
      state: state,
      onPrimaryTap: () {
        switch (state.type) {
          case RetentionStateType.noCheckSet:
          case RetentionStateType.checkMissed:
            context.go('/record');
          case RetentionStateType.checkDueToday:
          case RetentionStateType.checkSetForTomorrow:
            context.go('/record');
          case RetentionStateType.loopClosed:
            context.go('/record');
          case RetentionStateType.nextCheckChosen:
            setState(() => _retentionDismissed = true);
        }
      },
      onDismiss: () => setState(() => _retentionDismissed = true),
    );
  }

  List<Widget> _fallbackEntryCards(PatternsStackDecision decision) {
    final widgets = <Widget>[];
    if (!decision.suppressSeparateFindMomentCard) {
      widgets.add(_findAMomentCard());
      widgets.add(const SizedBox(height: AppSpacing.sm));
    }
    if (!decision.suppressSeparatePatternMapCard) {
      widgets.add(_patternMapCard());
      widgets.add(const SizedBox(height: AppSpacing.sm));
    }
    if (!decision.suppressSeparateAskArchiveCard) {
      widgets.add(_askArchiveCard());
      widgets.add(const SizedBox(height: AppSpacing.sm));
    }
    if (widgets.isNotEmpty) {
      widgets.add(const SizedBox(height: AppSpacing.sm));
    }
    return widgets;
  }

  List<Widget> _sectionWidgets(
    PatternsSectionType type,
    PatternsStackDecision decision,
  ) {
    switch (type) {
      case PatternsSectionType.activeCheckIn:
        return _activeCheckInStackWidgets();
      case PatternsSectionType.archiveMemory:
        if (_archiveMemory != null) {
          return [
            ArchiveMemorySummaryCard(
              summary: _archiveMemory!,
              showEntryLinks: !decision.suppressSeparatePatternMapCard,
              showFeedback: true,
              onOpenPatternMap: () => context.push('/pattern-map'),
              onFindMoments: () => context.push('/moments'),
              onUseCheck: _useArchiveMemoryCheck,
            ),
            const SizedBox(height: AppSpacing.lg),
          ];
        }
        if (!_showEmpty) {
          return [
            ArchiveMemoryEmptyPreviewCard(onRecord: _goToRecord),
            const SizedBox(height: AppSpacing.lg),
          ];
        }
        return const [];
      case PatternsSectionType.nextCheck:
        if (_patternNextAction == null) return const [];
        return [
          PatternNextActionCard(
            action: _patternNextAction!,
            onUse: () => _usePatternNextAction(_patternNextAction!),
          ),
          const SizedBox(height: AppSpacing.lg),
        ];
      case PatternsSectionType.archiveNavigation:
        return [
          ArchiveCleanViewCard(
            sections: _archiveCleanSections,
            onSectionTap: _onArchiveCleanSectionTap,
          ),
          const SizedBox(height: AppSpacing.lg),
        ];
      case PatternsSectionType.patternProfile:
        return const [PatternProfileCard(), SizedBox(height: AppSpacing.sm)];
      case PatternsSectionType.rangeReview:
        if (_rangeReview == null || !_rangeReview!.hasEnoughData) {
          return const [];
        }
        return [
          ArchiveRangeReviewCard(
            review: _rangeReview!,
            onOpenReview: () => context.push('/archive-review'),
            onUseCheck: decision.suppressLowerPriorityCtas
                ? null
                : _useRangeReviewCheck,
          ),
          const SizedBox(height: AppSpacing.lg),
        ];
      case PatternsSectionType.archiveCompression:
        if (_compressionGroups.isEmpty) return const [];
        return [
          ArchiveCompressionCard(
            group: _compressionGroups.first,
            onKept: (g) =>
                _onCompressionAction(g, ArchiveCompressionCoordinator.markKept),
            onSplit: (g) => _onCompressionAction(
              g,
              ArchiveCompressionCoordinator.markSplit,
            ),
            onHidden: (g) => _onCompressionAction(
              g,
              ArchiveCompressionCoordinator.markHidden,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ];
      case PatternsSectionType.patternProgress:
        final widgets = <Widget>[];
        if (_patternProgress != null) {
          widgets.add(
            PatternProgressCard(
              progress: _patternProgress!,
              showRecordCta: _patternNextAction == null,
            ),
          );
          widgets.add(const SizedBox(height: AppSpacing.lg));
        }
        if (_patternNextAction != null &&
            !_hasMemoryNextCheck &&
            !decision.includes(PatternsSectionType.nextCheck)) {
          widgets.add(
            PatternNextActionCard(
              action: _patternNextAction!,
              onUse: () => _usePatternNextAction(_patternNextAction!),
            ),
          );
          widgets.add(const SizedBox(height: AppSpacing.lg));
        }
        if (_habitProof != null) {
          widgets.add(
            HabitProofCard(
              proof: _habitProof!,
              onUseNext: decision.suppressLowerPriorityCtas
                  ? null
                  : () => _useHabitProofNext(_habitProof!),
            ),
          );
          widgets.add(const SizedBox(height: AppSpacing.lg));
        }
        if (_patternMemory != null) {
          widgets.add(PatternMemoryCard(memory: _patternMemory!));
          widgets.add(const SizedBox(height: AppSpacing.lg));
        }
        if (_activePatternThread != null) {
          widgets.add(ActivePatternThreadCard(thread: _activePatternThread!));
          widgets.add(const SizedBox(height: AppSpacing.lg));
        }
        return widgets;
      case PatternsSectionType.timeline:
        if (_archiveTimeline == null) return const [];
        return [
          ArchiveEvolutionTimelineCard(
            timeline: _archiveTimeline!,
            showOpenTimeline: !decision.suppressSeparateTimelineCard,
            onOpenTimeline: () => context.push('/archive-timeline'),
            onUseCheck:
                decision.suppressLowerPriorityCtas ||
                    !_archiveTimeline!.hasNextCheck
                ? null
                : _useArchiveTimelineCheck,
          ),
          const SizedBox(height: AppSpacing.lg),
        ];
      case PatternsSectionType.recap:
        final widgets = <Widget>[];
        if (_monthlyReview != null) {
          widgets.add(
            MonthlyPatternReviewCard(
              review: _monthlyReview!,
              onUseCheck: _useMonthlyCheck,
            ),
          );
          widgets.add(const SizedBox(height: AppSpacing.xs));
          widgets.add(
            PrivateRecapActions(
              recap: PrivateRecapEngine.fromMonthlyReview(_monthlyReview!),
            ),
          );
          widgets.add(const SizedBox(height: AppSpacing.sm));
        }
        if (_patternWeeklyRecap != null) {
          widgets.add(
            weekly_recap_card.WeeklyPatternRecapCard(
              recap: _patternWeeklyRecap!,
              onUseNext: () => _usePatternWeeklyRecapNext(_patternWeeklyRecap!),
            ),
          );
          widgets.add(const SizedBox(height: AppSpacing.xs));
          widgets.add(
            PrivateRecapActions(
              recap: PrivateRecapEngine.fromWeeklyRecap(_patternWeeklyRecap!),
            ),
          );
          widgets.add(const SizedBox(height: AppSpacing.lg));
        }
        if (!_patternsHideAdvancedRetention && _watchForCompleted != null) {
          widgets.add(
            WatchForResultCard(
              completed: _watchForCompleted!,
              headline: ScreenshotMode.enabled
                  ? ScreenshotSampleData.watchForCompletedHeadline
                  : null,
              body: ScreenshotMode.enabled
                  ? ScreenshotSampleData.watchForCompletedBody
                  : null,
            ),
          );
          widgets.add(const SizedBox(height: AppSpacing.lg));
        }
        if (_commitment != null &&
            _commitmentState != TomorrowCommitmentDisplayState.hidden) {
          widgets.add(
            TomorrowReturnStatusCard(
              commitment: _commitment!,
              state: _commitmentState,
            ),
          );
          widgets.add(const SizedBox(height: AppSpacing.lg));
        }
        if (!_patternsHideAdvancedRetention &&
            _returnStreak != null &&
            _returnStreak!.showOnPatterns) {
          widgets.add(ReturnStreakCard(streak: _returnStreak!));
          widgets.add(const SizedBox(height: AppSpacing.lg));
        }
        if (!_patternsHideAdvancedRetention && _returnComparison != null) {
          widgets.add(ReturnComparisonCard(comparison: _returnComparison!));
          widgets.add(const SizedBox(height: AppSpacing.lg));
        }
        if (!_patternsHideAdvancedRetention && _changeSummary != null) {
          widgets.add(ChangeSummaryCard(summary: _changeSummary!));
          widgets.add(const SizedBox(height: AppSpacing.lg));
        }
        if (!_patternsHideAdvancedRetention && _weeklyRecap != null) {
          widgets.add(
            WeeklyPatternRecapCard(
              recap: _weeklyRecap!,
              onRecordNext: () => context.go('/record'),
            ),
          );
          widgets.add(const SizedBox(height: AppSpacing.lg));
        }
        return widgets;
      case PatternsSectionType.share:
        if (_patternShareRecap == null) return const [];
        return [
          PatternShareRecapCard(recap: _patternShareRecap!),
          const SizedBox(height: AppSpacing.lg),
        ];
      case PatternsSectionType.emptyState:
        return const [];
    }
  }

  bool _showArchiveIntelligenceProBridge({
    required ArchiveBeliefThread belief,
    required WeeklyWhatChangedReview weekly,
    required ArchiveOhWowMoment ohWow,
  }) {
    if (_archiveIsPro || _proBridgeResolved) return false;
    if (!FirstThreeSessionGates.showSoftProBridge(
      entryCount: _entries.length,
      resolved: _proBridgeResolved,
      isPro: _archiveIsPro,
    )) {
      return false;
    }
    return belief.hasEnoughData || weekly.hasReview || ohWow.hasMoment;
  }

  List<Widget> _buildArchiveIntelligenceWidgets({
    required PatternIntelligenceDisplayBundle bundle,
  }) {
    final belief = bundle.belief;
    final weekly = bundle.weekly;
    final ohWow = bundle.ohWow;
    final humanCopy = bundle.humanCopy;

    final widgets = <Widget>[];
    if (ohWow.hasMoment &&
        !ArchiveBeliefCorrectionStore.isDismissed(ohWow.suggestionId)) {
      widgets.add(ArchiveOhWowMomentCard(moment: ohWow, humanCopy: humanCopy));
      widgets.add(const SizedBox(height: AppSpacing.lg));
    }
    if (belief.hasEnoughData) {
      widgets.add(
        ArchiveBeliefThreadCard(
          thread: belief,
          humanCopy: humanCopy,
          onRecordMoreEvidence: _goToRecord,
          onDismissed: () => setState(() {}),
        ),
      );
      widgets.add(const SizedBox(height: AppSpacing.lg));
    }
    if (weekly.hasReview) {
      widgets.add(
        WeeklyWhatChangedReviewCard(review: weekly, humanCopy: humanCopy),
      );
      widgets.add(const SizedBox(height: AppSpacing.lg));
    }
    if (_showArchiveIntelligenceProBridge(
      belief: belief,
      weekly: weekly,
      ohWow: ohWow,
    )) {
      widgets.add(
        ArchiveIntelligenceProBridgeCard(
          onSeePro: () => context.push('/subscription'),
          onNotNow: () async {
            await RecordReturnProStore.instance().markProBridgeResolved();
            if (!mounted) return;
            setState(() => _proBridgeResolved = true);
          },
        ),
      );
      widgets.add(const SizedBox(height: AppSpacing.lg));
    }
    return widgets;
  }

  List<Widget> _archiveDifferentiationSurfaces() {
    final tier = _archiveIntelligenceTier;
    final bundle = PatternIntelligencePipeline.build(_entries, tier: tier);
    return _buildArchiveIntelligenceWidgets(bundle: bundle);
  }

  List<Widget> _orderedPatternsStack() {
    final decision = _stackDecision;
    final widgets = <Widget>[
      QuickHelpButton(
        alignment: Alignment.centerRight,
        patternTitle: _checkInCompletedRecently?.patternTitle,
        nextCheck: _checkInCompletedRecently?.question,
        onStartRecording: () async => _goToRecord(),
      ),
      const SizedBox(height: AppSpacing.sm),
    ];
    widgets.addAll(_archiveDifferentiationSurfaces());
    if (_signalArchiveSnapshot != null &&
        (_signalArchiveSnapshot!.hasActiveSignal ||
            _signalArchiveSnapshot!.reflectionCount > 0 ||
            _signalJourney != null)) {
      widgets.addAll(_signalArchiveSurfaces());
    }
    if (!decision.includes(PatternsSectionType.activeCheckIn)) {
      final objective = _patternsObjectiveCard();
      if (objective != null) {
        widgets.add(objective);
        widgets.add(const SizedBox(height: AppSpacing.lg));
      }
    }
    widgets.addAll(_fallbackEntryCards(decision));
    for (final section in decision.sections) {
      widgets.addAll(_sectionWidgets(section, decision));
      if (section == PatternsSectionType.activeCheckIn) {
        final objective = _patternsObjectiveCard();
        if (objective != null) {
          widgets.add(objective);
          widgets.add(const SizedBox(height: AppSpacing.lg));
        }
      }
    }
    final insightWidgets = _orderedArchiveInsightWidgets();
    if (insightWidgets.isNotEmpty) {
      widgets.addAll(insightWidgets);
    }
    return widgets;
  }

  /// Patterns-tab screenshot override — bypasses archive state and empty UI.
  Widget _buildForcedScreenshotRepeatCardView(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: ListView(
          key: const Key('force_screenshot_repeat_card_view'),
          padding: ArchiveMobileSpacing.pagePadding,
          children: [
            SecondSessionComparisonCard(
              key: const Key('force_screenshot_repeat_card'),
              comparison: ForceScreenshotRepeatCard.comparison,
              onGoDeeper: () => context.go('/record'),
              onRecordNextEvidence: () => context.go('/record'),
              onNotTheSame: () {},
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (ForceScreenshotRepeatCard.enabled) {
      return _buildForcedScreenshotRepeatCardView(context);
    }

    _queueJournalDriftCheck();
    _schedulePatternsInitialLoadIfVisible();

    Widget buildBody() => _buildPatternsTabBody(context);
    return PatternsTabStability.guard(
      builder: buildBody,
      fallbackBuilder: () => _buildPatternsNoClearPatternScaffold(
        context,
        reason: 'build_guard',
      ),
    );
  }

  Widget _buildPatternsTabBody(BuildContext context) {
    PatternsTabStability.logTabBuild(
      entryCount: _entries.length,
      patternCount: _patternCount,
    );

    if (_loading) {
      if (_entries.length >= 3 && isIntentionalEmptyArchive(_entries)) {
        return _buildPatternsNoClearPatternScaffold(
          context,
          reason: 'no_evidence_entries',
        );
      }
      return const Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_showEmpty) {
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: ArchiveMobileSpacing.pagePadding,
              children: _withLoopMapPrimarySurface(
                const [PatternsEmptyView(fillViewport: false)],
              ),
            ),
          ),
        ),
      );
    }

    if (_showFirstArchive) {
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: ArchiveMobileSpacing.pagePadding,
              children: _withLoopMapPrimarySurface([
                PatternsFirstArchiveView(
                  fillViewport: false,
                  savedEntryId: _firstArchiveEntryId,
                ),
              ]),
            ),
          ),
        ),
      );
    }

    if (_patternsFirstThreeStack) {
      final journey =
          _firstThreeJourney ??
          const FirstThreeJourneyEngine().build(
            reflectionCount: _entries.length,
            entries: _entries,
          );
      final secondSessionComparisonRaw =
          _entries.length == FirstThreeSessionGates.minEntriesForRepeatSurface
          ? const SecondSessionSignalEngine().build(_entries)
          : null;
      final humanInput = PatternHumanCopyInput.fromEntries(_entries);
      final secondSessionComparison = secondSessionComparisonRaw == null
          ? null
          : PatternDisplayCopyGate.sanitizeSecondSessionComparison(
              PatternIntelligencePipeline.applyHumanCopyToComparison(
                secondSessionComparisonRaw,
                humanInput,
              ),
            );
      final thirdSessionUsefulness =
          FirstThreeSessionGates.showSession3ArchiveSurface(_entries.length)
          ? const ThirdSessionArchiveUsefulnessEngine().build(_entries)
          : ThirdSessionArchiveUsefulness.insufficient;
      final intelligenceBundle = PatternIntelligencePipeline.build(
        _entries,
        tier: _archiveIntelligenceTier,
      );
      final strongest = _strongest;
      final patternProgress = _patternProgress;
      final patternNextAction = _patternNextAction;
      final habitProof = _habitProof;
      final patternWeeklyRecap = _patternWeeklyRecap;
      final patternShareRecap = _patternShareRecap;
      final patternMemory = _patternMemory;
      final activePatternThread = _activePatternThread;
      final selectedSignal = _selectedSignal;
      final signalArchiveSnapshot = _signalArchiveSnapshot;
      final firstLoopPhase = _firstLoopPhase;
      final missedCheckInForDiagnosis = _missedCheckInForDiagnosis;
      final checkInDueToday = _checkInDueToday;
      final checkInCompletedRecently = _checkInCompletedRecently;
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: ArchiveMobileSpacing.pagePadding,
              children: _withLoopMapPrimarySurface([
                if (_showArchiveLoopOnboardingBanner &&
                    _loopMapPrimarySurface?.state !=
                        LoopMapPrimarySurfaceState.newUser) ...[
                  ArchiveLoopOnboardingBanner(
                    onStart: () => context.go('/archive-loop-onboarding'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                ..._buildArchiveIntelligenceWidgets(bundle: intelligenceBundle),
                if (!intelligenceBundle.belief.hasEnoughData &&
                    thirdSessionUsefulness.hasEnoughData) ...[
                  ThirdSessionArchiveUsefulnessCard(
                    usefulness: thirdSessionUsefulness,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (secondSessionComparison != null &&
                    secondSessionComparison.hasEnoughData &&
                    !ArchiveBeliefCorrectionStore.isDismissed(
                      'second_session_repeat',
                    )) ...[
                  SecondSessionComparisonCard(
                    comparison: secondSessionComparison,
                    onGoDeeper: _goToRecord,
                    onRecordNextEvidence: _goToRecord,
                    onNotTheSame: () {
                      ArchiveBeliefCorrectionStore.dismiss(
                        'second_session_repeat',
                      );
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (firstLoopPhase != null &&
                    firstLoopPhase != FirstLoopStatePhase.recordMoment) ...[
                  FirstLoopStateCard(
                    phase: firstLoopPhase,
                    question: _firstLoop.tomorrowQuestion,
                    onRecord: _goToRecord,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (missedCheckInForDiagnosis != null) ...[
                  MissedCheckInReasonPrompt(
                    checkIn: missedCheckInForDiagnosis,
                    onAnswered: () =>
                        setState(() => _missedCheckInForDiagnosis = null),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ] else if (checkInDueToday != null) ...[
                  PatternsCheckInStatusCard.waiting(
                    question: checkInDueToday.question,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ] else if (checkInCompletedRecently != null) ...[
                  PatternsCheckInStatusCard.closed(
                    completed: checkInCompletedRecently,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (checkInCompletedRecently.selectedOptionId == 'heavier')
                    KinderAngleCard(
                      reflectionText: '',
                      patternTitle: checkInCompletedRecently.patternTitle,
                      specificPrompt: checkInCompletedRecently.prompt,
                      resultHint:
                          checkInCompletedRecently.selectedOptionId ?? 'same',
                      trigger: KinderAngleTrigger.genericHardMoment,
                      compact: true,
                      fromPatterns: true,
                    )
                  else
                    PerspectiveShiftCard(
                      reflectionText: '',
                      resultHint:
                          checkInCompletedRecently.selectedOptionId ?? 'same',
                      checkInQuestion: checkInCompletedRecently.question,
                      patternTitle: checkInCompletedRecently.patternTitle,
                      specificPrompt: checkInCompletedRecently.prompt,
                      compact: true,
                      fromPatterns: true,
                    ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (patternProgress != null) ...[
                  PatternProgressCard(
                    progress: patternProgress,
                    showRecordCta: patternNextAction == null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (patternNextAction != null) ...[
                  PatternNextActionCard(
                    action: patternNextAction,
                    onUse: () => _usePatternNextAction(patternNextAction),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (habitProof != null) ...[
                  HabitProofCard(
                    proof: habitProof,
                    onUseNext: () => _useHabitProofNext(habitProof),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (patternWeeklyRecap != null) ...[
                  weekly_recap_card.WeeklyPatternRecapCard(
                    recap: patternWeeklyRecap,
                    onUseNext: () =>
                        _usePatternWeeklyRecapNext(patternWeeklyRecap),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (patternShareRecap != null) ...[
                  PatternShareRecapCard(recap: patternShareRecap),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (patternMemory != null) ...[
                  PatternMemoryCard(memory: patternMemory),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (activePatternThread != null) ...[
                  ActivePatternThreadCard(thread: activePatternThread),
                  const SizedBox(height: AppSpacing.lg),
                ] else if (strongest != null) ...[
                  const BeliefSectionHeading(
                    title: ConsumerUiCopy.patternsHeroHeading,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ArchiveHeroBeliefCard(
                    belief: strongest,
                    reflectionsAnalysed:
                        _beliefs?.stats.reflectionsAnalysed ?? _entries.length,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (selectedSignal != null && !journey.completed) ...[
                  PatternsSignalsWaitingCard(
                    selected: selectedSignal,
                    reflectionCount: _entries.length,
                    nextPrompt: selectedSignal.nextPrompt,
                    onViewDetail: () =>
                        SignalArchiveNavigation.openSignalDetail(context),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (signalArchiveSnapshot != null &&
                    (signalArchiveSnapshot.hasActiveSignal ||
                        signalArchiveSnapshot.reflectionCount > 0 ||
                        _signalJourney != null)) ...[
                  ..._signalArchiveSurfaces(),
                ],
                if (!journey.completed) ...[
                  FirstThreeJourneyCard(model: journey),
                  const SizedBox(height: AppSpacing.lg),
                ],
                const PatternsComeBackTomorrowCard(),
                const SizedBox(height: AppSpacing.xl),
                const ArchiveRecordEvidenceCta(),
                const SizedBox(height: AppSpacing.lg),
              ]),
            ),
          ),
        ),
      );
    }

    if (!_hasRenderablePatternInsight) {
      if (_hasArchiveReactivityPatterns) {
        return Scaffold(
          backgroundColor: AppColors.backgroundPrimary,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: ArchiveMobileSpacing.pagePadding,
                children: _withLoopMapPrimarySurface(_safeOrderedPatternsStack()),
              ),
            ),
          ),
        );
      }
      return _buildPatternsNoClearPatternScaffold(
        context,
        reason: _patternsEmptyReason,
      );
    }

    final strongest = _strongest;
    if (strongest == null) {
      if (_hasArchiveReactivityPatterns) {
        return Scaffold(
          backgroundColor: AppColors.backgroundPrimary,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: ArchiveMobileSpacing.pagePadding,
                children: _withLoopMapPrimarySurface(_safeOrderedPatternsStack()),
              ),
            ),
          ),
        );
      }
      return _buildPatternsNoClearPatternScaffold(
        context,
        reason: 'null_belief_snapshot_or_field',
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: ArchiveMobileSpacing.pagePadding,
            children: _withLoopMapPrimarySurface([
              ..._safeOrderedPatternsStack(),
              ..._safeLegacyBeliefSections(strongest),
            ]),
          ),
        ),
      ),
    );
  }
}
