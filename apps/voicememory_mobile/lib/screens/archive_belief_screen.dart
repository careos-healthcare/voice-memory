import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/archive_mobile_spacing.dart';
import '../config/archive_me_demo_state.dart';
import '../config/screenshot_mode.dart';
import '../config/force_screenshot_repeat_card.dart';
import '../config/screenshot_sample_data.dart';
import '../design/empty_archive_experience.dart';
import '../features/archive_evidence/archive_belief_correction_store.dart';
import '../features/archive_thought_map/archive_thought_map_engine.dart';
import '../features/archive_evidence/archive_belief_thread_engine.dart';
import '../features/archive_evidence/archive_belief_thread_model.dart';
import '../features/archive_evidence/archive_intelligence_tier.dart';
import '../features/archive_evidence/archive_intelligence_tier_resolver.dart';
import '../features/archive_evidence/archive_evidence.dart';
import '../features/early_archive/early_archive_proof_analytics.dart';
import '../features/early_archive/early_evidence_timeline_demo.dart';
import '../features/early_archive/early_evidence_timeline_engine.dart';
import '../features/early_archive/early_archive_return_reminder_gates.dart';
import '../features/early_archive/early_archive_return_reminder_store.dart';
import '../features/early_archive/early_evidence_milestone_store.dart';
import '../features/early_archive/early_first_signal_engine.dart';
import '../features/early_archive/early_first_signal_record_routes.dart';
import '../features/early_archive/confirmed_repeat_why_matters_gates.dart';
import '../features/early_archive/confirmed_repeat_why_matters_store.dart';
import '../features/early_archive/confirmed_repeat_thought_map_analytics.dart';
import '../features/early_archive/confirmed_repeat_thought_map_engine.dart';
import '../features/early_archive/confirmed_repeat_thought_map_gates.dart';
import '../features/early_archive/confirmed_repeat_thought_map_models.dart';
import '../features/early_archive/confirmed_repeat_thought_map_store.dart';
import '../features/early_archive/positive_pattern_engine.dart';
import '../features/early_archive/positive_reinforcement_analytics.dart';
import '../features/early_archive/positive_reinforcement_engine.dart';
import '../features/early_archive/positive_reinforcement_gates.dart';
import '../features/early_archive/private_archive_report_engine.dart';
import '../features/early_archive/private_archive_report_gates.dart';
import '../features/early_archive/archive_summary_engine.dart';
import '../features/early_archive/archive_summary_gates.dart';
import '../features/early_archive/archive_summary_model.dart';
import '../features/early_archive/archive_watching_engine.dart';
import '../features/early_archive/archive_watching_gates.dart';
import '../features/early_archive/daily_return_reason_analytics.dart';
import '../features/early_archive/daily_return_reason_engine.dart';
import '../features/early_archive/daily_return_reason_gates.dart';
import '../features/early_archive/daily_return_reason_model.dart';
import '../features/early_archive/weekly_archive_review_analytics.dart';
import '../features/early_archive/weekly_archive_review_engine.dart';
import '../features/early_archive/weekly_archive_review_gates.dart';
import '../features/early_archive/weekly_archive_review_model.dart';
import '../features/early_archive/confirmed_repeat_trigger_capture.dart';
import '../features/early_archive/confirmed_repeat_helpful_action_capture.dart';
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
import '../widgets/demo/sample_archive_entry_card.dart';
import '../widgets/return_ritual_card.dart';
import '../widgets/beta_feedback_card.dart';
import '../widgets/pro_interest_link_card.dart';
import '../features/beta_feedback/beta_feedback_store.dart';
import '../features/beta/confirmed_repeat_beta_feedback_gates.dart';
import '../features/beta/confirmed_repeat_beta_feedback_store.dart';
import '../features/early_archive/archive_proof_surface_layout.dart';
import '../features/repeat_return_check/repeat_return_check_engine.dart';
import '../features/repeat_return_check/repeat_return_check_store.dart';
import '../features/repeat_return_check/repeat_return_check_trend.dart';
import '../features/repeat_return_check/pattern_changed_analytics.dart';
import '../features/repeat_return_check/pattern_changed_engine.dart';
import '../features/repeat_return_check/pattern_changed_gates.dart';
import '../features/repeat_return_check/pattern_changed_store.dart';
import '../widgets/beta/confirmed_repeat_beta_feedback_card.dart';
import '../widgets/pro_value_preview_card.dart';
import '../features/pro/pro_value_preview_dismiss_store.dart';
import '../features/pro/pro_value_preview_gates.dart';
import '../features/archive_depth/archive_depth_engine.dart';
import '../features/archive_depth/archive_depth_gates.dart';
import '../features/archive_watchlist/archive_watchlist_gates.dart';
import '../features/archive_milestones/archive_milestones_gates.dart';
import '../features/next_evidence_plan/next_evidence_plan_gates.dart';
import '../features/return_changes/archive_return_changes_engine.dart';
import '../features/return_changes/archive_return_changes_gates.dart';
import '../features/return_changes/archive_return_changes_store.dart';
import '../features/return_changes/archive_return_snapshot.dart';
import '../widgets/archive_depth_card.dart';
import '../widgets/archive_watchlist_card.dart';
import '../widgets/next_evidence_plan_card.dart';
import '../widgets/first_week_path_card.dart';
import '../widgets/daily_archive_exercise_card.dart';
import '../widgets/archive_clarity_progress_card.dart';
import '../widgets/then_vs_now_card.dart';
import '../widgets/capacity_loop_card.dart';
import '../widgets/capacity_beta_mission_card.dart';
import '../widgets/capacity_cost_later_card.dart';
import '../widgets/capacity_decision_outcome_card.dart';
import '../widgets/capacity_pull_reason_card.dart';
import '../widgets/capacity_three_moment_card.dart';
import '../widgets/capacity_activation_fit_card.dart';
import '../widgets/before_you_say_yes_card.dart';
import '../widgets/capacity_weekly_review_card.dart';
import '../widgets/capacity_boundary_response_card.dart';
import '../widgets/archive_daily_change_card.dart';
import '../features/archive_daily_change/archive_daily_change_engine.dart';
import '../features/archive_daily_change/archive_daily_change_store.dart';
import '../features/capacity_loop/capacity_weekly_review_engine.dart';
import '../features/capacity_loop/capacity_boundary_response_engine.dart';
import '../features/capacity_loop/capacity_boundary_response_store.dart';
import '../features/capacity_loop/capacity_loop_engine.dart';
import '../features/capacity_loop/capacity_cost_engine.dart';
import '../features/capacity_loop/capacity_cost_store.dart';
import '../features/capacity_loop/capacity_decision_outcome_engine.dart';
import '../features/capacity_loop/capacity_decision_outcome_store.dart';
import '../features/capacity_loop/capacity_pull_reason_engine.dart';
import '../features/capacity_loop/capacity_pull_reason_store.dart';
import '../features/pro_interest/pro_interest_store.dart';
import '../features/capacity_loop/capacity_three_moment_engine.dart';
import '../features/capacity_loop/capacity_activation_fit_engine.dart';
import '../features/capacity_loop/capacity_activation_fit_store.dart';
import '../features/capacity_loop/capacity_beta_mission_engine.dart';
import '../features/capacity_loop/capacity_beta_mission_store.dart';
import '../features/capacity_loop/capacity_launch_wedge_gates.dart';
import '../features/capacity_loop/before_yes_engine.dart';
import '../features/capacity_loop/before_yes_copy.dart';
import '../features/capacity_loop/capacity_loop_copy.dart';
import '../features/capacity_loop/low_effort_yes_capture_copy.dart';
import '../features/capacity_loop/low_effort_yes_capture_engine.dart';
import '../features/capacity_loop/low_effort_yes_capture_models.dart';
import '../features/loop_mode/loop_mode_coordinator.dart';
import '../features/acquisition/acquisition_cohort_coordinator.dart';
import '../features/acquisition/acquisition_cohort_model.dart';
import '../widgets/archive_calendar_card.dart';
import '../widgets/review_ritual_card.dart';
import '../features/review_ritual/view_ritual_engine.dart';
import '../features/review_ritual/view_ritual_models.dart';
import '../features/review_ritual/view_ritual_store.dart';
import '../widgets/milestone_share_card.dart';
import '../features/milestone_share/milestone_share_gates.dart';
import '../features/then_now/then_now_engine.dart';
import '../features/archive_calendar/archive_calendar_engine.dart';
import '../widgets/archive_milestones_card.dart';
import '../widgets/archive_return_changes_card.dart';
import '../features/beta_feedback/beta_feedback_engine.dart';
import '../features/archive_home/archive_home_priority_engine.dart';
import '../features/archive_home/archive_home_priority_models.dart';
import '../widgets/archive_home_more_tools_section.dart';
import '../widgets/patterns/early_evidence_timeline_demo_section.dart';
import '../widgets/patterns/patterns_empty_view.dart';
import '../widgets/patterns/patterns_mind_map_forming_card.dart';
import '../widgets/patterns/patterns_thought_map_preview_card.dart';
import '../widgets/patterns/change_summary_card.dart';
import '../widgets/patterns/return_comparison_card.dart';
import '../widgets/patterns/return_streak_card.dart';
import '../widgets/patterns/tomorrow_return_status_card.dart';
import '../widgets/patterns/weekly_pattern_recap_card.dart';
import '../widgets/patterns/active_pattern_thread_card.dart';
import '../widgets/activation/third_session_archive_usefulness_card.dart';
import '../features/archive_proof/archive_belief_surface.dart';
import '../features/archive_proof/archive_current_belief_gates.dart';
import '../features/early_archive/archive_change_timeline_engine.dart';
import '../features/early_archive/archive_change_timeline_gates.dart';
import '../features/early_archive/helpful_action_appeared_engine.dart';
import '../features/early_archive/helpful_action_appeared_gates.dart';
import '../features/early_archive/what_changed_since_last_time_engine.dart';
import '../features/early_archive/what_changed_since_last_time_gates.dart';
import '../features/archive_proof/archive_change_timeline_metrics_store.dart';
import '../features/archive_proof/archive_paid_value_proof_source.dart';
import '../features/archive_proof/archive_proof_record_routes.dart';
import '../features/archive_proof/visible_archive_proof_copy.dart';
import '../widgets/patterns/archive_belief_surface_card.dart';
import '../widgets/patterns/archive_change_timeline_card.dart';
import '../widgets/patterns/helpful_action_appeared_card.dart';
import '../widgets/patterns/what_changed_since_last_time_card.dart';
import '../widgets/patterns/archive_paid_value_proof_card.dart';
import '../widgets/patterns/archive_oh_wow_moment_card.dart';
import '../widgets/patterns/archive_intelligence_pro_bridge_card.dart';
import '../widgets/patterns/weekly_what_changed_review_card.dart';
import '../billing/archive_entitlement_reader.dart';
import '../widgets/patterns/watch_for_result_card.dart';
import '../features/activation/first_three_session_gates.dart';
import '../features/activation/paywall_timing_gates.dart';
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
import '../features/pressure_retention/shareable_archive_proof_model.dart';
import '../features/return_ritual/return_ritual_gates.dart';
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
import '../widgets/record/early_first_signal_card.dart';
import '../widgets/record/confirmed_repeat_why_matters_card.dart';
import '../widgets/record/confirmed_repeat_thought_map_card.dart';
import '../widgets/record/positive_reinforcement_card.dart';
import '../widgets/record/archive_summary_card.dart';
import '../widgets/record/daily_return_reason_card.dart';
import '../widgets/record/weekly_archive_review_card.dart' as week_review;
import '../widgets/record/confirmed_repeat_change_notice_card.dart';
import '../widgets/record/early_archive_return_reminder_card.dart';
import '../widgets/record/early_evidence_timeline_card.dart';
import '../widgets/record/repeat_return_check_change_proof_card.dart';
import '../widgets/record/pattern_changed_card.dart';
import '../widgets/record/private_archive_report_card.dart';
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
  ArchiveReturnChangesResult? _archiveReturnChangesResult;
  ArchiveReturnSnapshot? _archiveReturnCurrentSnapshot;
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
  bool _capacityLoopActive = false;
  bool _capacityCohortActive = false;
  bool _loading = true;
  bool _reloadScheduled = false;
  bool _archiveIsPro = false;
  bool _proBridgeResolved = false;
  bool _earlyEvidenceTriggerCaptured = false;
  bool _earlyEvidenceHelpfulCaptured = false;
  bool _earlyEvidenceDemoVisible = false;
  bool _earlyReturnReminderOffer = false;
  bool _earlyReturnReminderHidden = false;
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
    if (ScreenshotMode.enabled && !ArchiveMeDemoState.isActive) {
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
    if (ScreenshotMode.enabled && !ArchiveMeDemoState.isActive) {
      _applyScreenshotSample();
      return;
    }
    await ArchiveBeliefCorrectionStore.ensureLoaded();
    await ArchiveWorkspaceHintStore.ensureLoaded();
    await ProValuePreviewDismissStore.ensureLoaded();
    await BetaFeedbackStore.ensureLoaded();
    await ConfirmedRepeatBetaFeedbackStore.ensureLoaded();
    await ConfirmedRepeatWhyMattersStore.ensureLoaded();
    await ConfirmedRepeatThoughtMapStore.ensureLoaded();
    await RepeatReturnCheckStore.ensureLoaded();
    await PatternChangedStore.ensureLoaded();
    await ReviewRitualStore.ensureLoaded();
    await CapacityCostStore.ensureLoaded();
    await CapacityDecisionOutcomeStore.ensureLoaded();
    await CapacityPullReasonStore.ensureLoaded();
    await CapacityActivationFitStore.ensureLoaded();
    await CapacityBoundaryResponseStore.ensureLoaded();
    await ArchiveDailyChangeStore.ensureLoaded();
    await CapacityBetaMissionStore.ensureLoaded();
    await ProInterestStore.ensureLoaded();
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
        _archiveReturnChangesResult = null;
        _archiveReturnCurrentSnapshot = null;
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
    final activeLoop = await LoopModeCoordinator.loadActive();
    final acquisitionCohort = await AcquisitionCohortCoordinator.load();
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

    final earlyTriggerCaptured =
        await EarlyEvidenceMilestoneStore.instance().readTriggerCaptured();
    final earlyHelpfulCaptured =
        await EarlyEvidenceMilestoneStore.instance().readHelpfulActionCaptured();
    final earlyReturnReminderOffer =
        await EarlyArchiveReturnReminderStore.instance().shouldOffer();
    final hasRealEarlyEvidenceTimeline =
        EarlyEvidenceTimelineEngine.build(
          entries: entries,
          triggerCapturedMilestone: earlyTriggerCaptured,
          helpfulActionCapturedMilestone: earlyHelpfulCaptured,
        ) !=
        null;

    if (!mounted) return;
    setState(() {
      _archiveIsPro = isPro;
      _proBridgeResolved = recordReturnPro.proBridgeResolved;
      _entries = entries;
      _firstLoop = firstLoop;
      _capacityLoopActive = activeLoop?.isCapacityYes ?? false;
      _capacityCohortActive =
          acquisitionCohort?.cohortId == AcquisitionCohortId.capacityYesDirect;
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
      _earlyEvidenceTriggerCaptured = earlyTriggerCaptured;
      _earlyEvidenceHelpfulCaptured = earlyHelpfulCaptured;
      _earlyReturnReminderOffer = earlyReturnReminderOffer;
      if (hasRealEarlyEvidenceTimeline) {
        _earlyEvidenceDemoVisible = false;
      }
      _loading = false;
    });
    await _refreshArchiveReturnChanges(entries);
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
    return isIntentionalEmptyArchive(_entries);
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

  /// Confirmed-repeat early proof (3–5 entries) — timeline and capture CTAs.
  bool get _patternsEarlyArchiveProofStack {
    if (_entries.length < FirstThreeSessionGates.minEntriesForUsefulArchive) {
      return false;
    }
    if (_entries.length > 5) return false;
    return EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(_entries);
  }

  bool get _usesPatternsEarlyProofScaffold =>
      _patternsFirstThreeStack || _patternsEarlyArchiveProofStack;

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

  void _handleThoughtMapMissingPiece(ThoughtMapResult map) {
    final missing = map.sections.where((section) => !section.isKnown);
    if (missing.isEmpty) return;
    final section = missing.first;
    ConfirmedRepeatThoughtMapAnalytics.recordMissingPieceTapped(
      section: section.id,
      surface: 'patterns',
      entryCount: _entries.length,
    );
    unawaited(
      ConfirmedRepeatThoughtMapStore.instance().markMissingPieceTarget(
        section.id,
      ),
    );
    if (section.id == ThoughtMapSectionId.trigger) {
      ConfirmedRepeatTriggerCapture.armForNextSave();
      context.go(
        EarlyFirstSignalRecordRoutes.routeWithTriggerPrompt(autostart: true),
      );
      return;
    }
    if (section.id == ThoughtMapSectionId.result) {
      ConfirmedRepeatHelpfulActionCapture.armForNextSave();
      context.go(
        EarlyFirstSignalRecordRoutes.routeWithWhatHelpedPrompt(autostart: true),
      );
      return;
    }
    context.go(
      EarlyFirstSignalRecordRoutes.routeWithPrompt(
        prompt: section.guidedRecordPrompt,
        autostart: true,
      ),
    );
  }

  void _handleArchiveSummaryRecordNext(ArchiveSummaryResult summary) {
    final recordNext = summary.recordNext;
    if (recordNext.needsTriggerCapture) {
      ConfirmedRepeatTriggerCapture.armForNextSave();
      context.go(
        EarlyFirstSignalRecordRoutes.routeWithTriggerPrompt(autostart: true),
      );
      return;
    }
    if (recordNext.needsResultCapture) {
      ConfirmedRepeatHelpfulActionCapture.armForNextSave();
      context.go(
        EarlyFirstSignalRecordRoutes.routeWithWhatHelpedPrompt(autostart: true),
      );
      return;
    }
    context.go(
      EarlyFirstSignalRecordRoutes.routeWithPrompt(
        prompt: recordNext.guidedRecordPrompt,
        autostart: true,
      ),
    );
  }

  void _handleDailyReturnReason(DailyReturnReasonResult reason) {
    DailyReturnReasonAnalytics.recordTapped(
      kind: reason.kind,
      surface: 'patterns',
      entryCount: _entries.length,
    );
    if (reason.needsTriggerCapture) {
      ConfirmedRepeatTriggerCapture.armForNextSave();
      context.go(
        EarlyFirstSignalRecordRoutes.routeWithTriggerPrompt(autostart: true),
      );
      return;
    }
    if (reason.needsResultCapture) {
      ConfirmedRepeatHelpfulActionCapture.armForNextSave();
      context.go(
        EarlyFirstSignalRecordRoutes.routeWithWhatHelpedPrompt(autostart: true),
      );
      return;
    }
    context.go(
      EarlyFirstSignalRecordRoutes.routeWithPrompt(
        prompt: reason.guidedRecordPrompt,
        autostart: true,
      ),
    );
  }

  void _handleWeeklyArchiveWeekReview(WeeklyArchiveWeekReviewResult review) {
    WeeklyArchiveWeekReviewAnalytics.recordTapped(
      surface: 'patterns',
      entryCount: _entries.length,
      hasRepeat: review.hasRepeat,
      hasChange: review.hasChange,
      hasPositivePattern: review.hasPositivePattern,
    );
    context.go(
      EarlyFirstSignalRecordRoutes.routeWithPrompt(
        prompt: review.guidedRecordPrompt,
        autostart: true,
      ),
    );
  }

  void _handlePositiveReinforcementRecordAgain(
    PositiveReinforcementResult reinforcement,
  ) {
    PositiveReinforcementAnalytics.recordTapped(
      surface: 'patterns',
      entryCount: _entries.length,
      helpfulPatternRecorded: true,
    );
    ConfirmedRepeatHelpfulActionCapture.armForNextSave();
    context.go(
      EarlyFirstSignalRecordRoutes.routeWithPrompt(
        prompt: reinforcement.guidedRecordPrompt,
        autostart: true,
      ),
    );
  }

  void _handlePatternChangedRecord(PatternChangedResult result) {
    PatternChangedAnalytics.recordTapped(
      surface: 'patterns',
      entryCount: _entries.length,
      changeType: result.type,
    );
    _goToRecord();
  }

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

  Future<void> _refreshArchiveReturnChanges(List<JournalEntry> entries) async {
    if (ScreenshotMode.enabled) {
      if (!mounted) return;
      setState(() {
        _archiveReturnChangesResult = null;
        _archiveReturnCurrentSnapshot = null;
      });
      return;
    }
    final store = ArchiveReturnChangesStore.fromAppPrefs(
      AppServices.instance.prefs,
    );
    final resolved = await resolveArchiveReturnChanges(
      entries: entries,
      store: store,
    );
    if (!mounted) return;
    setState(() {
      _archiveReturnCurrentSnapshot = resolved.current;
      _archiveReturnChangesResult = resolved.result;
    });
  }

  Future<void> _markArchiveReturnChangesSeen() async {
    final snapshot = _archiveReturnCurrentSnapshot;
    if (snapshot == null) return;
    await ArchiveReturnChangesStore.fromAppPrefs(
      AppServices.instance.prefs,
    ).markSeen(snapshot);
    if (!mounted) return;
    setState(() => _archiveReturnChangesResult = null);
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
    bool suppressWhenPostProofShown = false,
  }) {
    if (suppressWhenPostProofShown || _archiveIsPro || _proBridgeResolved) {
      return false;
    }
    return FirstThreeSessionGates.showSoftProBridge(
      entryCount: _entries.length,
      resolved: _proBridgeResolved,
      isPro: _archiveIsPro,
      hasArchiveProof: PaywallTimingGates.hasArchiveProofFromEntries(
        entries: _entries,
        hasBeliefProof: belief.hasEnoughData,
        hasWeeklyReview: weekly.hasReview,
        hasOhWowMoment: ohWow.hasMoment,
      ),
    );
  }

  List<Widget> _buildArchiveIntelligenceWidgets({
    required ArchiveBeliefThread belief,
    required WeeklyWhatChangedReview weekly,
    required ArchiveOhWowMoment ohWow,
    bool suppressWhenPostProofShown = false,
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
      suppressWhenPostProofShown: suppressWhenPostProofShown,
    )) {
      widgets.add(
        ArchiveIntelligenceProBridgeCard(
          onSeePro: () {
            EarlyArchiveProofAnalytics.proScreenOpenedAfterTimeline(
              source: 'patterns_pro_bridge',
            );
            context.push('/subscription');
          },
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
    if (!surface.shouldShow || surface.isPrimaryAfterFirstProof) {
      return const [];
    }
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
      const SizedBox(height: ArchiveMobileSpacing.proofStackCardGap),
    ];
  }

  List<Widget> _buildHelpfulActionAppearedWidgets() {
    final earlyFirstSignal = EarlyFirstSignalEngine.build(entries: _entries);
    final timeline = EarlyEvidenceTimelineEngine.build(
      entries: _entries,
      triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
      helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
    );
    final viewingConfirmedRepeatOrTimeline =
        timeline != null || (earlyFirstSignal?.showsConfirmedRepeat ?? false);
    final candidate = HelpfulActionAppearedEngine.build(
      entries: _entries,
      returnChecks: RepeatReturnCheckStore.cached,
      helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
    );
    if (!HelpfulActionAppearedGates.shouldShow(
      loaded: true,
      entryCount: _entries.length,
      isReady: true,
      isRecording: false,
      isPostSave: false,
      isDegradedPostSave: false,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
      hasConfirmedRepeatFoundation:
          EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(_entries),
      result: candidate,
    )) {
      return const [];
    }
    return [
      HelpfulActionAppearedCard(
        result: candidate!,
        entryCount: _entries.length,
        source: 'patterns',
      ),
      const SizedBox(height: ArchiveMobileSpacing.proofStackCardGap),
    ];
  }

  List<Widget> _buildWhatChangedSinceLastTimeWidgets() {
    final earlyFirstSignal = EarlyFirstSignalEngine.build(entries: _entries);
    final timeline = EarlyEvidenceTimelineEngine.build(
      entries: _entries,
      triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
      helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
    );
    final viewingConfirmedRepeatOrTimeline =
        timeline != null || (earlyFirstSignal?.showsConfirmedRepeat ?? false);
    final candidate = WhatChangedSinceLastTimeEngine.build(
      entries: _entries,
      returnChecks: RepeatReturnCheckStore.cached,
    );
    if (!WhatChangedSinceLastTimeGates.shouldShow(
      loaded: true,
      entryCount: _entries.length,
      isReady: true,
      isRecording: false,
      isPostSave: false,
      isDegradedPostSave: false,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
      hasConfirmedRepeatFoundation:
          EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(_entries),
      result: candidate,
    )) {
      return const [];
    }
    return [
      WhatChangedSinceLastTimeCard(
        result: candidate!,
        entryCount: _entries.length,
      ),
      const SizedBox(height: ArchiveMobileSpacing.proofStackCardGap),
    ];
  }

  List<Widget> _buildThoughtMapPreviewWidgets() {
    final preview = const ArchiveThoughtMapEngine().build(
      _entries,
      tier: _archiveIntelligenceTier,
    );
    if (!preview.shouldShow) return const [];
    return [
      PatternsThoughtMapPreviewCard(preview: preview),
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

  ArchiveHomePriorityInput _archiveHomePriorityInput({
    required ArchiveWorkspaceLayout layout,
    required WeeklyArchiveReview? weeklyReview,
  }) {
    final savedCount = _entries
        .where(
          (e) =>
              e.transcript.trim().isNotEmpty &&
              !e.transcript.startsWith('[draft]'),
        )
        .length;
    final realSavedCount = BetaFeedbackEngine.realEntryCountFor(_entries);
    final depth = const ArchiveDepthEngine().build(entries: _entries);
    final thenNow = const ThenNowEngine().buildFromJournal(entries: _entries);
    final capacityLoop = const CapacityLoopEngine().buildFromJournal(
      entries: _entries,
      capacityLoopActive: _capacityLoopActive,
      capacityCohortActive: _capacityCohortActive,
      costRecords: CapacityCostStore.cached,
      outcomeRecords: CapacityDecisionOutcomeStore.cached,
      pullReasonRecords: CapacityPullReasonStore.cached,
    );
    final capacityThreeMoment =
        const CapacityThreeMomentEngine().buildFromJournal(
      entries: _entries,
      capacityLoopActive: _capacityLoopActive,
      capacityCohortActive: _capacityCohortActive,
      sampleMode: ScreenshotMode.enabled,
    );
    final capacityPullReason =
        const CapacityPullReasonEngine().buildFromJournal(
      entries: _entries,
      capacityLoopActive: _capacityLoopActive,
      capacityCohortActive: _capacityCohortActive,
      records: CapacityPullReasonStore.cached,
    );
    final capacityDecisionOutcome =
        const CapacityDecisionOutcomeEngine().buildFromJournal(
      entries: _entries,
      capacityLoopActive: _capacityLoopActive,
      capacityCohortActive: _capacityCohortActive,
      records: CapacityDecisionOutcomeStore.cached,
    );
    final capacityCostCheckin = const CapacityCostEngine().buildFromJournal(
      entries: _entries,
      capacityLoopActive: _capacityLoopActive,
      capacityCohortActive: _capacityCohortActive,
      records: CapacityCostStore.cached,
      outcomeRecords: CapacityDecisionOutcomeStore.cached,
    );
    final capacityActivationFit =
        const CapacityActivationFitEngine().buildFromJournal(
      entries: _entries,
      capacityLoopActive: _capacityLoopActive,
      capacityCohortActive: _capacityCohortActive,
      pendingPullReasonOnHome: capacityPullReason.showOnArchiveHome,
      pendingDecisionOutcomeOnHome: capacityDecisionOutcome.showOnArchiveHome,
      pendingCostCheckinOnHome: capacityCostCheckin.showOnArchiveHome,
      threeMomentActivationOnHome: capacityThreeMoment.showOnArchiveHome,
    );
    final beforeYesPause = const BeforeYesPauseEngine().buildFromJournal(
      entries: _entries,
      capacityLoopActive: _capacityLoopActive,
      capacityCohortActive: _capacityCohortActive,
      capacityLoopHasCard: capacityLoop.hasCard,
      costLaterCheckinVisible: capacityCostCheckin.hasCard &&
          capacityCostCheckin.showOnArchiveHome,
      costRecords: CapacityCostStore.cached,
    );
    final capacityWeeklyReview =
        const CapacityWeeklyReviewEngine().buildFromJournal(
      entries: _entries,
      capacityLoopActive: _capacityLoopActive,
      capacityCohortActive: _capacityCohortActive,
      costRecords: CapacityCostStore.cached,
      outcomeRecords: CapacityDecisionOutcomeStore.cached,
      pendingDecisionOutcome: capacityDecisionOutcome.showOnArchiveHome,
      pendingCostCheckin: capacityCostCheckin.showOnArchiveHome,
      beforeYesPauseOnHome: beforeYesPause.showOnArchiveHome,
      pendingPullReasonOnHome: capacityPullReason.showOnArchiveHome,
      pullReasonRecords: CapacityPullReasonStore.cached,
    );
    final capacityBoundaryResponse =
        const CapacityBoundaryResponseEngine().buildFromJournal(
      entries: _entries,
      capacityLoopActive: _capacityLoopActive,
      capacityCohortActive: _capacityCohortActive,
      costRecords: CapacityCostStore.cached,
      outcomeRecords: CapacityDecisionOutcomeStore.cached,
      pendingDecisionOutcome: capacityDecisionOutcome.showOnArchiveHome,
      pendingCostCheckin: capacityCostCheckin.showOnArchiveHome,
      beforeYesPauseOnHome: beforeYesPause.showOnArchiveHome,
      weeklyReviewOnHome: capacityWeeklyReview.showOnArchiveHome,
      pendingPullReasonOnHome: capacityPullReason.showOnArchiveHome,
      pullReasonRecords: CapacityPullReasonStore.cached,
    );
    final archiveDailyChange =
        const ArchiveDailyChangeEngine().buildFromJournal(
      entries: _entries,
      capacityLoopActive: _capacityLoopActive,
      capacityCohortActive: _capacityCohortActive,
      state: ArchiveDailyChangeStore.cached,
      pullReasonRecords: CapacityPullReasonStore.cached,
      costRecords: CapacityCostStore.cached,
      outcomeRecords: CapacityDecisionOutcomeStore.cached,
      boundarySelection: CapacityBoundaryResponseStore.cached,
      activationFitRecord: CapacityActivationFitStore.cached,
      weeklyReviewAvailable: capacityWeeklyReview.showOnArchiveHome,
      sampleMode: ScreenshotMode.enabled,
    );
    final archiveCalendar =
        const ArchiveCalendarEngine().buildFromJournal(entries: _entries);
    final reviewRitualResult = const ReviewRitualEngine().build(
      ReviewRitualInput(
        realSavedMomentCount: realSavedCount,
        weeklyReviewAvailable: weeklyReview?.hasEnoughEvidence ?? false,
        ritual: ReviewRitualStore.cached,
      ),
    );
    final milestoneShareVisible = MilestoneShareGates.showOnArchiveHome(
      realSavedMomentCount: realSavedCount,
      milestoneCount: realSavedCount >= 1 ? 1 : 0,
      sampleMode: ScreenshotMode.enabled,
    );
    final capacityWedgeActive =
        _capacityLoopActive || _capacityCohortActive;
    final earlyCapacityWedgeSession = CapacityLaunchWedgeGates.inEarlyActivationPhase(
      capacityWedgeActive: capacityWedgeActive,
      capacityMomentCount: capacityThreeMoment.capacityMomentCount,
    );
    return ArchiveHomePriorityInput(
      savedEntryCount: savedCount,
      usableEvidenceCount: layout.eligibleCount,
      depthLevel: depth.level,
      returnChangesAvailable: ArchiveReturnChangesGates.show(
        entryCount: _entries.length,
        sampleMode: ScreenshotMode.enabled,
        result: _archiveReturnChangesResult,
      ),
      weeklyReviewAvailable: weeklyReview?.hasEnoughEvidence ?? false,
      sampleMode: ScreenshotMode.enabled,
      proPreviewPromoVisible: ProValuePreviewGates.showArchivePromo(
        entryCount: _entries.length,
        dismissed: ProValuePreviewDismissStore.isDismissed,
      ),
      showEmptySample: _showEmpty,
      archiveDailyChangeVisible: !ScreenshotMode.enabled &&
          archiveDailyChange.hasFeature &&
          archiveDailyChange.showOnArchiveHome &&
          !earlyCapacityWedgeSession,
      firstWeekPathVisible: !ScreenshotMode.enabled &&
          realSavedCount < 7 &&
          !earlyCapacityWedgeSession,
      dailyArchiveExerciseVisible:
          !ScreenshotMode.enabled && !earlyCapacityWedgeSession,
      archiveClarityProgressVisible:
          !ScreenshotMode.enabled && !earlyCapacityWedgeSession,
      capacityThreeMomentActivationVisible: !ScreenshotMode.enabled &&
          capacityThreeMoment.hasCard &&
          capacityThreeMoment.showOnArchiveHome,
      capacityLoopVisible: !ScreenshotMode.enabled &&
          capacityLoop.hasCard &&
          capacityLoop.showOnArchiveHome &&
          !capacityThreeMoment.showOnArchiveHome,
      capacityPullReasonVisible: !ScreenshotMode.enabled &&
          capacityPullReason.hasCard &&
          capacityPullReason.showOnArchiveHome,
      capacityDecisionOutcomeVisible: !ScreenshotMode.enabled &&
          capacityDecisionOutcome.hasCard &&
          capacityDecisionOutcome.showOnArchiveHome &&
          !capacityPullReason.showOnArchiveHome,
      capacityCostLaterCheckinVisible: !ScreenshotMode.enabled &&
          capacityCostCheckin.hasCard &&
          capacityCostCheckin.showOnArchiveHome &&
          !capacityDecisionOutcome.showOnArchiveHome &&
          !capacityPullReason.showOnArchiveHome,
      capacityActivationFitVisible: !ScreenshotMode.enabled &&
          capacityActivationFit.hasCard &&
          capacityActivationFit.showOnArchiveHome,
      beforeYouSayYesPauseVisible: !ScreenshotMode.enabled &&
          beforeYesPause.showOnArchiveHome &&
          !capacityActivationFit.showOnArchiveHome,
      capacityWeeklyReviewVisible: !ScreenshotMode.enabled &&
          capacityWeeklyReview.showOnArchiveHome &&
          !capacityActivationFit.showOnArchiveHome,
      capacityBoundaryResponseVisible: !ScreenshotMode.enabled &&
          capacityBoundaryResponse.showOnArchiveHome &&
          !capacityActivationFit.showOnArchiveHome,
      thenVsNowVisible:
          !ScreenshotMode.enabled && thenNow.hasCard && thenNow.showOnArchiveHome,
      archiveCalendarVisible:
          !ScreenshotMode.enabled &&
          archiveCalendar.hasCard &&
          archiveCalendar.showOnArchiveHome,
      reviewRitualVisible:
          !ScreenshotMode.enabled && reviewRitualResult.showOnArchiveHome,
      milestoneShareVisible: milestoneShareVisible,
      calmCapacityActivationMode: earlyCapacityWedgeSession,
    );
  }

  void _appendArchiveHomeSectionWidgets(
    List<Widget> target,
    List<Widget> sectionWidgets,
  ) {
    if (sectionWidgets.isEmpty) return;
    if (target.isNotEmpty) {
      target.add(const SizedBox(height: AppSpacing.md));
    }
    target.addAll(sectionWidgets);
  }

  List<Widget> _archiveHomeSectionWidgets(
    ArchiveHomeSectionId sectionId, {
    required ArchiveHomeSummary summary,
    required ShareableArchiveProof? shareProof,
    required ArchiveWorkspaceQuickActions quickActions,
    required ArchiveWorkspaceHintsPlan hints,
    required ArchiveWorkspaceLayout layout,
    required EvidenceAttentionFilters attentionFilters,
    required ArchiveHealthActionPlan actionPlan,
    required ArchiveHealthScore archiveHealth,
    required ContextInsights contextInsights,
    required ArchiveEvidenceMap evidenceMap,
    required BeliefHistoryTimeline? beliefHistory,
    required WeeklyArchiveReview? weeklyReview,
    required ShareableArchiveProof standaloneShareProof,
  }) {
    switch (sectionId) {
      case ArchiveHomeSectionId.archiveSummary:
        return [
          ArchiveHomeSummaryCard(
            summary: summary,
            onPrimary: () => _handleArchiveHomeAction(summary.primaryAction),
            onSecondary: summary.secondaryAction != ArchiveHomeAction.none
                ? () => _handleArchiveHomeAction(summary.secondaryAction)
                : null,
            shareProof: shareProof?.hasProof == true ? shareProof : null,
          ),
        ];
      case ArchiveHomeSectionId.archiveDailyChange:
        final dailyChange =
            const ArchiveDailyChangeEngine().buildFromJournal(
          entries: _entries,
          capacityLoopActive: _capacityLoopActive,
          capacityCohortActive: _capacityCohortActive,
          state: ArchiveDailyChangeStore.cached,
          pullReasonRecords: CapacityPullReasonStore.cached,
          costRecords: CapacityCostStore.cached,
          outcomeRecords: CapacityDecisionOutcomeStore.cached,
          boundarySelection: CapacityBoundaryResponseStore.cached,
          activationFitRecord: CapacityActivationFitStore.cached,
          weeklyReviewAvailable: const CapacityWeeklyReviewEngine()
                  .buildFromJournal(
                entries: _entries,
                capacityLoopActive: _capacityLoopActive,
                capacityCohortActive: _capacityCohortActive,
                costRecords: CapacityCostStore.cached,
                outcomeRecords: CapacityDecisionOutcomeStore.cached,
                pullReasonRecords: CapacityPullReasonStore.cached,
              )
              .showOnArchiveHome,
          sampleMode: ScreenshotMode.enabled,
        );
        if (!dailyChange.hasFeature || !dailyChange.showOnArchiveHome) {
          return const [];
        }
        unawaited(ArchiveDailyChangeStore.instance().markSeen(DateTime.now().toUtc()));
        return [
          ArchiveDailyChangeCard(
            result: dailyChange,
            onDismiss: () async {
              await ArchiveDailyChangeStore.instance()
                  .dismiss(DateTime.now().toUtc());
              if (!mounted) return;
              setState(() {});
            },
          ),
        ];
      case ArchiveHomeSectionId.introHint:
        if (hints.introHint case final introHint?) {
          return [_workspaceHintWidget(introHint)!];
        }
        return const [];
      case ArchiveHomeSectionId.quickActions:
        if (!quickActions.showCard) return const [];
        return [
          ArchiveWorkspaceQuickActionsCard(
            quickActions: quickActions,
            onActionTap: _onArchiveWorkspaceQuickAction,
          ),
        ];
      case ArchiveHomeSectionId.returnRitual:
        if (!ReturnRitualGates.showOnArchive(entryCount: _entries.length)) {
          return const [];
        }
        return [
          ReturnRitualCard(
            entryCount: _entries.length,
            onAddMoment: _goToRecord,
          ),
        ];
      case ArchiveHomeSectionId.proPreview:
        if (!ProValuePreviewGates.showArchivePromo(
          entryCount: _entries.length,
          dismissed: ProValuePreviewDismissStore.isDismissed,
        )) {
          return const [];
        }
        return [
          ProValuePreviewPromoCard(
            onDismiss: () async {
              await ProValuePreviewDismissStore.dismiss();
              if (!mounted) return;
              setState(() {});
            },
          ),
        ];
      case ArchiveHomeSectionId.returnChanges:
        if (!ArchiveReturnChangesGates.show(
          entryCount: _entries.length,
          sampleMode: ScreenshotMode.enabled,
          result: _archiveReturnChangesResult,
        )) {
          return const [];
        }
        return [
          ArchiveReturnChangesCard(
            result: _archiveReturnChangesResult!,
            onMarkSeen: () => unawaited(_markArchiveReturnChangesSeen()),
          ),
        ];
      case ArchiveHomeSectionId.archiveDepth:
        if (!ArchiveDepthGates.showOnArchive(sampleMode: ScreenshotMode.enabled)) {
          return const [];
        }
        return [
          ArchiveDepthCard(
            result: const ArchiveDepthEngine().build(entries: _entries),
          ),
        ];
      case ArchiveHomeSectionId.watchlist:
        if (!ArchiveWatchlistGates.showTeaser(
              entryCount: _entries.length,
              sampleMode: ScreenshotMode.enabled,
            ) &&
            !ArchiveWatchlistGates.showCard(
              entryCount: _entries.length,
              sampleMode: ScreenshotMode.enabled,
            )) {
          return const [];
        }
        return [
          ArchiveWatchlistCard(
            entryCount: _entries.length,
            entries: _entries,
            onAddMoment: _goToRecord,
          ),
        ];
      case ArchiveHomeSectionId.nextEvidencePlan:
        if (!NextEvidencePlanGates.showTeaser(
              entryCount: _entries.length,
              sampleMode: ScreenshotMode.enabled,
            ) &&
            !NextEvidencePlanGates.showCard(
              entryCount: _entries.length,
              sampleMode: ScreenshotMode.enabled,
            )) {
          return const [];
        }
        return [
          NextEvidencePlanCard(
            entryCount: _entries.length,
            entries: _entries,
            onAddMoment: _goToRecord,
          ),
        ];
      case ArchiveHomeSectionId.firstWeekPath:
        return [
          FirstWeekPathCard(
            entries: _entries,
            onPrimaryAction: _goToRecord,
            hasWeeklyReviewAvailable: weeklyReview?.hasEnoughEvidence ?? false,
            sampleMode: ScreenshotMode.enabled,
          ),
        ];
      case ArchiveHomeSectionId.dailyArchiveExercise:
        return [
          DailyArchiveExerciseCard(
            entries: _entries,
            onPrimaryAction: _goToRecord,
            sampleMode: ScreenshotMode.enabled,
          ),
        ];
      case ArchiveHomeSectionId.archiveClarityProgress:
        return [
          ArchiveClarityProgressCard(
            entries: _entries,
            onPrimaryAction: _goToRecord,
            sampleMode: ScreenshotMode.enabled,
            weeklyReviewAvailable: weeklyReview?.hasEnoughEvidence ?? false,
          ),
        ];
      case ArchiveHomeSectionId.capacityThreeMomentActivation:
        return [
          CapacityThreeMomentCard(
            result: const CapacityThreeMomentEngine().buildFromJournal(
              entries: _entries,
              capacityLoopActive: _capacityLoopActive,
              capacityCohortActive: _capacityCohortActive,
            ),
          ),
        ];
      case ArchiveHomeSectionId.capacityLoop:
        return [
          CapacityLoopCard(
            entries: _entries,
            result: const CapacityLoopEngine().buildFromJournal(
              entries: _entries,
              capacityLoopActive: _capacityLoopActive,
              capacityCohortActive: _capacityCohortActive,
              costRecords: CapacityCostStore.cached,
              outcomeRecords: CapacityDecisionOutcomeStore.cached,
              pullReasonRecords: CapacityPullReasonStore.cached,
            ),
            capacityLoopActive: _capacityLoopActive,
            capacityCohortActive: _capacityCohortActive,
            onPrimaryAction: _goToRecord,
          ),
        ];
      case ArchiveHomeSectionId.capacityPullReason:
        return [
          CapacityPullReasonCard(
            result: const CapacityPullReasonEngine().buildFromJournal(
              entries: _entries,
              capacityLoopActive: _capacityLoopActive,
              capacityCohortActive: _capacityCohortActive,
              records: CapacityPullReasonStore.cached,
            ),
            onSaved: () {
              if (!mounted) return;
              setState(() {});
            },
          ),
        ];
      case ArchiveHomeSectionId.capacityDecisionOutcome:
        return [
          CapacityDecisionOutcomeCard(
            result: const CapacityDecisionOutcomeEngine().buildFromJournal(
              entries: _entries,
              capacityLoopActive: _capacityLoopActive,
              capacityCohortActive: _capacityCohortActive,
              records: CapacityDecisionOutcomeStore.cached,
            ),
            onSaved: () {
              if (!mounted) return;
              setState(() {});
            },
          ),
        ];
      case ArchiveHomeSectionId.capacityCostLaterCheckin:
        return [
          CapacityCostLaterCard(
            result: const CapacityCostEngine().buildFromJournal(
              entries: _entries,
              capacityLoopActive: _capacityLoopActive,
              capacityCohortActive: _capacityCohortActive,
              records: CapacityCostStore.cached,
              outcomeRecords: CapacityDecisionOutcomeStore.cached,
            ),
            onSaved: () {
              if (!mounted) return;
              setState(() {});
            },
          ),
        ];
      case ArchiveHomeSectionId.capacityActivationFit:
        return [
          CapacityActivationFitCard(
            compact: true,
            result: const CapacityActivationFitEngine().buildFromJournal(
              entries: _entries,
              capacityLoopActive: _capacityLoopActive,
              capacityCohortActive: _capacityCohortActive,
              pendingPullReasonOnHome: const CapacityPullReasonEngine()
                  .buildFromJournal(
                    entries: _entries,
                    capacityLoopActive: _capacityLoopActive,
                    capacityCohortActive: _capacityCohortActive,
                    records: CapacityPullReasonStore.cached,
                  )
                  .showOnArchiveHome,
              pendingDecisionOutcomeOnHome:
                  const CapacityDecisionOutcomeEngine()
                      .buildFromJournal(
                        entries: _entries,
                        capacityLoopActive: _capacityLoopActive,
                        capacityCohortActive: _capacityCohortActive,
                        records: CapacityDecisionOutcomeStore.cached,
                      )
                      .showOnArchiveHome,
              pendingCostCheckinOnHome: const CapacityCostEngine()
                  .buildFromJournal(
                    entries: _entries,
                    capacityLoopActive: _capacityLoopActive,
                    capacityCohortActive: _capacityCohortActive,
                    records: CapacityCostStore.cached,
                    outcomeRecords: CapacityDecisionOutcomeStore.cached,
                  )
                  .showOnArchiveHome,
              threeMomentActivationOnHome:
                  const CapacityThreeMomentEngine().buildFromJournal(
                    entries: _entries,
                    capacityLoopActive: _capacityLoopActive,
                    capacityCohortActive: _capacityCohortActive,
                  )
                  .showOnArchiveHome,
            ),
            onSaved: () {
              if (!mounted) return;
              setState(() {});
            },
          ),
        ];
      case ArchiveHomeSectionId.beforeYouSayYesPause:
        return [
          BeforeYouSayYesCard(
            compact: true,
            result: const BeforeYesPauseEngine().buildFromJournal(
              entries: _entries,
              capacityLoopActive: _capacityLoopActive,
              capacityCohortActive: _capacityCohortActive,
              capacityLoopHasCard: const CapacityLoopEngine()
                  .buildFromJournal(
                    entries: _entries,
                    capacityLoopActive: _capacityLoopActive,
                    capacityCohortActive: _capacityCohortActive,
                    costRecords: CapacityCostStore.cached,
                    outcomeRecords: CapacityDecisionOutcomeStore.cached,
                  )
                  .hasCard,
              costLaterCheckinVisible: const CapacityCostEngine()
                  .buildFromJournal(
                    entries: _entries,
                    capacityLoopActive: _capacityLoopActive,
                    capacityCohortActive: _capacityCohortActive,
                    records: CapacityCostStore.cached,
                    outcomeRecords: CapacityDecisionOutcomeStore.cached,
                  )
                  .showOnArchiveHome,
              costRecords: CapacityCostStore.cached,
            ),
            onPauseBeforeYes: () => context.push(
              BeforeYesCopy.recordRouteWithPrompt(BeforeYesCopy.recordPrompt),
            ),
            onAlreadySaidYes: () => context.push(CapacityLoopCopy.recordRoute),
            onQuickSave: () => context.push(LowEffortYesCaptureCopy.route),
          ),
        ];
      case ArchiveHomeSectionId.capacityWeeklyReview:
        return [
          CapacityWeeklyReviewCard(
            result: const CapacityWeeklyReviewEngine().buildFromJournal(
              entries: _entries,
              capacityLoopActive: _capacityLoopActive,
              capacityCohortActive: _capacityCohortActive,
              costRecords: CapacityCostStore.cached,
              outcomeRecords: CapacityDecisionOutcomeStore.cached,
              pendingDecisionOutcome: const CapacityDecisionOutcomeEngine()
                  .buildFromJournal(
                    entries: _entries,
                    capacityLoopActive: _capacityLoopActive,
                    capacityCohortActive: _capacityCohortActive,
                    records: CapacityDecisionOutcomeStore.cached,
                  )
                  .showOnArchiveHome,
              pendingCostCheckin: const CapacityCostEngine()
                  .buildFromJournal(
                    entries: _entries,
                    capacityLoopActive: _capacityLoopActive,
                    capacityCohortActive: _capacityCohortActive,
                    records: CapacityCostStore.cached,
                    outcomeRecords: CapacityDecisionOutcomeStore.cached,
                  )
                  .showOnArchiveHome,
              beforeYesPauseOnHome: const BeforeYesPauseEngine()
                  .buildFromJournal(
                    entries: _entries,
                    capacityLoopActive: _capacityLoopActive,
                    capacityCohortActive: _capacityCohortActive,
                    capacityLoopHasCard: const CapacityLoopEngine()
                        .buildFromJournal(
                          entries: _entries,
                          capacityLoopActive: _capacityLoopActive,
                          capacityCohortActive: _capacityCohortActive,
                          costRecords: CapacityCostStore.cached,
                          outcomeRecords: CapacityDecisionOutcomeStore.cached,
                        )
                        .hasCard,
                    costLaterCheckinVisible: false,
                    costRecords: CapacityCostStore.cached,
                  )
                  .showOnArchiveHome,
            ),
          ),
        ];
      case ArchiveHomeSectionId.capacityBoundaryResponse:
        return [
          CapacityBoundaryResponseCard(
            result: const CapacityBoundaryResponseEngine().buildFromJournal(
              entries: _entries,
              capacityLoopActive: _capacityLoopActive,
              capacityCohortActive: _capacityCohortActive,
              costRecords: CapacityCostStore.cached,
              outcomeRecords: CapacityDecisionOutcomeStore.cached,
              pendingDecisionOutcome: const CapacityDecisionOutcomeEngine()
                  .buildFromJournal(
                    entries: _entries,
                    capacityLoopActive: _capacityLoopActive,
                    capacityCohortActive: _capacityCohortActive,
                    records: CapacityDecisionOutcomeStore.cached,
                  )
                  .showOnArchiveHome,
              pendingCostCheckin: const CapacityCostEngine()
                  .buildFromJournal(
                    entries: _entries,
                    capacityLoopActive: _capacityLoopActive,
                    capacityCohortActive: _capacityCohortActive,
                    records: CapacityCostStore.cached,
                    outcomeRecords: CapacityDecisionOutcomeStore.cached,
                  )
                  .showOnArchiveHome,
              beforeYesPauseOnHome: const BeforeYesPauseEngine()
                  .buildFromJournal(
                    entries: _entries,
                    capacityLoopActive: _capacityLoopActive,
                    capacityCohortActive: _capacityCohortActive,
                    capacityLoopHasCard: const CapacityLoopEngine()
                        .buildFromJournal(
                          entries: _entries,
                          capacityLoopActive: _capacityLoopActive,
                          capacityCohortActive: _capacityCohortActive,
                          costRecords: CapacityCostStore.cached,
                          outcomeRecords: CapacityDecisionOutcomeStore.cached,
                        )
                        .hasCard,
                    costLaterCheckinVisible: false,
                    costRecords: CapacityCostStore.cached,
                  )
                  .showOnArchiveHome,
              weeklyReviewOnHome: const CapacityWeeklyReviewEngine()
                  .buildFromJournal(
                    entries: _entries,
                    capacityLoopActive: _capacityLoopActive,
                    capacityCohortActive: _capacityCohortActive,
                    costRecords: CapacityCostStore.cached,
                    outcomeRecords: CapacityDecisionOutcomeStore.cached,
                    pendingDecisionOutcome: const CapacityDecisionOutcomeEngine()
                        .buildFromJournal(
                          entries: _entries,
                          capacityLoopActive: _capacityLoopActive,
                          capacityCohortActive: _capacityCohortActive,
                          records: CapacityDecisionOutcomeStore.cached,
                        )
                        .showOnArchiveHome,
                    pendingCostCheckin: const CapacityCostEngine()
                        .buildFromJournal(
                          entries: _entries,
                          capacityLoopActive: _capacityLoopActive,
                          capacityCohortActive: _capacityCohortActive,
                          records: CapacityCostStore.cached,
                          outcomeRecords: CapacityDecisionOutcomeStore.cached,
                        )
                        .showOnArchiveHome,
                    beforeYesPauseOnHome: const BeforeYesPauseEngine()
                        .buildFromJournal(
                          entries: _entries,
                          capacityLoopActive: _capacityLoopActive,
                          capacityCohortActive: _capacityCohortActive,
                          capacityLoopHasCard: const CapacityLoopEngine()
                              .buildFromJournal(
                                entries: _entries,
                                capacityLoopActive: _capacityLoopActive,
                                capacityCohortActive: _capacityCohortActive,
                                costRecords: CapacityCostStore.cached,
                                outcomeRecords:
                                    CapacityDecisionOutcomeStore.cached,
                              )
                              .hasCard,
                          costLaterCheckinVisible: false,
                          costRecords: CapacityCostStore.cached,
                        )
                        .showOnArchiveHome,
                  )
                  .showOnArchiveHome,
            ),
          ),
        ];
      case ArchiveHomeSectionId.thenVsNow:
        return [
          ThenVsNowCard(
            entries: _entries,
            result: ThenNowEngine().buildFromJournal(entries: _entries),
            onSecondaryAction: _goToRecord,
          ),
        ];
      case ArchiveHomeSectionId.archiveCalendar:
        return [
          ArchiveCalendarCard(
            result: ArchiveCalendarEngine().buildFromJournal(entries: _entries),
          ),
        ];
      case ArchiveHomeSectionId.reviewRitual:
        return [
          ReviewRitualCard(
            result: const ReviewRitualEngine().build(
              ReviewRitualInput(
                realSavedMomentCount:
                    BetaFeedbackEngine.realEntryCountFor(_entries),
                weeklyReviewAvailable: weeklyReview?.hasEnoughEvidence ?? false,
                ritual: ReviewRitualStore.cached,
              ),
            ),
          ),
        ];
      case ArchiveHomeSectionId.milestoneShare:
        return [
          MilestoneShareHomeCard(entries: _entries),
        ];
      case ArchiveHomeSectionId.milestones:
        if (!ArchiveMilestonesGates.showOnArchive(
          sampleMode: ScreenshotMode.enabled,
        )) {
          return const [];
        }
        return [
          ArchiveMilestonesCard(
            entries: _entries,
            onAddMoment: _goToRecord,
          ),
        ];
      case ArchiveHomeSectionId.betaFeedback:
        return [
          BetaFeedbackCard(
            entries: _entries,
            sampleMode: ScreenshotMode.enabled,
            onChanged: () {
              if (!mounted) return;
              setState(() {});
            },
          ),
        ];
      case ArchiveHomeSectionId.proInterestLink:
        return [
          ProInterestLinkCard(
            entries: _entries,
            sampleMode: ScreenshotMode.enabled,
          ),
        ];
      case ArchiveHomeSectionId.needsAttention:
        if (!layout.needsAttention.show) return const [];
        final widgets = <Widget>[];
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
        return widgets;
      case ArchiveHomeSectionId.evidenceQuality:
        if (!layout.evidenceQuality.show) return const [];
        final widgets = <Widget>[];
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
        return widgets;
      case ArchiveHomeSectionId.reviewHistory:
        if (!layout.reviewHistory.show) return const [];
        final widgets = <Widget>[];
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
        return widgets;
      case ArchiveHomeSectionId.controls:
        if (!layout.controls.show) return const [];
        final widgets = <Widget>[];
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
        return widgets;
      case ArchiveHomeSectionId.sampleArchive:
        if (!_showEmpty) return const [];
        return [
          SampleArchiveEntryCard(
            onViewSample: () => context.push('/sample-archive'),
          ),
        ];
    }
  }

  List<Widget> _earlyReturnReminderWidgets({
    required bool hasRealTimeline,
    required bool earlyProofActive,
  }) {
    if (!_earlyReturnReminderOffer || _earlyReturnReminderHidden) {
      return const [];
    }
    if (!earlyProofActive) return const [];
    if (!EarlyArchiveReturnReminderGates.eligible(
      entryCount: _entries.length,
      entries: _entries,
      hasRealTimeline: hasRealTimeline,
    )) {
      return const [];
    }
    return [
      EarlyArchiveReturnReminderCard(
        source: 'patterns',
        onDismiss: () => setState(() => _earlyReturnReminderHidden = true),
      ),
      const SizedBox(height: AppSpacing.lg),
    ];
  }

  List<Widget> _earlyEvidenceDemoWidgets() {
    final hasRealTimeline = EarlyEvidenceTimelineEngine.build(
          entries: _entries,
          triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
          helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
        ) !=
        null;
    if (!EarlyEvidenceTimelineDemo.canShowCta(
      entryCount: _entries.length,
      hasRealTimeline: hasRealTimeline,
    )) {
      return const [];
    }

    if (_earlyEvidenceDemoVisible) {
      return [
        EarlyEvidenceTimelineDemoSection(
          entryCount: _entries.length,
          surface: 'patterns',
          onHide: () {
            EarlyArchiveProofAnalytics.demoHidden(
              entryCount: _entries.length,
              surface: 'patterns',
            );
            setState(() => _earlyEvidenceDemoVisible = false);
          },
        ),
      ];
    }

    return [
      EarlyEvidenceTimelineDemoCta(
        entryCount: _entries.length,
        surface: 'patterns',
        onTap: () {
          EarlyArchiveProofAnalytics.demoOpened(
            entryCount: _entries.length,
            surface: 'patterns',
          );
          setState(() => _earlyEvidenceDemoVisible = true);
        },
      ),
    ];
  }

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
    final priorityPlan = const ArchiveHomePriorityEngine().build(
      _archiveHomePriorityInput(
        layout: layout,
        weeklyReview: weeklyReview,
      ),
    );

    List<Widget> sectionWidgetsFor(ArchiveHomeSectionId sectionId) =>
        _archiveHomeSectionWidgets(
          sectionId,
          summary: summary,
          shareProof: shareProof,
          quickActions: quickActions,
          hints: hints,
          layout: layout,
          attentionFilters: attentionFilters,
          actionPlan: actionPlan,
          archiveHealth: archiveHealth,
          contextInsights: contextInsights,
          evidenceMap: evidenceMap,
          beliefHistory: beliefHistory,
          weeklyReview: weeklyReview,
          standaloneShareProof: standaloneShareProof,
        );

    List<Widget> buildOrderedSections(List<ArchiveHomeSectionId> sectionIds) {
      final built = <Widget>[];
      for (final sectionId in sectionIds) {
        if (priorityPlan.isHidden(sectionId)) continue;
        _appendArchiveHomeSectionWidgets(
          built,
          sectionWidgetsFor(sectionId),
        );
      }
      return built;
    }

    final widgets = buildOrderedSections(priorityPlan.primarySections);

    final missionResult = const CapacityBetaMissionEngine().buildFromJournal(
      entries: _entries,
      capacityLoopActive: _capacityLoopActive,
      capacityCohortActive: _capacityCohortActive,
      fitRecord: CapacityActivationFitStore.cached,
      boundarySelection: CapacityBoundaryResponseStore.cached,
      proInterestState: ProInterestStore.cached,
      missionRecord: CapacityBetaMissionStore.cached,
    );
    final capacityThreeMomentOnHome =
        const CapacityThreeMomentEngine().buildFromJournal(
      entries: _entries,
      capacityLoopActive: _capacityLoopActive,
      capacityCohortActive: _capacityCohortActive,
    ).showOnArchiveHome;
    if (missionResult.showOnArchiveHome && !capacityThreeMomentOnHome) {
      widgets.addAll(_archiveWorkspaceSectionSpacer());
      widgets.add(
        CapacityBetaMissionCard(
          key: const Key('archive_home_capacity_beta_mission'),
          result: missionResult,
          compact: true,
          onDismiss: () async {
            await CapacityBetaMissionStore.instance().dismiss();
            if (!mounted) return;
            setState(() {});
          },
        ),
      );
    }

    if (priorityPlan.showMoreArchiveTools) {
      final secondaryWidgets =
          buildOrderedSections(priorityPlan.secondarySections);
      if (secondaryWidgets.isNotEmpty) {
        widgets.addAll(_archiveWorkspaceSectionSpacer());
        widgets.add(
          ArchiveHomeMoreToolsSection(
            key: const Key('archive_home_more_tools'),
            children: secondaryWidgets,
          ),
        );
      }
    }

    if (_showEmpty &&
        !priorityPlan.primarySections.contains(ArchiveHomeSectionId.sampleArchive) &&
        !priorityPlan.secondarySections.contains(ArchiveHomeSectionId.sampleArchive)) {
      _appendArchiveHomeSectionWidgets(
        widgets,
        sectionWidgetsFor(ArchiveHomeSectionId.sampleArchive),
      );
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
    final suppressFormingStackDuplicates =
        archiveHome.title == ArchiveEvidenceThreshold.formingTitle;
    final widgets = <Widget>[
      QuickHelpButton(
        alignment: Alignment.centerRight,
        patternTitle: _checkInCompletedRecently?.patternTitle,
        nextCheck: _checkInCompletedRecently?.question,
        onStartRecording: () async => _goToRecord(),
      ),
      const SizedBox(height: AppSpacing.sm),
      ..._archiveHomeCommandCenterWidgets(),
      if (!suppressFormingStackDuplicates) ..._buildThoughtMapPreviewWidgets(),
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
    widgets.addAll(
      suppressFormingStackDuplicates
          ? const <Widget>[]
          : _buildArchiveBeliefProofWidgets(),
    );
    widgets.addAll(_buildWhatChangedSinceLastTimeWidgets());
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
            child: PatternsEmptyView(
              fillViewport: true,
              footer: [
                const SizedBox(height: AppSpacing.lg),
                ..._earlyEvidenceDemoWidgets(),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
      );
    }

    if (_showFirstArchive) {
      final demoWidgets = _earlyEvidenceDemoWidgets();
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: ArchiveMobileSpacing.pagePadding,
              children: [
                ..._archiveHomeCommandCenterWidgets(),
                if (demoWidgets.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  ...demoWidgets,
                ],
              ],
            ),
          ),
        ),
      );
    }

    if (_usesPatternsEarlyProofScaffold) {
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
      final earlyFirstSignal = EarlyFirstSignalEngine.build(entries: _entries);
      final confirmedRepeatChangeNotice =
          EarlyFirstSignalEngine.buildChangeNotice(entries: _entries);
      final earlyEvidenceTimeline = EarlyEvidenceTimelineEngine.build(
        entries: _entries,
        triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
        helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
      );
      final showEarlyEvidenceTimeline = earlyEvidenceTimeline != null;
      final viewingConfirmedRepeatOnPatterns = showEarlyEvidenceTimeline ||
          (earlyFirstSignal?.showsConfirmedRepeat ?? false);
      final repeatReturnChangeProof = RepeatReturnCheckEngine.changeProofForReady(
        entryCount: _entries.length,
        viewingConfirmedRepeat: viewingConfirmedRepeatOnPatterns,
        isRecording: false,
        isPostSave: false,
        records: RepeatReturnCheckStore.cached,
      );
      final patternChangedCandidate = PatternChangedEngine.build(
        changeProof: repeatReturnChangeProof,
        records: RepeatReturnCheckStore.cached,
        entries: _entries,
      );
      final patternChangedDismissed = patternChangedCandidate != null &&
          PatternChangedStore.isDismissed(
            entryId: patternChangedCandidate.entryId,
            type: patternChangedCandidate.type,
          );
      final confirmedRepeatThoughtMap = ConfirmedRepeatThoughtMapEngine.build(
        entries: _entries,
        triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
        helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
        returnChecks: RepeatReturnCheckStore.cached,
      );
      final positivePattern = PositivePatternEngine.build(entries: _entries);
      final helpfulActionAppearedCandidate = HelpfulActionAppearedEngine.build(
        entries: _entries,
        returnChecks: RepeatReturnCheckStore.cached,
        helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
      );
      final showHelpfulActionAppeared = HelpfulActionAppearedGates.shouldShow(
        loaded: true,
        entryCount: _entries.length,
        isReady: true,
        isRecording: false,
        isPostSave: false,
        isDegradedPostSave: false,
        viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnPatterns,
        hasConfirmedRepeatFoundation:
            EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(_entries),
        result: helpfulActionAppearedCandidate,
      );
      final archiveChangeTimelineCandidate = ArchiveChangeTimelineEngine.build(
        entries: _entries,
        helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
        returnChecks: RepeatReturnCheckStore.cached,
        viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnPatterns,
      );
      final showArchiveChangeTimeline = ArchiveChangeTimelineGates.shouldShow(
        loaded: true,
        entryCount: _entries.length,
        isReady: true,
        isRecording: false,
        isPostSave: false,
        viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnPatterns,
        timeline: archiveChangeTimelineCandidate,
      );
      final positiveReinforcement = PositiveReinforcementEngine.build(
        positivePattern: positivePattern,
        entries: _entries,
        helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
      );
      final archiveSummaryCandidate = ArchiveSummaryEngine.build(
        entries: _entries,
        confirmedRepeat: earlyFirstSignal,
        timeline: earlyEvidenceTimeline,
        changeProof: repeatReturnChangeProof,
        triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
        helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
        returnChecks: RepeatReturnCheckStore.cached,
        viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnPatterns,
      );
      final archiveBeliefSurfaceCandidate =
          ArchiveBeliefSurfaceSource().resolve(
        _entries,
        tier: _archiveIntelligenceTier,
        confirmedRepeat: earlyFirstSignal,
        changeProof: repeatReturnChangeProof,
        returnChecks: RepeatReturnCheckStore.cached,
        triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
        helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
        viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnPatterns,
      );
      final showArchiveCurrentBelief = ArchiveCurrentBeliefGates.shouldShow(
        loaded: true,
        entryCount: _entries.length,
        isReady: true,
        isRecording: false,
        isPostSave: false,
        viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnPatterns,
        hasConfirmedRepeatFoundation:
            EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(_entries),
        hasCurrentBeliefSurface:
            archiveBeliefSurfaceCandidate.isPrimaryAfterFirstProof &&
                archiveBeliefSurfaceCandidate.shouldShow,
      );
      final dailyReturnReasonCandidate = DailyReturnReasonEngine.build(
        entries: _entries,
        changeProof: repeatReturnChangeProof,
        triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
        helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
        returnChecks: RepeatReturnCheckStore.cached,
        viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnPatterns,
      );
      final hasChangeOverTimeProof = repeatReturnChangeProof != null;
      final patternsPostProofArchiveProof =
          PaywallTimingGates.hasArchiveProofFromEntries(
        entries: _entries,
        triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
        helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
        hasChangeOverTimeProof: hasChangeOverTimeProof,
      );
      final archiveSummaryVisibleForProGate = ArchiveSummaryGates.shouldShow(
        loaded: true,
        entryCount: _entries.length,
        isReady: true,
        isRecording: false,
        viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnPatterns,
        hasSummary: archiveSummaryCandidate != null,
      );
      final weeklyArchiveReviewVisibleForProGate =
          WeeklyArchiveWeekReviewGates.shouldShow(
        loaded: true,
        entryCount: _entries.length,
        isReady: true,
        isRecording: false,
        entries: _entries,
        returnChecks: RepeatReturnCheckStore.cached,
      );
      final hasConfirmedRepeatForProGate = viewingConfirmedRepeatOnPatterns &&
          ((earlyFirstSignal?.showsConfirmedRepeat ?? false) ||
              showEarlyEvidenceTimeline);
      final privateArchiveReportForProGate = PrivateArchiveReportEngine.build(
        entries: _entries,
        triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
        helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
        returnChecks: RepeatReturnCheckStore.cached,
        viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnPatterns,
      );
      final privateArchiveReportPreviewForProGate =
          privateArchiveReportForProGate != null &&
              PrivateArchiveReportGates.shouldShow(
                loaded: true,
                entryCount: _entries.length,
                isReady: true,
                isRecording: false,
                isPostSave: false,
                viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnPatterns,
                report: privateArchiveReportForProGate,
              ) &&
              PrivateArchiveReportGates.showPreviewNote(isPro: _archiveIsPro);
      final patternChangedForProGate = patternChangedCandidate != null &&
          viewingConfirmedRepeatOnPatterns &&
          _entries.length >
              FirstThreeSessionGates.minEntriesForUsefulArchive;
      final hasReturnCheckAnsweredForProGate =
          RepeatReturnCheckTrendEngine.hasAnsweredCheck(
                RepeatReturnCheckStore.cached,
              ) &&
              _entries.length >= PaywallTimingGates.minFullArchiveHistoryEntryCount;
      final showPatternsPostProofProBridge =
          PaywallTimingGates.showPostProofProBridge(
        entryCount: _entries.length,
        resolved: _proBridgeResolved,
        isPro: _archiveIsPro,
        hasArchiveProof: patternsPostProofArchiveProof,
        viewingConfirmedRepeatOrTimeline: hasConfirmedRepeatForProGate,
        hasChangeOverTimeProof: hasChangeOverTimeProof,
        hasArchiveSummary: archiveSummaryVisibleForProGate,
        hasWeeklyArchiveReview: weeklyArchiveReviewVisibleForProGate,
        hasPatternChanged: patternChangedForProGate,
        hasPrivateArchiveReportPreview: privateArchiveReportPreviewForProGate,
        hasReturnCheckAnswered: hasReturnCheckAnsweredForProGate,
      );
      final proofSurfaceLayout = ArchiveProofSurfaceLayout(
        confirmedRepeatCardVisible: !showEarlyEvidenceTimeline &&
            (earlyFirstSignal?.showsConfirmedRepeat ?? false),
        timelineVisible: showEarlyEvidenceTimeline,
        changeProofVisible: repeatReturnChangeProof != null,
        proBridgeVisible: showPatternsPostProofProBridge,
        whyMattersVisible: ConfirmedRepeatWhyMattersGates.shouldShow(
          loaded: true,
          viewingConfirmedRepeat: viewingConfirmedRepeatOnPatterns,
          entryCount: _entries.length,
          isReady: true,
          isRecording: false,
          dismissed: ConfirmedRepeatWhyMattersStore.cachedDismissed,
        ),
        thoughtMapVisible: ConfirmedRepeatThoughtMapGates.shouldShow(
          loaded: true,
          viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnPatterns,
          entryCount: _entries.length,
          isReady: true,
          isRecording: false,
          hasThoughtMap: confirmedRepeatThoughtMap != null,
        ),
        positiveReinforcementVisible: PositiveReinforcementGates.shouldShow(
          loaded: true,
          entryCount: _entries.length,
          isReady: true,
          isRecording: false,
          hasPositivePattern: positiveReinforcement != null,
        ) &&
            !showHelpfulActionAppeared,
        positivePatternVisible: false,
        patternChangedVisible: PatternChangedGates.shouldShow(
          loaded: true,
          entryCount: _entries.length,
          isReady: true,
          isRecording: false,
          isPostSave: false,
          viewingConfirmedRepeat: viewingConfirmedRepeatOnPatterns,
          patternChanged: patternChangedCandidate,
          dismissed: patternChangedDismissed,
        ),
        helpfulActionAppearedVisible: showHelpfulActionAppeared,
        archiveSummaryVisible: ArchiveSummaryGates.shouldShow(
          loaded: true,
          entryCount: _entries.length,
          isReady: true,
          isRecording: false,
          viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnPatterns,
          hasSummary: archiveSummaryCandidate != null,
        ),
        archiveCurrentBeliefVisible: showArchiveCurrentBelief,
        archiveChangeTimelineVisible: showArchiveChangeTimeline,
      );
      final showArchiveSummary = proofSurfaceLayout.effectiveArchiveSummaryVisible;
      final archiveSummary = showArchiveSummary ? archiveSummaryCandidate : null;
      final showDailyReturnReason = DailyReturnReasonGates.shouldShow(
        loaded: true,
        entryCount: _entries.length,
        isReady: true,
        isRecording: false,
        viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnPatterns,
        hasReason: dailyReturnReasonCandidate != null,
      );
      final dailyReturnReason =
          showDailyReturnReason ? dailyReturnReasonCandidate : null;
      final archiveWatchingCandidate = ArchiveWatchingEngine.build(
        entries: _entries,
        changeProof: repeatReturnChangeProof,
        triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
        helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
        returnChecks: RepeatReturnCheckStore.cached,
        viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnPatterns,
      );
      final archiveWatching = ArchiveWatchingGates.shouldShow(
            loaded: true,
            entryCount: _entries.length,
            isReady: true,
            isRecording: false,
            viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnPatterns,
            archiveSummaryVisible: showArchiveSummary,
            hasWatching: archiveWatchingCandidate != null,
          )
          ? archiveWatchingCandidate
          : null;
      final weeklyArchiveWeekReview = WeeklyArchiveWeekReviewEngine.build(
        entries: _entries,
        confirmedRepeat: earlyFirstSignal,
        changeProof: repeatReturnChangeProof,
        triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
        helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
        returnChecks: RepeatReturnCheckStore.cached,
        viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnPatterns,
      );
      final showWeeklyArchiveWeekReview = WeeklyArchiveWeekReviewGates.shouldShow(
        loaded: true,
        entryCount: _entries.length,
        isReady: true,
        isRecording: false,
        entries: _entries,
        returnChecks: RepeatReturnCheckStore.cached,
      );
      final privateArchiveReportCandidate = PrivateArchiveReportEngine.build(
        entries: _entries,
        triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
        helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
        returnChecks: RepeatReturnCheckStore.cached,
        viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnPatterns,
      );
      final showPrivateArchiveReport = PrivateArchiveReportGates.shouldShow(
        loaded: true,
        entryCount: _entries.length,
        isReady: true,
        isRecording: false,
        isPostSave: false,
        viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnPatterns,
        report: privateArchiveReportCandidate,
      );
      final showConfirmedRepeatWhyMatters =
          proofSurfaceLayout.effectiveWhyMattersVisible;
      final showConfirmedRepeatThoughtMap =
          proofSurfaceLayout.effectiveThoughtMapVisible;
      final showPositiveReinforcement =
          proofSurfaceLayout.effectivePositiveReinforcementVisible;
      final showPatternChanged =
          proofSurfaceLayout.effectivePatternChangedVisible;
      final showThoughtMapRecordCta = showConfirmedRepeatThoughtMap &&
          confirmedRepeatThoughtMap?.firstMissingSection != null;
      final suppressConfirmedRepeatInlineFeedback =
          ConfirmedRepeatBetaFeedbackGates.suppressInlineAccuracyFeedback(
        state: ConfirmedRepeatBetaFeedbackStore.cached,
      );
      final suppressArchiveHomeEarlyProofDuplicate =
          showEarlyEvidenceTimeline || earlyFirstSignal != null;
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
                if (showEarlyEvidenceTimeline) ...[
                  EarlyEvidenceTimelineCard(
                    timeline: earlyEvidenceTimeline!,
                    nearbyConfirmedRepeat: proofSurfaceLayout.timelineNearby,
                    suppressEvidencePhrases:
                        proofSurfaceLayout.suppressTimelineEvidencePhrases,
                    analyticsSurface: 'patterns',
                    entryCount: _entries.length,
                    entriesForWhy: _entries,
                    onRecordWhatHelped:
                        earlyEvidenceTimeline.showsSofterReturn &&
                            !earlyEvidenceTimeline.showsHelpfulAction
                        ? () {
                            ConfirmedRepeatHelpfulActionCapture.armForNextSave();
                            context.go(
                              EarlyFirstSignalRecordRoutes.routeWithWhatHelpedPrompt(
                                autostart: true,
                              ),
                            );
                          }
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (!showEarlyEvidenceTimeline &&
                    earlyFirstSignal != null &&
                    proofSurfaceLayout.effectiveConfirmedRepeatCardVisible) ...[
                  EarlyFirstSignalCard(
                    signal: earlyFirstSignal!,
                    showInsightFeedback: !suppressConfirmedRepeatInlineFeedback,
                    analyticsSurface: 'patterns',
                    entryCount: _entries.length,
                    entriesForWhy: _entries,
                    onPrimary: _goToRecord,
                    onViewEvidence: earlyFirstSignal!.showsConfirmedRepeat
                        ? () => context.push(BeliefEvidenceNavigation.route)
                        : null,
                    onReturnPrompt: earlyFirstSignal!.returnPrompt != null
                        ? () {
                            ConfirmedRepeatTriggerCapture.armForNextSave();
                            context.go(
                              EarlyFirstSignalRecordRoutes.routeWithTriggerPrompt(
                                autostart: true,
                              ),
                            );
                          }
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (showArchiveCurrentBelief &&
                    archiveBeliefSurfaceCandidate.shouldShow) ...[
                  ArchiveBeliefSurfaceCard(
                    surface: archiveBeliefSurfaceCandidate,
                    onRecordNext: () => context.go(
                      ArchiveProofRecordRoutes.uri(
                        guidedPromptNodeKey:
                            ArchiveProofRecordRoutes.changeTimelineNodeKey,
                      ),
                    ),
                    onDismissed: () => setState(() {}),
                  ),
                  SizedBox(height: ArchiveMobileSpacing.proofStackCardGap),
                ],
                ..._buildWhatChangedSinceLastTimeWidgets(),
                if (showPatternChanged && patternChangedCandidate != null) ...[
                  PatternChangedCard(
                    result: patternChangedCandidate,
                    entryCount: _entries.length,
                    surface: 'patterns',
                    onRecord: () => _handlePatternChangedRecord(
                      patternChangedCandidate,
                    ),
                    onDismissed: () => setState(() {}),
                  ),
                  SizedBox(height: ArchiveMobileSpacing.proofStackCardGap),
                ] else if (proofSurfaceLayout.effectiveChangeProofVisible &&
                    repeatReturnChangeProof != null) ...[
                  RepeatReturnCheckChangeProofCard(
                    proof: repeatReturnChangeProof,
                    entryCount: _entries.length,
                    surface: 'patterns',
                    onRecordNext: _goToRecord,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                ..._buildHelpfulActionAppearedWidgets(),
                if (showArchiveChangeTimeline &&
                    archiveChangeTimelineCandidate != null) ...[
                  ArchiveChangeTimelineCard(
                    timeline: archiveChangeTimelineCandidate,
                    entryCount: _entries.length,
                  ),
                  SizedBox(height: ArchiveMobileSpacing.proofStackCardGap),
                ],
                if (showArchiveSummary && archiveSummary != null) ...[
                  ArchiveSummaryCard(
                    summary: archiveSummary,
                    showRecordNextCta: true,
                    watching: archiveWatching,
                    onRecordNext: () => _handleArchiveSummaryRecordNext(
                      archiveSummary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (showDailyReturnReason && dailyReturnReason != null) ...[
                  DailyReturnReasonCard(
                    reason: dailyReturnReason,
                    showRecordCta: true,
                    onRecord: () => _handleDailyReturnReason(dailyReturnReason),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (showWeeklyArchiveWeekReview &&
                    weeklyArchiveWeekReview != null) ...[
                  week_review.WeeklyArchiveWeekReviewCard(
                    review: weeklyArchiveWeekReview,
                    showRecordCta: true,
                    onRecord: () => _handleWeeklyArchiveWeekReview(
                      weeklyArchiveWeekReview,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (showPrivateArchiveReport &&
                    privateArchiveReportCandidate != null) ...[
                  PrivateArchiveReportCard(
                    report: privateArchiveReportCandidate,
                    entryCount: _entries.length,
                    surface: 'patterns',
                    isPro: _archiveIsPro,
                    onSeePro: _archiveIsPro
                        ? null
                        : () => context.push('/subscription'),
                  ),
                  SizedBox(height: ArchiveMobileSpacing.proofStackCardGap),
                ],
                if (showConfirmedRepeatWhyMatters) ...[
                  ConfirmedRepeatWhyMattersCard(
                    onDismissed: () => setState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (showConfirmedRepeatThoughtMap &&
                    confirmedRepeatThoughtMap != null) ...[
                  ConfirmedRepeatThoughtMapCard(
                    result: confirmedRepeatThoughtMap,
                    showRecordMissingPieceCta: showThoughtMapRecordCta,
                    onRecordMissingPiece: () => _handleThoughtMapMissingPiece(
                      confirmedRepeatThoughtMap,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (showPositiveReinforcement &&
                    positiveReinforcement != null) ...[
                  PositiveReinforcementCard(
                    reinforcement: positiveReinforcement,
                    showRecordAgainCta: !positiveReinforcement.isCompletion,
                    onRecordAgain: () => _handlePositiveReinforcementRecordAgain(
                      positiveReinforcement,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (viewingConfirmedRepeatOnPatterns &&
                    _entries.length >=
                        ConfirmedRepeatBetaFeedbackGates.minEntryCount) ...[
                  ConfirmedRepeatBetaFeedbackCard(
                    entryCount: _entries.length,
                    surface: 'patterns',
                    viewingConfirmedRepeat: viewingConfirmedRepeatOnPatterns,
                    isRecording: false,
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (showPatternsPostProofProBridge) ...[
                  ArchiveIntelligenceProBridgeCard(
                    compact: proofSurfaceLayout.proBridgeCompact,
                    onSeePro: () {
                      EarlyArchiveProofAnalytics.proScreenOpenedAfterTimeline(
                        source: 'patterns_post_proof_bridge',
                      );
                      context.push('/subscription');
                    },
                    onNotNow: () async {
                      await RecordReturnProStore.instance().markProBridgeResolved();
                      if (!mounted) return;
                      setState(() => _proBridgeResolved = true);
                    },
                  ),
                  SizedBox(height: ArchiveMobileSpacing.proofStackCardGap),
                ],
                if (!showEarlyEvidenceTimeline &&
                    confirmedRepeatChangeNotice != null) ...[
                  ConfirmedRepeatChangeNoticeCard(
                    notice: confirmedRepeatChangeNotice!,
                    analyticsSurface: 'patterns',
                    entryCount: _entries.length,
                    entriesForWhy: _entries,
                    onRecordWhatHelped: () {
                      ConfirmedRepeatHelpfulActionCapture.armForNextSave();
                      context.go(
                        EarlyFirstSignalRecordRoutes.routeWithWhatHelpedPrompt(
                          autostart: true,
                        ),
                      );
                    },
                    onViewEvidence: () =>
                        context.push(BeliefEvidenceNavigation.route),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                ..._earlyReturnReminderWidgets(
                  hasRealTimeline: showEarlyEvidenceTimeline,
                  earlyProofActive: showEarlyEvidenceTimeline ||
                      (earlyFirstSignal?.showsConfirmedRepeat ?? false),
                ),
                if (!suppressArchiveHomeEarlyProofDuplicate)
                  ..._archiveHomeCommandCenterWidgets(),
                ..._buildThoughtMapPreviewWidgets(),
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
                    thirdEntryBeliefPayoff != null &&
                    !showEarlyEvidenceTimeline &&
                    earlyFirstSignal?.kind !=
                        EarlyFirstSignalKind.threeEntryConfirmedRepeat) ...[
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
                    secondSessionPayoff != null &&
                    earlyFirstSignal?.kind !=
                        EarlyFirstSignalKind.twoEntryFirstSignal) ...[
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
                  suppressWhenPostProofShown: showPatternsPostProofProBridge,
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

    if (isIntentionalEmptyArchive(_entries)) {
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: const PatternsEmptyView(fillViewport: true),
          ),
        ),
      );
    }

    final strongest = _strongest;
    if (strongest == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: const SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: PatternsMindMapFormingCard(),
            ),
          ),
        ),
      );
    }

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
