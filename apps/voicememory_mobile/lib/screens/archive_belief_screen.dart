import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/archive_mobile_spacing.dart';
import '../config/screenshot_mode.dart';
import '../config/force_screenshot_repeat_card.dart';
import '../config/screenshot_sample_data.dart';
import '../design/empty_archive_experience.dart';
import '../features/archive_evidence/archive_belief_correction_store.dart';
import '../features/archive_evidence/archive_belief_thread_engine.dart';
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
import '../features/archive_proof/archive_belief_surface.dart';
import '../features/archive_proof/archive_change_timeline_metrics_store.dart';
import '../features/archive_proof/archive_paid_value_proof_source.dart';
import '../features/archive_proof/archive_proof_record_routes.dart';
import '../features/archive_proof/visible_archive_proof_copy.dart';
import '../widgets/patterns/archive_belief_surface_card.dart';
import '../widgets/patterns/archive_paid_value_proof_card.dart';
import '../widgets/patterns/archive_oh_wow_moment_card.dart';
import '../widgets/patterns/archive_intelligence_pro_bridge_card.dart';
import '../widgets/patterns/weekly_what_changed_review_card.dart';
import '../billing/archive_entitlement_reader.dart';
import '../widgets/patterns/watch_for_result_card.dart';
import '../features/activation/first_three_session_gates.dart';
import '../features/archive_evidence/archive_evidence_guard.dart';
import '../features/activation/second_session_payoff.dart';
import '../features/activation/third_entry_belief_payoff.dart';
import '../features/activation/belief_update_payoff.dart';
import '../features/activation/belief_evidence_trail.dart';
import '../features/activation/belief_history_timeline.dart';
import '../features/activation/archive_home_summary.dart';
import '../features/activation/archive_evidence_map.dart';
import '../features/activation/evidence_attention_filters.dart';
import '../features/activation/archive_workspace_layout.dart';
import '../features/activation/archive_workspace_quick_actions.dart';
import '../features/activation/archive_workspace_hints.dart';
import '../features/activation/archive_workspace_hint_store.dart';
import '../features/activation/context_insights.dart';
import '../features/activation/archive_health_action_plan.dart';
import '../features/activation/archive_health_score.dart';
import '../features/activation/insight_quality_dashboard.dart';
import '../features/activation/weekly_archive_review.dart';
import '../features/share/archive_share_actions.dart';
import '../features/pressure_retention/shareable_archive_proof_engine.dart';
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
import '../widgets/record/second_session_payoff_card.dart';
import '../widgets/record/third_entry_belief_payoff_card.dart';
import '../widgets/record/belief_update_payoff_card.dart';
import '../widgets/archive/belief_history_timeline_card.dart';
import '../widgets/archive/weekly_archive_review_card.dart';
import '../widgets/archive/archive_home_summary_card.dart';
import '../widgets/archive/archive_evidence_map_card.dart';
import '../widgets/archive/evidence_attention_filters_card.dart';
import '../widgets/archive/archive_workspace_section_heading.dart';
import '../widgets/archive/archive_workspace_quick_actions_card.dart';
import '../widgets/archive/archive_workspace_hint_card.dart';
import '../widgets/archive/context_insights_card.dart';
import '../widgets/archive/archive_health_action_plan_card.dart';
import '../widgets/archive/archive_health_card.dart';
import '../widgets/pressure_retention/shareable_archive_proof_card.dart';

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
  bool _loading = true;
  bool _reloadScheduled = false;
  bool _archiveIsPro = false;
  bool _proBridgeResolved = false;
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
    if (peek.isEmpty || peek.length == 1) {
      _entries = peek;
      _loading = false;
    }
    _load();
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
    await ArchiveBeliefCorrectionStore.ensureLoaded();
    await ArchiveWorkspaceHintStore.ensureLoaded();
    final isPro = await ArchiveEntitlementReader.forAccessCheck().isPro;
    final recordReturnPro = await RecordReturnProStore.instance().load();
    final entries = await AppServices.instance.journal.loadAll();
    if (!mounted) return;

    if (entries.isEmpty) {
      setState(() {
        _entries = entries;
        _beliefs = null;
        _changing = const [];
        _insights = ArchiveInsightsSnapshot.empty;
        _loading = false;
      });
      First25UserMetrics.trackArchiveOpened(surface: 'archive_beliefs_empty');
      return;
    }

    if (entries.length == 1) {
      setState(() {
        _archiveIsPro = isPro;
        _proBridgeResolved = recordReturnPro.proBridgeResolved;
        _entries = entries;
        _beliefs = null;
        _changing = const [];
        _insights = ArchiveInsightsSnapshot.empty;
        _loading = false;
      });
      First25UserMetrics.trackArchiveOpened(
        surface: 'archive_beliefs_first_entry',
      );
      return;
    }

    if (isIntentionalEmptyArchive(entries)) {
      setState(() {
        _archiveIsPro = isPro;
        _proBridgeResolved = recordReturnPro.proBridgeResolved;
        _entries = entries;
        _beliefs = null;
        _changing = const [];
        _insights = ArchiveInsightsSnapshot.empty;
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

    final commitment = await TomorrowCommitmentCoordinator.load();
    final commitmentState = commitment == null
        ? TomorrowCommitmentDisplayState.hidden
        : commitment.displayState(DateTime.now());
    final comparison = await ReturnComparisonCoordinator.loadLatest();
    final streak = await ReturnRetentionCoordinator.loadStreak();
    final changeSummary = await ReturnRetentionCoordinator.loadChangeSummary();
    final weeklyRecap = await ReturnRetentionCoordinator.loadWeeklyRecap();
    final watchForCompleted = await WatchForCoordinator.loadLatestCompleted();
    final activeThread =
        await ActivePatternThreadCoordinator.loadCurrentThread();
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
    setState(() {
      _archiveIsPro = isPro;
      _proBridgeResolved = recordReturnPro.proBridgeResolved;
      _entries = entries;
      _firstLoop = firstLoop;
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
    if (shell != null && shell.currentIndex != 1) return;

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
      if (activeShell != null && activeShell.currentIndex != 1) return;
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

  bool get _suppressEarlyArchiveBeliefProof {
    if (!_patternsFirstThreeStack) return false;
    if (_entries.length < FirstThreeSessionGates.minEntriesForRepeatSurface) {
      return true;
    }
    if (_entries.length == FirstThreeSessionGates.minEntriesForRepeatSurface) {
      return !const SecondSessionSignalEngine().hasGroundedRepeatMatch(
        _entries,
      );
    }
    return false;
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

  Future<void> _shareArchiveProofSafely() async {
    final proof =
        const ShareableArchiveProofEngine().buildFromJournal(entries: _entries);
    if (!proof.hasProof || !ArchiveShareActions.isShareable(proof.shareText)) {
      return;
    }
    await ArchiveShareActions.shareShareText(context, text: proof.shareText);
  }

  void _onArchiveWorkspaceQuickAction(ArchiveWorkspaceQuickAction action) {
    switch (action.destination) {
      case ArchiveWorkspaceQuickActionDestination.record:
        _goToRecord();
      case ArchiveWorkspaceQuickActionDestination.untaggedDrilldown:
      case ArchiveWorkspaceQuickActionDestination.insightQuality:
      case ArchiveWorkspaceQuickActionDestination.archiveBelief:
      case ArchiveWorkspaceQuickActionDestination.weeklyReview:
        final route = action.resolveRoute();
        if (route != null) context.push(route);
      case ArchiveWorkspaceQuickActionDestination.shareProof:
        unawaited(_shareArchiveProofSafely());
    }
  }

  void _dismissWorkspaceHint(String hintId) {
    ArchiveWorkspaceHintStore.dismiss(hintId);
    setState(() {});
  }

  Widget? _workspaceHintWidget(ArchiveWorkspaceHint? hint) {
    if (hint == null) return null;
    return ArchiveWorkspaceHintCard(
      hint: hint,
      onDismiss: () => _dismissWorkspaceHint(hint.hintId),
    );
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
        reflectionsAnalysed: _beliefs!.stats.reflectionsAnalysed,
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
            metricsStore: _timelineMetricsStore,
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
    required ArchiveBeliefThread belief,
    required WeeklyWhatChangedReview weekly,
    required ArchiveOhWowMoment ohWow,
  }) {
    final widgets = <Widget>[];
    if (ohWow.hasMoment &&
        !ArchiveBeliefCorrectionStore.isDismissed(ohWow.suggestionId)) {
      widgets.add(ArchiveOhWowMomentCard(moment: ohWow));
      widgets.add(const SizedBox(height: AppSpacing.lg));
    }
    if (belief.hasEnoughData) {
      // Belief proof surface renders above timeline via [_buildArchiveBeliefProofWidgets].
    }
    if (weekly.hasReview) {
      widgets.add(WeeklyWhatChangedReviewCard(review: weekly));
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
    const engine = ArchiveBeliefThreadEngine();
    final belief = engine.build(_entries, tier: tier);
    final weekly = const WeeklyWhatChangedReviewEngine().build(
      _entries,
      tier: tier,
    );
    final ohWow = engine.buildOhWow(_entries, tier: tier);
    return _buildArchiveIntelligenceWidgets(
      belief: belief,
      weekly: weekly,
      ohWow: ohWow,
    );
  }

  ArchiveChangeTimelineMetricsStore get _timelineMetricsStore =>
      ArchiveChangeTimelineMetricsStore(AppServices.instance.prefs);

  List<Widget> _buildArchiveBeliefProofWidgets() {
    final surface = ArchiveBeliefSurfaceSource().resolve(
      _entries,
      tier: _archiveIntelligenceTier,
    );
    if (!surface.shouldShow) return const [];
    return [
      ArchiveBeliefSurfaceCard(
        surface: surface,
        onRecordNext: () => context.go(
          ArchiveProofRecordRoutes.uri(
            guidedPromptNodeKey: ArchiveProofRecordRoutes.changeTimelineNodeKey,
          ),
        ),
        onDismissed: () => setState(() {}),
      ),
      const SizedBox(height: AppSpacing.lg),
    ];
  }

  ArchiveHomeSummary _archiveHomeSummary() =>
      ArchiveHomeSummaryEngine.build(entries: _entries);

  void _handleArchiveHomeAction(ArchiveHomeAction action) {
    switch (action) {
      case ArchiveHomeAction.record:
      case ArchiveHomeAction.addMoment:
        _goToRecord();
      case ArchiveHomeAction.viewArchive:
        if (_entries.isEmpty) break;
        final sorted = List<JournalEntry>.from(_entries)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        context.push('/entry/${sorted.first.id}');
      case ArchiveHomeAction.typeInstead:
        context.push('/quick-capture');
      case ArchiveHomeAction.viewEvidence:
        context.push(BeliefEvidenceNavigation.route);
      case ArchiveHomeAction.viewReview:
        context.push(WeeklyArchiveReviewNavigation.route);
      case ArchiveHomeAction.none:
        break;
    }
  }

  ArchiveWorkspaceLayout _archiveWorkspaceLayout() {
    final summary = _archiveHomeSummary();
    final beliefHistory =
        ArchiveEvidenceGuard.eligibleReflectionCount(_entries) >= 5
            ? BeliefHistoryTimelineEngine.build(entries: _entries)
            : null;
    final weeklyReview =
        ArchiveEvidenceGuard.eligibleReflectionCount(_entries) >= 5
            ? WeeklyArchiveReviewEngine.build(entries: _entries)
            : null;
    final shareProof =
        const ShareableArchiveProofEngine().buildFromJournal(entries: _entries);

    return ArchiveWorkspaceLayoutEngine.build(
      entries: _entries,
      archiveHome: summary,
      attentionFilters: EvidenceAttentionFiltersEngine.build(
        entries: _entries,
        omitKinds: const {EvidenceAttentionFilterKind.sameContext},
      ),
      actionPlan: ArchiveHealthActionPlanEngine.build(entries: _entries),
      archiveHealth: ArchiveHealthScoreEngine.build(entries: _entries),
      contextInsights: ContextInsightsEngine.build(entries: _entries),
      evidenceMap: ArchiveEvidenceMapEngine.build(entries: _entries),
      beliefHistory: beliefHistory,
      weeklyReview: weeklyReview,
      shareProof: shareProof,
    );
  }

  List<Widget> _archiveWorkspaceSectionSpacer() => const [
        SizedBox(height: AppSpacing.lg),
      ];

  List<Widget> _archiveHomeCommandCenterWidgets() {
    final summary = _archiveHomeSummary();
    final shareProof = summary.showShareProof
        ? const ShareableArchiveProofEngine().buildFromJournal(entries: _entries)
        : null;
    final layout = _archiveWorkspaceLayout();
    final actionPlan = ArchiveHealthActionPlanEngine.build(entries: _entries);
    final attentionFilters = EvidenceAttentionFiltersEngine.build(
      entries: _entries,
      omitKinds: const {EvidenceAttentionFilterKind.sameContext},
    );
    final archiveHealth = ArchiveHealthScoreEngine.build(entries: _entries);
    final contextInsights = ContextInsightsEngine.build(entries: _entries);
    final evidenceMap = ArchiveEvidenceMapEngine.build(entries: _entries);
    final beliefHistory =
        ArchiveEvidenceGuard.eligibleReflectionCount(_entries) >= 5
            ? BeliefHistoryTimelineEngine.build(entries: _entries)
            : null;
    final weeklyReview =
        ArchiveEvidenceGuard.eligibleReflectionCount(_entries) >= 5
            ? WeeklyArchiveReviewEngine.build(entries: _entries)
            : null;
    final standaloneShareProof =
        const ShareableArchiveProofEngine().buildFromJournal(entries: _entries);
    final quickActions = ArchiveWorkspaceQuickActionsEngine.build(
      entries: _entries,
      archiveHome: summary,
      workspaceLayout: layout,
      evidenceMapVisible: evidenceMap.showCard,
      weeklyReview: weeklyReview,
      shareProof: standaloneShareProof,
    );
    final hints = ArchiveWorkspaceHintsEngine.build(layout: layout);

    final widgets = <Widget>[
      ArchiveHomeSummaryCard(
        summary: summary,
        onPrimary: () => _handleArchiveHomeAction(summary.primaryAction),
        onSecondary: summary.secondaryAction != ArchiveHomeAction.none
            ? () => _handleArchiveHomeAction(summary.secondaryAction)
            : null,
        shareProof: shareProof?.hasProof == true ? shareProof : null,
      ),
    ];

    if (hints.introHint case final introHint?) {
      widgets.add(const SizedBox(height: AppSpacing.md));
      widgets.add(_workspaceHintWidget(introHint)!);
    }

    if (quickActions.showCard) {
      widgets.add(const SizedBox(height: AppSpacing.md));
      widgets.add(
        ArchiveWorkspaceQuickActionsCard(
          quickActions: quickActions,
          onActionTap: _onArchiveWorkspaceQuickAction,
        ),
      );
    }

    if (layout.needsAttention.show) {
      widgets.addAll(_archiveWorkspaceSectionSpacer());
      if (layout.needsAttention.heading case final heading?) {
        widgets.add(
          ArchiveWorkspaceSectionHeading(
            sectionId: 'needs_attention',
            title: heading,
          ),
        );
      }
      if (hints.needsAttentionHint case final sectionHint?) {
        widgets.add(const SizedBox(height: AppSpacing.xs));
        widgets.add(_workspaceHintWidget(sectionHint)!);
      }
      if (layout.showAttentionFilters) {
        widgets.add(
          EvidenceAttentionFiltersCard(
            filters: attentionFilters,
            hideTitle: layout.needsAttention.heading != null,
            onFilterTap: (filter) {
              final route = filter.resolveRoute();
              if (route != null) context.push(route);
            },
          ),
        );
        if (layout.showActionPlan) {
          widgets.add(const SizedBox(height: AppSpacing.md));
        }
      }
      if (layout.showActionPlan) {
        widgets.add(
          ArchiveHealthActionPlanCard(
            plan: actionPlan,
            onPrimary: _goToRecord,
            onSecondary: actionPlan.secondaryAction ==
                    ArchiveHealthActionPlanCta.viewEvidence
                ? () => context.push(BeliefEvidenceNavigation.route)
                : null,
          ),
        );
      }
    }

    if (layout.evidenceQuality.show) {
      widgets.addAll(_archiveWorkspaceSectionSpacer());
      if (layout.evidenceQuality.heading case final heading?) {
        widgets.add(
          ArchiveWorkspaceSectionHeading(
            sectionId: 'evidence_quality',
            title: heading,
          ),
        );
      }
      if (hints.evidenceQualityHint case final sectionHint?) {
        widgets.add(const SizedBox(height: AppSpacing.xs));
        widgets.add(_workspaceHintWidget(sectionHint)!);
      }
      var addedQualityCard = false;
      void addQualityCard(Widget card) {
        if (addedQualityCard) {
          widgets.add(const SizedBox(height: AppSpacing.md));
        }
        widgets.add(card);
        addedQualityCard = true;
      }

      if (layout.showArchiveHealth) {
        addQualityCard(ArchiveHealthCard(score: archiveHealth));
      }
      if (layout.showContextInsights) {
        addQualityCard(ContextInsightsCard(insights: contextInsights));
      }
      if (layout.showEvidenceMap) {
        addQualityCard(
          ArchiveEvidenceMapCard(
            map: evidenceMap,
            onRowTap: (tagId) => context.push(
              ArchiveEvidenceMapNavigation.contextPath(tagId),
            ),
          ),
        );
      }
    }

    if (layout.reviewHistory.show) {
      widgets.addAll(_archiveWorkspaceSectionSpacer());
      if (layout.reviewHistory.heading case final heading?) {
        widgets.add(
          ArchiveWorkspaceSectionHeading(
            sectionId: 'review_history',
            title: heading,
          ),
        );
      }
      if (hints.reviewHistoryHint case final sectionHint?) {
        widgets.add(const SizedBox(height: AppSpacing.xs));
        widgets.add(_workspaceHintWidget(sectionHint)!);
      }
      if (layout.showBeliefHistory && beliefHistory != null) {
        widgets.add(BeliefHistoryTimelineCard(timeline: beliefHistory));
      }
      if (layout.showWeeklyReview && weeklyReview != null) {
        if (layout.showBeliefHistory) {
          widgets.add(const SizedBox(height: AppSpacing.md));
        }
        widgets.add(
          WeeklyArchiveReviewCard(
            review: weeklyReview,
            compact: true,
            onViewFullReview: () =>
                context.push(WeeklyArchiveReviewNavigation.route),
            onAddAnother: _goToRecord,
          ),
        );
      }
    }

    if (layout.controls.show) {
      widgets.addAll(_archiveWorkspaceSectionSpacer());
      if (layout.controls.heading case final heading?) {
        widgets.add(
          ArchiveWorkspaceSectionHeading(
            sectionId: 'controls',
            title: heading,
          ),
        );
      }
      if (layout.showInsightQualityLink) {
        widgets.add(
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('archive_belief_insight_quality_link'),
              onPressed: () => context.push(InsightQualityNavigation.route),
              child: Text(VisibleArchiveProofCopy.insightQualityArchiveLink),
            ),
          ),
        );
      }
      if (layout.showStandaloneShareProof && standaloneShareProof.hasProof) {
        if (layout.showInsightQualityLink) {
          widgets.add(const SizedBox(height: AppSpacing.md));
        }
        widgets.add(ShareableArchiveProofCard(proof: standaloneShareProof));
      }
    }

    widgets.add(const SizedBox(height: AppSpacing.lg));
    return widgets;
  }

  List<Widget> _orderedPatternsStack() {
    final decision = _stackDecision;
    const engine = ArchiveBeliefThreadEngine();
    final belief = engine.build(_entries, tier: _archiveIntelligenceTier);
    final archiveHome = _archiveHomeSummary();
    final workspaceLayout = _archiveWorkspaceLayout();
    final widgets = <Widget>[
      QuickHelpButton(
        alignment: Alignment.centerRight,
        patternTitle: _checkInCompletedRecently?.patternTitle,
        nextCheck: _checkInCompletedRecently?.question,
        onStartRecording: () async => _goToRecord(),
      ),
      const SizedBox(height: AppSpacing.sm),
      ..._archiveHomeCommandCenterWidgets(),
    ];
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
    widgets.addAll(_buildArchiveBeliefProofWidgets());
    final beliefUpdatePayoff =
        ArchiveEvidenceGuard.eligibleReflectionCount(_entries) >= 4
            ? BeliefUpdatePayoffEngine.build(entries: _entries)
            : null;
    final beliefHistoryTimeline =
        ArchiveEvidenceGuard.eligibleReflectionCount(_entries) >= 5
            ? BeliefHistoryTimelineEngine.build(entries: _entries)
            : null;
    if (!archiveHome.suppressDuplicatePayoffCards && beliefUpdatePayoff != null) {
      widgets.add(
        BeliefUpdatePayoffCard(
          payoff: beliefUpdatePayoff,
          onAddAnother: _goToRecord,
          onViewEvidence: () => context.push(BeliefEvidenceNavigation.route),
        ),
      );
      widgets.add(const SizedBox(height: AppSpacing.lg));
    }
    if (!archiveHome.suppressDuplicatePayoffCards &&
        beliefHistoryTimeline != null &&
        !workspaceLayout.includesReviewHistoryInWorkspace) {
      widgets.add(BeliefHistoryTimelineCard(timeline: beliefHistoryTimeline));
      widgets.add(const SizedBox(height: AppSpacing.lg));
    }
    final weeklyArchiveReview =
        ArchiveEvidenceGuard.eligibleReflectionCount(_entries) >= 5
            ? WeeklyArchiveReviewEngine.build(entries: _entries)
            : null;
    if (!archiveHome.suppressDuplicatePayoffCards &&
        weeklyArchiveReview != null &&
        weeklyArchiveReview.hasEnoughEvidence &&
        !workspaceLayout.includesReviewHistoryInWorkspace) {
      widgets.add(
        WeeklyArchiveReviewCard(
          review: weeklyArchiveReview,
          compact: true,
          onViewFullReview: () =>
              context.push(WeeklyArchiveReviewNavigation.route),
          onAddAnother: _goToRecord,
        ),
      );
      widgets.add(const SizedBox(height: AppSpacing.lg));
    }
    final shareableProof = const ShareableArchiveProofEngine().buildFromJournal(
      entries: _entries,
    );
    if (!archiveHome.suppressDuplicatePayoffCards &&
        !archiveHome.showShareProof &&
        shareableProof.hasProof &&
        !workspaceLayout.includesStandaloneShareProofInWorkspace) {
      widgets.add(ShareableArchiveProofCard(proof: shareableProof));
      widgets.add(const SizedBox(height: AppSpacing.lg));
    }
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
    widgets.addAll(_archiveDifferentiationSurfaces());
    widgets.addAll(_fallbackEntryCards(decision));
    if (ArchivePaidValueProofSource.shouldShow(
      entryCount: _entries.where((e) => !e.isArchived).length,
      belief: belief,
      timeline: _archiveTimeline,
      returnProofSeen: _habitProof != null || _patternProgress != null,
    )) {
      widgets.add(const ArchivePaidValueProofCard());
      widgets.add(const SizedBox(height: AppSpacing.lg));
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

    if (_loading) {
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
              children: _archiveHomeCommandCenterWidgets(),
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
              children: _archiveHomeCommandCenterWidgets(),
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
      final archiveHome = _archiveHomeSummary();
      final workspaceLayout = _archiveWorkspaceLayout();
      final beliefUpdatePayoff =
          ArchiveEvidenceGuard.eligibleReflectionCount(_entries) >= 4
              ? BeliefUpdatePayoffEngine.build(entries: _entries)
              : null;
      final beliefHistoryTimeline =
          ArchiveEvidenceGuard.eligibleReflectionCount(_entries) >= 5
              ? BeliefHistoryTimelineEngine.build(entries: _entries)
              : null;
      final weeklyArchiveReview =
          ArchiveEvidenceGuard.eligibleReflectionCount(_entries) >= 5
              ? WeeklyArchiveReviewEngine.build(entries: _entries)
              : null;
      final shareableProof =
          const ShareableArchiveProofEngine().buildFromJournal(
        entries: _entries,
      );
      final thirdEntryBeliefPayoff =
          beliefUpdatePayoff == null &&
                  ArchiveEvidenceGuard.eligibleReflectionCount(_entries) ==
                      FirstThreeSessionGates.minEntriesForUsefulArchive
              ? ThirdEntryBeliefPayoffEngine.build(entries: _entries)
              : null;
      final secondSessionPayoff = _entries.length ==
              FirstThreeSessionGates.minEntriesForRepeatSurface
          ? SecondSessionPayoffEngine.build(entries: _entries)
          : null;
      final groundedSecondSessionRepeat =
          _entries.length > FirstThreeSessionGates.minEntriesForRepeatSurface &&
          const SecondSessionSignalEngine().hasGroundedRepeatMatch(_entries);
      final secondSessionComparison = groundedSecondSessionRepeat
          ? const SecondSessionSignalEngine().build(_entries)
          : null;
      final thirdSessionUsefulness =
          FirstThreeSessionGates.showSession3ArchiveSurface(_entries.length)
          ? const ThirdSessionArchiveUsefulnessEngine().build(_entries)
          : ThirdSessionArchiveUsefulness.insufficient;
      final archiveBeliefThread = const ArchiveBeliefThreadEngine().build(
        _entries,
        tier: _archiveIntelligenceTier,
      );
      final weeklyWhatChanged = const WeeklyWhatChangedReviewEngine().build(
        _entries,
        tier: _archiveIntelligenceTier,
      );
      final ohWowMoment = const ArchiveBeliefThreadEngine().buildOhWow(
        _entries,
        tier: _archiveIntelligenceTier,
      );
      final strongest = _strongest;
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: ArchiveMobileSpacing.pagePadding,
              children: [
                ..._archiveHomeCommandCenterWidgets(),
                if (!_suppressEarlyArchiveBeliefProof)
                  ..._buildArchiveBeliefProofWidgets(),
                if (!archiveHome.suppressDuplicatePayoffCards &&
                    beliefUpdatePayoff != null) ...[
                  BeliefUpdatePayoffCard(
                    payoff: beliefUpdatePayoff,
                    onAddAnother: _goToRecord,
                    onViewEvidence: () =>
                        context.push(BeliefEvidenceNavigation.route),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (!archiveHome.suppressDuplicatePayoffCards &&
                    beliefHistoryTimeline != null &&
                    !workspaceLayout.includesReviewHistoryInWorkspace) ...[
                  BeliefHistoryTimelineCard(timeline: beliefHistoryTimeline),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (!archiveHome.suppressDuplicatePayoffCards &&
                    weeklyArchiveReview != null &&
                    weeklyArchiveReview.hasEnoughEvidence &&
                    !workspaceLayout.includesReviewHistoryInWorkspace) ...[
                  WeeklyArchiveReviewCard(
                    review: weeklyArchiveReview,
                    compact: true,
                    onViewFullReview: () =>
                        context.push(WeeklyArchiveReviewNavigation.route),
                    onAddAnother: _goToRecord,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (!archiveHome.suppressDuplicatePayoffCards &&
                    !archiveHome.showShareProof &&
                    shareableProof.hasProof &&
                    !workspaceLayout.includesStandaloneShareProofInWorkspace) ...[
                  ShareableArchiveProofCard(proof: shareableProof),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (!archiveHome.suppressDuplicatePayoffCards &&
                    thirdEntryBeliefPayoff != null) ...[
                  ThirdEntryBeliefPayoffCard(
                    payoff: thirdEntryBeliefPayoff,
                    onAddAnother: _goToRecord,
                    onViewArchive: () {
                      if (_entries.isEmpty) return;
                      final sorted = List<JournalEntry>.from(_entries)
                        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                      context.push('/entry/${sorted.first.id}');
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (!archiveHome.suppressDuplicatePayoffCards &&
                    secondSessionPayoff != null) ...[
                  SecondSessionPayoffCard(
                    payoff: secondSessionPayoff,
                    onAddAnother: _goToRecord,
                    onViewArchive: () {
                      if (_entries.isEmpty) return;
                      final sorted = List<JournalEntry>.from(_entries)
                        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                      context.push('/entry/${sorted.first.id}');
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (!archiveHome.suppressDuplicatePayoffCards &&
                    !journey.completed &&
                    secondSessionPayoff == null) ...[
                  FirstThreeJourneyCard(model: journey),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (!archiveHome.suppressDuplicatePayoffCards &&
                    secondSessionComparison?.hasEnoughData == true &&
                    !ArchiveBeliefCorrectionStore.isDismissed(
                      'second_session_repeat',
                    )) ...[
                  SecondSessionComparisonCard(
                    comparison: secondSessionComparison!,
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
                if (!archiveHome.suppressDuplicatePayoffCards &&
                    !archiveBeliefThread.hasEnoughData &&
                    thirdSessionUsefulness.hasEnoughData &&
                    thirdEntryBeliefPayoff == null) ...[
                  ThirdSessionArchiveUsefulnessCard(
                    usefulness: thirdSessionUsefulness,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                ..._buildArchiveIntelligenceWidgets(
                  belief: archiveBeliefThread,
                  weekly: weeklyWhatChanged,
                  ohWow: ohWowMoment,
                ),
                if (!archiveHome.suppressDuplicatePayoffCards &&
                    _firstLoopPhase != null &&
                    _firstLoopPhase != FirstLoopStatePhase.recordMoment) ...[
                  FirstLoopStateCard(
                    phase: _firstLoopPhase!,
                    question: _firstLoop.tomorrowQuestion,
                    onRecord: _goToRecord,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (_missedCheckInForDiagnosis != null) ...[
                  MissedCheckInReasonPrompt(
                    checkIn: _missedCheckInForDiagnosis!,
                    onAnswered: () =>
                        setState(() => _missedCheckInForDiagnosis = null),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ] else if (_checkInDueToday != null) ...[
                  PatternsCheckInStatusCard.waiting(
                    question: _checkInDueToday!.question,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ] else if (_checkInCompletedRecently != null) ...[
                  PatternsCheckInStatusCard.closed(
                    completed: _checkInCompletedRecently,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (_checkInCompletedRecently!.selectedOptionId == 'heavier')
                    KinderAngleCard(
                      reflectionText: '',
                      patternTitle: _checkInCompletedRecently!.patternTitle,
                      specificPrompt: _checkInCompletedRecently!.prompt,
                      resultHint:
                          _checkInCompletedRecently!.selectedOptionId ?? 'same',
                      trigger: KinderAngleTrigger.genericHardMoment,
                      compact: true,
                      fromPatterns: true,
                    )
                  else
                    PerspectiveShiftCard(
                      reflectionText: '',
                      resultHint:
                          _checkInCompletedRecently!.selectedOptionId ?? 'same',
                      checkInQuestion: _checkInCompletedRecently!.question,
                      patternTitle: _checkInCompletedRecently!.patternTitle,
                      specificPrompt: _checkInCompletedRecently!.prompt,
                      compact: true,
                      fromPatterns: true,
                    ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (_patternProgress != null) ...[
                  PatternProgressCard(
                    progress: _patternProgress!,
                    showRecordCta: _patternNextAction == null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (_patternNextAction != null) ...[
                  PatternNextActionCard(
                    action: _patternNextAction!,
                    onUse: () => _usePatternNextAction(_patternNextAction!),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (_habitProof != null) ...[
                  HabitProofCard(
                    proof: _habitProof!,
                    onUseNext: () => _useHabitProofNext(_habitProof!),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (_patternWeeklyRecap != null) ...[
                  weekly_recap_card.WeeklyPatternRecapCard(
                    recap: _patternWeeklyRecap!,
                    onUseNext: () =>
                        _usePatternWeeklyRecapNext(_patternWeeklyRecap!),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (_patternShareRecap != null) ...[
                  PatternShareRecapCard(recap: _patternShareRecap!),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (_patternMemory != null) ...[
                  PatternMemoryCard(memory: _patternMemory!),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (_activePatternThread != null) ...[
                  ActivePatternThreadCard(thread: _activePatternThread!),
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
                if (_selectedSignal != null && !journey.completed) ...[
                  PatternsSignalsWaitingCard(
                    selected: _selectedSignal!,
                    reflectionCount: _entries.length,
                    nextPrompt: _selectedSignal!.nextPrompt,
                    onViewDetail: () =>
                        SignalArchiveNavigation.openSignalDetail(context),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (_signalArchiveSnapshot != null &&
                    (_signalArchiveSnapshot!.hasActiveSignal ||
                        _signalArchiveSnapshot!.reflectionCount > 0 ||
                        _signalJourney != null)) ...[
                  ..._signalArchiveSurfaces(),
                ],
                const PatternsComeBackTomorrowCard(),
                const SizedBox(height: AppSpacing.xl),
                const ArchiveRecordEvidenceCta(),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      );
    }

    final strongest = _strongest!;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: ArchiveMobileSpacing.pagePadding,
            children: [
              ..._orderedPatternsStack(),
              ..._legacyBeliefSections(strongest),
            ],
          ),
        ),
      ),
    );
  }
}
