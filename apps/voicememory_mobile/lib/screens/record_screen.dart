import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../audio/recording_service.dart';
import '../services/app_services.dart';
import '../services/capture_pipeline_service.dart';
import '../services/record_pipeline_log.dart';
import '../services/capture_save_messages.dart';
import '../design/archive_mobile_typography.dart';
import '../theme/app_colors.dart';
import '../theme/voicememory_colors.dart';
import '../theme/voicememory_typography.dart';
import '../features/timeline/timeline_entry_display.dart';
import '../features/voice_capture/voice_capture_copy.dart';
import '../features/voice_capture/voice_capture_post_save.dart';
import '../features/voice_capture/voice_capture_quality.dart';
import '../features/voice_capture/microphone_permission_copy.dart';
import '../features/voice_capture/microphone_permission_environment.dart';
import '../features/voice_capture/microphone_permission_state.dart';
import '../features/memory/memory_scope_store.dart';
import '../features/memory/curated_memory_marker.dart';
import '../features/memory/keep_exact_details.dart';
import '../features/memory/treat_as_new.dart';
import '../widgets/memory/entry_options_section.dart';
import '../widgets/memory/not_about_me_receipt.dart';
import '../widgets/memory/do_not_surface_receipt.dart';
import '../widgets/memory/sensitive_surfacing_receipt.dart';
import '../features/memory/entry_aboutness.dart';
import '../features/memory/memory_surfacing_mode.dart';
import '../widgets/memory/clean_slate_prompt_section.dart';
import '../features/memory/clean_slate_prompt_store.dart';
import '../widgets/memory/keep_exact_details_control.dart';
import '../widgets/memory/curated_memory_receipt.dart';
import '../widgets/memory/treat_as_new_control.dart';
import '../features/archive_movement/archive_movement.dart';
import '../features/archive_prompt/archive_prompt_engine.dart';
import '../product/belief_product_copy.dart';
import '../product/consumer_copy_guard.dart';
import '../product/consumer_ui_copy.dart';
import '../config/trial_mode.dart';
import '../features/trial/hook_rescue_decision_engine.dart';
import '../features/trial/hook_rescue_decision_model.dart';
import '../features/trial/trial_summary_engine.dart';
import '../config/creator_demo_mode.dart';
import '../config/screenshot_mode.dart';
import '../config/screenshot_sample_data.dart';
import '../features/tomorrow_return/return_comparison_coordinator.dart';
import '../features/tomorrow_return/return_comparison_model.dart';
import '../features/tomorrow_return/return_retention_coordinator.dart';
import '../features/tomorrow_return/return_streak_model.dart';
import '../features/tomorrow_return/tomorrow_return_loop_coordinator.dart';
import '../features/tomorrow_return/tomorrow_return_loop_models.dart';
import '../features/activation/activation_tracker.dart';
import '../features/feedback/archive_feedback_coordinator.dart';
import '../features/feedback/archive_feedback_model.dart';
import '../features/input_quality/input_quality_engine.dart';
import '../features/perspective/kinder_angle_engine.dart';
import '../features/perspective/kinder_angle_model.dart';
import '../features/quick_help/quick_help_model.dart';
import '../features/moments/key_moment_coordinator.dart';
import '../features/moments/key_moment_model.dart';
import '../features/input_quality/input_quality_model.dart';
import '../features/input_quality/input_quality_store.dart';
import '../features/language/language_detection_engine.dart';
import '../features/language/language_model.dart';
import '../features/language/reflection_language_store.dart';
import '../widgets/language/language_indicator_chip.dart';
import '../features/activation/first_loop_activation_coordinator.dart';
import '../features/activation/first_loop_activation_model.dart';
import '../features/activation/return_day_friction_coordinator.dart';
import '../features/activation/first_three_journey_coordinator.dart';
import '../features/tomorrow_return/check_in_reminder_service.dart';
import '../features/activation/first_three_journey_model.dart';
import '../features/activation/first_three_session_gates.dart';
import '../features/first_session/first_session_coordinator.dart';
import '../features/first_session/first_session_pattern_model.dart';
import '../features/tomorrow_return/active_pattern_thread_coordinator.dart';
import '../features/tomorrow_return/active_pattern_thread_model.dart';
import '../features/pattern_memory/habit_proof_model.dart';
import '../features/pattern_memory/pattern_memory_coordinator.dart';
import '../features/pattern_memory/pattern_memory_model.dart';
import '../features/pattern_memory/pattern_next_action_model.dart';
import '../features/pattern_memory/pattern_progress_model.dart';
import '../features/pattern_memory/pattern_share_recap_model.dart';
import '../features/pattern_memory/pattern_share_service.dart';
import '../features/pattern_memory/weekly_pattern_recap_model.dart';
import '../features/routine/routine_anchor_model.dart';
import '../features/routine/routine_anchor_store.dart';
import '../features/tomorrow_return/tomorrow_check_in_coordinator.dart';
import '../features/tomorrow_return/tomorrow_check_in_model.dart';
import '../features/tomorrow_return/watch_for_coordinator.dart';
import '../features/tomorrow_return/watch_for_model.dart';
import '../features/archive_beliefs/archive_beliefs_presenter.dart';
import '../widgets/potential_signals_card.dart';
import '../widgets/patterns/return_comparison_card.dart';
import '../widgets/patterns/return_streak_card.dart';
import '../widgets/routine/routine_anchor_chooser.dart';
import '../widgets/record/tomorrow_commitment_card.dart';
import '../widgets/record/tomorrow_return_card.dart';
import '../widgets/record/active_pattern_thread_prompt_card.dart';
import '../widgets/activation/first_three_journey_card.dart';
import '../widgets/record/first_reflection_result_card.dart';
import '../widgets/record/post_save_insight_choice_card.dart';
import '../widgets/record/second_session_comparison_card.dart';
import '../widgets/record/pattern_hypothesis_card.dart';
import '../features/signal_journey/signal_journey_coordinator.dart';
import '../features/signal_journey/signal_journey_model.dart';
import '../features/signal_review/signal_review_coordinator.dart';
import '../features/signal_review/signal_review_model.dart';
import '../features/signal_review/signal_review_navigation.dart';
import '../widgets/signal/archive_watching_card.dart';
import '../widgets/signal/signal_journey_card.dart';
import '../widgets/signal/signal_journey_completion_card.dart';
import '../widgets/signal/signal_review_card.dart';
import '../features/retention/second_session_signal_engine.dart';
import '../features/retention/second_session_signal_model.dart';
import '../features/retention/pattern_hypothesis_engine.dart';
import '../features/retention/pattern_hypothesis_model.dart';
import '../features/post_save_insight/selected_signal_coordinator.dart';
import '../features/post_save_insight/signal_feedback_store.dart';
import '../features/post_save_insight/signal_feedback_coordinator.dart';
import '../features/post_save_insight/signal_feedback_model.dart';
import '../features/post_save_insight/selected_signal_model.dart';
import '../features/signal_archive/signal_archive_coordinator.dart';
import '../features/signal_archive/signal_archive_snapshot.dart';
import '../features/objective/current_objective_model.dart';
import '../features/objective/current_objective_snapshot_store.dart';
import '../widgets/record/input_quality_coach_card.dart';
import '../widgets/onboarding/archive_memory_demo_card.dart';
import '../widgets/record/first_loop_start_card.dart';
import '../widgets/record/return_day_closed_card.dart';
import '../widgets/record/habit_proof_card.dart';
import '../widgets/record/weekly_pattern_recap_card.dart';
import '../widgets/record/pattern_next_action_card.dart';
import '../widgets/record/check_in_completed_card.dart';
import '../widgets/quick_help/quick_help_button.dart';
import '../widgets/quick_help/quick_help_sheet.dart';
import '../widgets/record/kinder_angle_card.dart';
import '../widgets/record/perspective_shift_card.dart';
import '../widgets/record/result_next_check_card.dart';
import '../widgets/record/pattern_memory_after_save_card.dart';
import '../widgets/record/pattern_progress_after_save_card.dart';
import '../widgets/patterns/missed_check_in_reason_prompt.dart';
import '../widgets/record/tomorrow_check_in_due_card.dart';
import '../widgets/record/todays_watch_for_card.dart';
import '../widgets/record/watch_for_tomorrow_card.dart';
import '../widgets/patterns/active_pattern_thread_card.dart';
import '../widgets/patterns/watch_for_result_card.dart';
import '../widgets/record/consumer_record_prompts_section.dart';
import '../features/record/record_stack_policy.dart';
import '../features/record/daily_mirror_engine.dart';
import '../features/record/daily_mirror_model.dart';
import '../features/record/record_empty_archive_gates.dart';
import '../features/acquisition/audience_wedge_model.dart';
import '../features/acquisition/audience_wedge_store.dart';
import '../features/loop_mode/loop_mode_coordinator.dart';
import '../features/loop_mode/loop_mode_model.dart';
import '../features/quality/first_insight_specificity_store.dart';
import '../widgets/loop_mode/loop_mode_progress_card.dart';
import '../widgets/record/loop_mode_first_handoff_card.dart';
import '../features/retention/next_evidence_reminder_service.dart';
import '../features/retention/reminder_pre_prompt_coordinator.dart';
import '../features/retention/return_reason_capture_coordinator.dart';
import '../features/retention/return_day_journey_engine.dart';
import '../features/objective/current_objective_engine.dart';
import '../features/objective/current_objective_model.dart';
import '../features/retention/retention_reminder_coordinator.dart';
import '../features/retention/retention_state_engine.dart';
import '../features/retention/retention_state_model.dart';
import '../features/tomorrow_return/compelling_check_engine.dart';
import '../widgets/objective/current_objective_card.dart';
import '../widgets/retention/retention_state_card.dart';
import '../widgets/record/first_recording_handoff_card.dart';
import '../widgets/retention/reminder_pre_prompt_sheet.dart';
import '../widgets/signal/return_day_journey_card.dart';
import '../widgets/trial/trial_first_moment_card.dart';
import '../dev/visual_audit_overrides.dart';
import '../features/archive_state_object/archive_state_object.dart';
import '../models/journal_entry.dart';
import '../features/archive_evolution/archive_evolution_coordinator.dart';
import '../features/archive_evolution/archive_evolution_models.dart';
import '../features/instant_reflection/instant_reflection_response.dart';
import '../features/instant_reflection/instant_reflection_response_engine.dart';
import '../widgets/indigo_capture_waveform.dart';
import '../features/daily_discoveries/daily_discovery_engine.dart';
import '../features/daily_discoveries/daily_discovery_models.dart';
import '../features/daily_discoveries/daily_discovery_store.dart';
import '../services/activation_funnel_analytics.dart';
import '../services/product_analytics.dart';
import '../features/pressure_retention/pressure_return_trigger_store.dart';
import '../widgets/capture_entry_actions.dart';
import '../widgets/record/entry_direction_starters.dart';
import '../billing/purchase_intent_return_cue.dart';
import '../features/referral/invite_attribution.dart';
import '../features/referral/invite_funnel_metrics.dart';
import '../features/referral/invited_day_two_return.dart';
import '../features/referral/invited_user_welcome.dart';
import '../widgets/referral/invited_day_two_return_card.dart';
import '../widgets/referral/invited_user_welcome_card.dart';
import '../features/first_session/day_seven_continuity_loop.dart';
import '../features/first_session/day_two_reminder.dart';
import '../features/first_session/day_two_return_preview.dart';
import '../features/first_session/first_recording_sample.dart';
import '../features/first_session/two_day_activation_engine.dart';
import '../widgets/first_session/day_seven_continuity_card.dart';
import '../widgets/first_session/day_two_reminder_card.dart';
import '../widgets/first_session/day_two_return_preview_card.dart';
import '../widgets/first_session/first_recording_sample_card.dart';
import '../widgets/first_session/first_save_rescue_card.dart';
import '../widgets/first_session/first_session_explanation_card.dart';
import '../widgets/first_session/two_day_activation_card.dart';
import '../widgets/pressure_retention/pressure_return_trigger_reminder.dart';
import '../billing/archive_entitlement_reader.dart';
import '../billing/paywall_route_args.dart';
import '../billing/paywall_source.dart';
import '../billing/suggestion_attribution_event.dart';
import '../billing/suggestion_attribution_store.dart';
import '../features/pressure_retention/archive_proof_counter_engine.dart';
import '../features/pressure_retention/archive_proof_counter_model.dart';
import '../features/pressure_retention/daily_return_suggestion_engine.dart';
import '../features/pressure_retention/daily_return_suggestion_model.dart';
import '../features/pressure_retention/done_for_today_receipt_engine.dart';
import '../features/pressure_retention/done_for_today_receipt_model.dart';
import '../features/pressure_retention/low_effort_check_in_engine.dart';
import '../features/pressure_retention/low_effort_check_in_model.dart';
import '../features/pressure_retention/one_small_recording_engine.dart';
import '../features/pressure_retention/one_small_recording_model.dart';
import '../features/pressure_retention/personal_return_prompt_engine.dart';
import '../features/pressure_retention/pressure_context.dart';
import '../billing/value_moment_paywall_trigger.dart';
import '../features/pressure_retention/shareable_archive_proof_engine.dart';
import '../features/pressure_retention/shareable_archive_proof_model.dart';
import '../features/pressure_retention/personal_return_prompt_model.dart';
import '../features/pressure_retention/pressure_check_in_record.dart';
import '../features/pressure_retention/pressure_check_in_store.dart';
import '../features/pressure_retention/start_here_save_receipt_engine.dart';
import '../features/pressure_retention/start_here_save_receipt_model.dart';
import '../features/pressure_retention/thread_return_evidence_engine.dart';
import '../features/pressure_retention/weekly_thread_review_engine.dart';
import '../widgets/record/start_here_save_receipt_card.dart';
import '../widgets/record/daily_return_suggestions_card.dart';
import '../widgets/billing/purchase_intent_return_cue_card.dart';
import '../widgets/billing/value_moment_pro_bridge.dart';
import '../widgets/pressure_retention/archive_proof_counter_card.dart';
import '../widgets/pressure_retention/shareable_archive_proof_card.dart';
import '../widgets/record/done_for_today_receipt_card.dart';
import '../widgets/record/post_save_recorded_summary_card.dart';
import '../widgets/record/post_save_listening_card.dart';
import '../widgets/record/evidence_context_tag_card.dart';
import '../widgets/record/low_effort_check_in_card.dart';
import '../widgets/record/one_small_recording_card.dart';
import '../widgets/record/daily_mirror_record_card.dart';
import '../widgets/record/microphone_permission_blocked_panel.dart';
import '../widgets/record/record_top_archive_promise_hero.dart';
import '../widgets/record/record_screen_close_button.dart';
import '../widgets/record/record_first_run_privacy_reassurance.dart';
import '../features/onboarding/record_return_pro_state.dart';
import '../features/onboarding/record_return_pro_store.dart';
import '../features/memory/memory_scope.dart';
import '../features/memory/memory_scope_policy.dart';
import '../features/retention/repeat_recording_nudge_state.dart';
import '../features/retention/repeat_recording_nudge_store.dart';
import '../features/aha/aha_moment_candidate.dart';
import '../features/aha/aha_moment_engine.dart';
import '../features/aha/aha_moment_store.dart';
import '../widgets/aha/first_aha_moment_card.dart';
import '../features/trust/archive_trust_receipt.dart';
import '../widgets/trust/archive_private_receipt_card.dart';
import '../widgets/trust/pro_value_clarity_card.dart';
import '../widgets/share/aha_proof_share_card.dart';
import '../features/trust/aha_proof_share_eligibility.dart';
import '../widgets/retention/day2_return_reason_card.dart';
import '../widgets/retention/second_entry_nudge_card.dart';
import '../widgets/retention/tiny_record_again_cta.dart';
import '../widgets/onboarding/change_starts_card.dart';
import '../features/archive_proof/archive_demo_preview_resolver.dart';
import '../features/archive_proof/archive_proof_record_routes.dart';
import '../widgets/onboarding/first_save_evidence_card.dart';
import '../widgets/patterns/archive_demo_preview_card.dart';
import '../widgets/onboarding/pro_archive_continuity_card.dart';
import '../widgets/onboarding/record_once_intro_card.dart';
import '../widgets/onboarding/tomorrow_return_cue_card.dart';
import '../record/example_prompt_visibility.dart';
import '../record/record_screen_framing_copy.dart';

import '../features/voice_capture/record_microphone_permission_ui.dart';
import '../features/voice_capture/record_cta_policy.dart';

export '../features/voice_capture/record_microphone_permission_ui.dart'
    show RecordUiState;

void _recordLog(String message) {
  debugPrint('RECORD: $message');
}

void _recordPermissionUiLog(String message) {
  debugPrint('${RecordMicrophonePermissionUi.logPrefix} $message');
}

void _recordCtaLog(String message) {
  debugPrint('${RecordMicrophonePermissionUi.recordCtaLogPrefix} $message');
}

class RecordScreen extends StatefulWidget {
  const RecordScreen({
    super.key,
    this.initialPrompt,
    this.autostartWithPrompt = false,
    this.pressureCheckInStore,
    this.suggestionAttributionStore,
    this.entitlementReader,
    this.purchaseIntentStore,
    this.inviteAttributionStore,
  });

  /// Optional conversation starter from deep links / empty-state chips.
  final String? initialPrompt;

  /// When true (and mic is ready), begins recording after applying [initialPrompt].
  final bool autostartWithPrompt;

  /// Injectable for tests; defaults to the live prefs-backed store.
  final PressureCheckInStore? pressureCheckInStore;

  /// Injectable for tests; defaults to the live prefs-backed store.
  final SuggestionAttributionStore? suggestionAttributionStore;

  /// Injectable for tests; defaults to the live billing-backed reader.
  final ArchiveEntitlementReader? entitlementReader;

  /// Injectable for tests; defaults to the live prefs-backed store.
  final PurchaseIntentStore? purchaseIntentStore;

  /// Injectable for tests; defaults to the live prefs-backed store.
  final InviteAttributionStore? inviteAttributionStore;

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  RecordUiState _ui = RecordUiState.idle;
  RecordingPhase _mic = RecordingPhase.idle;
  MicrophonePermissionState _micPermissionState =
      MicrophonePermissionState.unknown;
  bool _micPermissionUserDenied = false;
  bool _micSessionRequiresOpenSettings = false;
  bool _showMicPermissionSimulatorHelper = false;
  bool _ignoreStaleMicRefreshAfterGrant = false;
  final GlobalKey _permissionPanelKey = GlobalKey();
  int _seconds = 0;
  String? _error;
  String? _localSaveTitle;
  String? _syncNote;
  ArchiveMovementUpdate? _archiveMovement;
  int _journalEntryCount = 0;
  bool _journalEntryCountLoaded = false;
  List<JournalEntry> _journalEntries = const [];
  DateTime? _lastReflectionAt;

  /// Saved entry dates for the 2-day activation path; falls back to
  /// count-only cautious copy when empty or unreliable.
  List<DateTime> _entryDates = const [];
  bool _firstArchiveMilestoneCompleted = false;
  bool _autostartWithPromptAttempted = false;
  String _stageLabel = '';
  PipelineStage? _pipelineStage;
  String? _selectedPromptLine;
  AudienceWedge? _audienceWedge;
  LoopMode? _activeLoop;
  String? _postSaveFollowUp;
  bool _showPostSaveLoop = false;
  bool _lastCaptureAnalysisSucceeded = true;
  bool _lastCaptureLowQualityTranscript = false;
  bool _lastCaptureLikelySilentInput = false;
  List<JournalEntry> _entriesAfterSave = [];
  ArchiveStateObjectV3? _archiveStateAfterSave;
  InstantReflectionResponse? _instantReflectionResponse;
  DailyDiscovery? _immediateDiscovery;
  bool _immediateDiscoveryLoading = false;
  ArchiveEvolution? _postSaveEvolution;
  bool _archiveEvolutionLoading = false;
  TomorrowReturnLoop? _tomorrowReturnLoop;
  ReturnComparison? _returnComparison;
  ReturnStreak? _returnStreak;
  TomorrowCheckIn? _dueCheckInToday;
  RoutineAnchor? _dueRoutineAnchor;
  TomorrowCheckIn? _missedCheckInForDiagnosis;
  TomorrowCheckIn? _completedCheckInToday;
  PatternMemory? _patternMemory;
  PatternProgressMoment? _patternProgress;
  PatternNextAction? _patternNextAction;
  HabitProofMoment? _habitProof;
  WeeklyPatternRecap? _weeklyRecap;
  PatternShareRecap? _shareRecap;
  WatchForItem? _pendingWatchForToday;
  WatchForItem? _completedWatchForToday;
  WatchForItem? _suggestedWatchForTomorrow;
  int _watchForAlternativeIndex = 0;
  ActivePatternThread? _activePatternThread;
  bool _isFirstSessionPostSave = false;
  FirstSessionPattern? _firstSessionPattern;
  int _firstSessionAlternativeIndex = 0;
  FirstLoopActivationState _firstLoop = FirstLoopActivationState.empty;
  bool _firstLoopJustReady = false;
  String _firstLoopReadyQuestion = '';
  bool _returnDayJustClosed = false;
  FirstThreeJourneyModel? _firstThreeJourney;
  bool _watchForAcceptPending = false;
  HookRescueDecision? _hookRescue;
  String? _hookRescueNotUsefulReason;
  ArchiveFeedbackType? _feedbackHint;
  InputQualityResult? _inputQuality;
  String _inputQualityText = '';
  bool _inputQualityResolved = false;
  bool _firstRecordCardTracked = false;
  TomorrowCheckIn? _activeCheckInForTomorrow;
  TomorrowCheckIn? _recentMissedCheckIn;
  bool _retentionNextCheckJustChosen = false;
  bool _retentionDismissed = false;
  SecondSessionComparison? _secondSessionComparison;
  PatternHypothesis? _patternHypothesis;
  bool _patternHypothesisDismissed = false;
  String? _nextEvidencePrompt;
  FirstSessionPattern? _postSavePattern;
  List<PostSaveSignalFeedback> _postSaveInsightFeedback = const [];
  SelectedSignalRecord? _postSaveSelectedSignal;
  SignalArchiveSnapshot? _signalArchiveSnapshot;
  SignalJourney? _signalJourney;
  SignalReview? _signalReview;
  bool _journeyCompletionDismissed = false;
  PendingPurchaseIntent? _purchaseIntentCue;
  String? _invitedWelcomeSource;

  /// First-touch invite attribution source, when one exists — used by the
  /// invited Day 2 return copy. Stable id only, never referrer identity.
  String? _inviteSource;
  bool _hasWeeklyReviewForContinuity = false;
  bool _hasConnectedThreadForContinuity = false;
  AhaMomentCandidate? _ahaCandidate;

  /// Active UI language for post-save cards. Defaults to English; updated from
  /// reflection detection (or the screenshot override) and the language chip.
  String _languageCode = ScreenshotMode.languageCode;

  /// The originally detected language, used by the "Use detected language"
  /// override option.
  String _detectedLanguageCode = ScreenshotMode.languageCode;

  late final RecordingService _recording;
  late final CapturePipelineService _pipeline;

  @override
  void initState() {
    super.initState();
    CleanSlatePromptStore.noteSessionStart();
    final s = AppServices.instance;
    _recording = s.recording;
    _pipeline = s.pipeline;
    _recording.durationSeconds.listen((s) {
      if (mounted) setState(() => _seconds = s);
    });
    _refreshMic();
    unawaited(_loadMicPermissionSimulatorHelper());
    unawaited(
      _loadJournalEntryCount().then((_) async {
        if (_journalEntryCount >= 2) {
          unawaited(_loadFirstThreeJourney());
          unawaited(_loadActivePatternThread());
          unawaited(_loadSignalArchive());
        }
        if (_journalEntryCount >= 3) {
          await _loadPersonalReturnPrompts();
        }
      }),
    );
    _loadRecordReturnProState();
    _loadFirstLoop();
    _loadReturnTriggerAccepted();
    unawaited(_loadPurchaseIntentCue());
    unawaited(_loadInvitedWelcome());
    // Persisted memory scope drives the "Memory for this entry" control
    // and every save below; refresh the UI once loaded.
    if (AppServices.isInitialized) {
      unawaited(
        MemoryScopeStore.instance().ensureLoaded().then((_) {
          if (mounted) setState(() {});
        }),
      );
    }
    // Invited funnel mirror: silent unless a first-touch invite
    // attribution exists. Once per session.
    InviteFunnelMetrics.appOpened();
    final seed = widget.initialPrompt?.trim();
    if (seed != null && seed.isNotEmpty) {
      _selectedPromptLine = seed;
    }
    if (ScreenshotMode.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applyScreenshotRecordPreview();
      });
    } else {
      unawaited(
        _loadReturnDayState().then((_) async {
          final payload = CheckInReminderService.consumeTapPayload();
          if (payload != null &&
              (payload.startsWith('next_evidence') ||
                  payload.contains('reminder'))) {
            await ReturnReasonCaptureCoordinator.markOpenedFromReminder();
          }
          // The day-2 gentle reminder was tapped to open the app.
          if (payload == DayTwoReminder.reminderId) {
            ActivationFunnelAnalytics.track(
              ActivationFunnelAnalytics.day2ReminderOpened,
              oncePerSession: true,
            );
          }
          await _applyAcquisitionIntentPrompt();
        }),
      );
      if (TrialMode.enabled) {
        unawaited(ActivationTracker.trackTrialAppOpened());
        _loadHookRescueDecision();
      }
    }
  }

  Future<void> _loadHookRescueDecision() async {
    try {
      final summary = await const TrialSummaryEngine().build();
      final decision = const HookRescueDecisionEngine().decide(summary);
      String? topReason;
      final reasons = summary.hookDiagnosis.notUsefulReasonCounts;
      if (reasons.isNotEmpty) {
        topReason = reasons.entries
            .reduce((a, b) => b.value > a.value ? b : a)
            .key;
      }
      if (mounted) {
        setState(() {
          _hookRescue = decision;
          _hookRescueNotUsefulReason = topReason;
        });
      }
    } catch (_) {
      // Diagnosis is optional; never block the record loop.
    }
  }

  Future<void> _usePatternMemoryNext(PatternMemory memory) async {
    final checkIn = await PatternMemoryCoordinator.useNextQuestion(memory);
    if (!mounted) return;
    if (checkIn != null) {
      setState(() => _patternMemory = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved for your next check-in.')),
      );
      await _promptRoutineAnchorForDate(checkIn.targetDate);
    }
  }

  Future<void> _usePatternNextAction(PatternNextAction action) async {
    final checkIn = await PatternMemoryCoordinator.useNextAction(action);
    if (!mounted) return;
    if (checkIn != null) {
      setState(() => _patternNextAction = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved for tomorrow\u2019s check.')),
      );
      await _promptRoutineAnchorForDate(checkIn.targetDate);
    }
  }

  Future<void> _keepHabitProofGoing(HabitProofMoment proof) async {
    final checkIn = await PatternMemoryCoordinator.useHabitProofNext(proof);
    if (!mounted) return;
    setState(() => _habitProof = null);
    if (checkIn != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved for tomorrow\u2019s check.')),
      );
    }
  }

  Future<void> _copyShareRecap(PatternShareRecap recap) async {
    await PatternShareService.copyToClipboard(recap);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Recap copied.')));
  }

  Future<void> _useWeeklyRecapNext(WeeklyPatternRecap recap) async {
    final checkIn = await PatternMemoryCoordinator.useWeeklyRecapNext(recap);
    if (!mounted) return;
    setState(() => _weeklyRecap = null);
    if (checkIn != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved for tomorrow\u2019s check.')),
      );
    }
  }

  @override
  void dispose() {
    if (TrialMode.enabled) {
      if (_ui == RecordUiState.recording) {
        unawaited(ActivationTracker.trackTrialRecordingCancelled());
      }
      if (_watchForAcceptPending) {
        unawaited(
          ActivationTracker.trackTrialClosedBeforeWatchForAcceptedIfPending(),
        );
      }
    }
    // Leaving with an answer chosen but no recorded moment is a return-day drop.
    unawaited(
      ReturnDayFrictionCoordinator.trackAbandonedAfterAnswerIfPending(),
    );
    super.dispose();
  }

  Future<void> _loadActivePatternThread() async {
    final thread = await ActivePatternThreadCoordinator.loadCurrentThread();
    if (!mounted) return;
    setState(() => _activePatternThread = thread);
  }

  Future<void> _loadSignalArchive() async {
    final snapshot = await SignalArchiveCoordinator.load();
    final journey = await SignalJourneyCoordinator.loadActive();
    SignalReview? review;
    if (journey != null && journey.supportingCount >= 3) {
      review = await SignalReviewCoordinator.loadForActiveJourney();
    }
    if (!mounted) return;
    setState(() {
      _signalArchiveSnapshot = snapshot;
      _signalJourney = journey;
      _signalReview = review;
    });
  }

  void _applyScreenshotRecordPreview() {
    if (ScreenshotMode.objectiveDueCheckPreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 3;
        _dueCheckInToday = ScreenshotSampleData.tomorrowCheckInDueSample;
        _activeCheckInForTomorrow = null;
        _showPostSaveLoop = false;
      });
      return;
    }
    if (ScreenshotMode.objectiveFirstMomentPreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 0;
        _dueCheckInToday = null;
        _activeCheckInForTomorrow = null;
        _showPostSaveLoop = false;
      });
      return;
    }
    if (ScreenshotMode.objectiveNextReadyPreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 3;
        _retentionNextCheckJustChosen = true;
        _activeCheckInForTomorrow =
            ScreenshotSampleData.tomorrowCheckInSetForTomorrowSample;
        _dueCheckInToday = null;
        _showPostSaveLoop = false;
      });
      return;
    }
    if (ScreenshotMode.compellingCheckPreview) {
      setState(() {
        _ui = RecordUiState.done;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 1;
        _showPostSaveLoop = true;
        _isFirstSessionPostSave = true;
        _firstSessionPattern = ScreenshotSampleData.firstSessionPatternSample;
        _dueCheckInToday = null;
        _activeCheckInForTomorrow = null;
      });
      return;
    }
    if (ScreenshotMode.realReminderPreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 3;
        _dueCheckInToday = null;
        _activeCheckInForTomorrow =
            ScreenshotSampleData.tomorrowCheckInSetForTomorrowSample;
        _showPostSaveLoop = false;
      });
      return;
    }
    if (ScreenshotMode.retentionCheckSetPreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 3;
        _dueCheckInToday = null;
        _activeCheckInForTomorrow =
            ScreenshotSampleData.tomorrowCheckInSetForTomorrowSample;
        _showPostSaveLoop = false;
      });
      return;
    }
    if (ScreenshotMode.retentionDueTodayPreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 3;
        _dueCheckInToday = ScreenshotSampleData.tomorrowCheckInDueSample;
        _showPostSaveLoop = false;
      });
      return;
    }
    if (ScreenshotMode.retentionLoopClosedPreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 3;
        _completedCheckInToday =
            ScreenshotSampleData.tomorrowCheckInCompletedSample;
        _dueCheckInToday = null;
        _activeCheckInForTomorrow = null;
        _showPostSaveLoop = false;
      });
      return;
    }
    if (ScreenshotMode.retentionNextReadyPreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 3;
        _retentionNextCheckJustChosen = true;
        _activeCheckInForTomorrow =
            ScreenshotSampleData.tomorrowCheckInSetForTomorrowSample;
        _dueCheckInToday = null;
        _showPostSaveLoop = false;
      });
      return;
    }
    if (ScreenshotMode.recordCleanFirstRunPreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 0;
        _dueCheckInToday = null;
        _showPostSaveLoop = false;
        _firstThreeJourney = null;
        _pendingWatchForToday = null;
        _activePatternThread = null;
      });
      return;
    }
    if (ScreenshotMode.recordCleanDueCheckPreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 3;
        _dueCheckInToday = ScreenshotSampleData.tomorrowCheckInDueSample;
        _pendingWatchForToday = null;
        _activePatternThread = null;
        _showPostSaveLoop = false;
      });
      return;
    }
    if (ScreenshotMode.recordCleanPostSavePreview) {
      setState(() {
        _ui = RecordUiState.done;
        _showPostSaveLoop = true;
        _returnDayJustClosed = false;
        _completedCheckInToday =
            ScreenshotSampleData.tomorrowCheckInCompletedSample;
        _patternMemory = ScreenshotSampleData.patternMemorySample;
        _patternProgress = ScreenshotSampleData.patternProgressSample;
        _pendingWatchForToday = null;
        _activePatternThread = null;
        _inputQualityResolved = true;
      });
      return;
    }
    if (ScreenshotMode.positioningRescuePreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 0;
        _dueCheckInToday = null;
        _showPostSaveLoop = false;
        _firstThreeJourney = null;
      });
      return;
    }
    if (ScreenshotMode.activationRescueFirstRecordPreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 0;
        _dueCheckInToday = null;
        _showPostSaveLoop = false;
        _firstThreeJourney = null;
      });
      return;
    }
    if (ScreenshotMode.activationRescueTomorrowCheckPreview) {
      setState(() {
        _ui = RecordUiState.done;
        _showPostSaveLoop = true;
        _isFirstSessionPostSave = true;
        _firstSessionPattern = ScreenshotSampleData.firstSessionPatternSample;
        _tomorrowReturnLoop = ScreenshotSampleData.tomorrowReturnLoop;
        _returnComparison = null;
        _returnStreak = null;
        _completedWatchForToday = null;
        _suggestedWatchForTomorrow = null;
        _pendingWatchForToday = null;
        _activePatternThread = null;
      });
      return;
    }
    if (ScreenshotMode.activationRescueUsefulResultPreview) {
      setState(() {
        _ui = RecordUiState.done;
        _showPostSaveLoop = true;
        _returnDayJustClosed = false;
        _completedCheckInToday =
            ScreenshotSampleData.tomorrowCheckInCompletedSample;
        _pendingWatchForToday = null;
        _activePatternThread = null;
      });
      return;
    }
    if (ScreenshotMode.activationRescueNextCheckPreview) {
      setState(() {
        _ui = RecordUiState.done;
        _showPostSaveLoop = true;
        _returnDayJustClosed = false;
        _completedCheckInToday =
            ScreenshotSampleData.tomorrowCheckInCompletedSample;
        _pendingWatchForToday = null;
        _activePatternThread = null;
      });
      return;
    }
    if (ScreenshotMode.quickHelpPreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 0;
        _showPostSaveLoop = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showQuickHelpSheet(
          context,
          languageCode: _languageCode,
          onStartRecording: () => _onRecordPressed(source: 'main'),
          initialIntent: QuickHelpIntent.whatToRecord,
        );
      });
      return;
    }
    final journeyCount = ScreenshotMode.screenshotJourneyReflectionCount;
    if (journeyCount >= 0) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = journeyCount;
        _firstThreeJourney = ScreenshotSampleData.firstThreeJourneyForCount(
          journeyCount,
        );
        _showPostSaveLoop = false;
        _pendingWatchForToday = journeyCount >= 2
            ? ScreenshotSampleData.watchForPendingForToday(DateTime.now())
            : null;
        _activePatternThread = journeyCount >= 1
            ? ScreenshotSampleData.activePatternThreadSample
            : null;
        _completedWatchForToday = null;
        _suggestedWatchForTomorrow = null;
      });
      return;
    }
    if (ScreenshotMode.recordFirstSessionPreview) {
      setState(() {
        _ui = RecordUiState.done;
        _showPostSaveLoop = true;
        _isFirstSessionPostSave = true;
        _firstSessionPattern = ScreenshotSampleData.firstSessionPatternSample;
        _tomorrowReturnLoop = ScreenshotSampleData.tomorrowReturnLoop;
        _returnComparison = null;
        _returnStreak = null;
        _completedWatchForToday = null;
        _suggestedWatchForTomorrow = null;
        _pendingWatchForToday = null;
        _activePatternThread = null;
      });
      return;
    }
    if (ScreenshotMode.completedCheckInPreview) {
      setState(() {
        _ui = RecordUiState.done;
        _showPostSaveLoop = true;
        _returnDayJustClosed = false;
        _completedCheckInToday =
            ScreenshotSampleData.tomorrowCheckInCompletedSample;
        if (ScreenshotMode.kindnessPreview) {
          _inputQualityText = ScreenshotSampleData.selfBlameReflection;
        }
        _pendingWatchForToday = null;
        _activePatternThread = null;
      });
      return;
    }
    if (ScreenshotMode.inputQualityCoachPreview) {
      setState(() {
        _ui = RecordUiState.done;
        _showPostSaveLoop = true;
        _isFirstSessionPostSave = true;
        _firstSessionPattern = ScreenshotSampleData.firstSessionPatternSample;
        _tomorrowReturnLoop = ScreenshotSampleData.tomorrowReturnLoop;
        _inputQuality = assessReflectionQuality('Today was stressful.');
        _inputQualityText = 'Today was stressful.';
        _inputQualityResolved = false;
        _completedWatchForToday = null;
        _suggestedWatchForTomorrow = null;
        _pendingWatchForToday = null;
        _activePatternThread = null;
      });
      return;
    }
    if (ScreenshotMode.recordPostSavePreview) {
      setState(() {
        _ui = RecordUiState.done;
        _showPostSaveLoop = true;
        _tomorrowReturnLoop = ScreenshotSampleData.tomorrowReturnLoop;
        _returnComparison = ScreenshotSampleData.returnComparisonSample;
        _returnStreak = ScreenshotSampleData.returnStreakSample;
        _completedWatchForToday = ScreenshotSampleData.watchForCompletedSample;
        _suggestedWatchForTomorrow =
            ScreenshotSampleData.watchForPendingForToday(
              DateTime.now().add(const Duration(days: 1)),
            );
        _pendingWatchForToday = null;
        _activePatternThread = ScreenshotSampleData.activePatternThreadSample;
      });
      return;
    }
    if (ScreenshotMode.recordCheckInDuePreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _dueCheckInToday = ScreenshotSampleData.tomorrowCheckInDueSample;
        _pendingWatchForToday = null;
        _activePatternThread = null;
        _showPostSaveLoop = false;
      });
      return;
    }
    setState(() {
      _ui = RecordUiState.ready;
      _mic = RecordingPhase.ready;
      _pendingWatchForToday = ScreenshotSampleData.watchForPendingForToday(
        DateTime.now(),
      );
      _activePatternThread = ScreenshotSampleData.activePatternThreadSample;
      _completedWatchForToday = null;
      _suggestedWatchForTomorrow = null;
      _showPostSaveLoop = false;
    });
  }

  Future<void> _loadReturnDayState() async {
    final due = await TomorrowCheckInCoordinator.loadDueToday();
    final missed = due == null
        ? await TomorrowCheckInCoordinator.loadMissedNeedingReason()
        : null;
    final recentMissed = due == null && missed == null
        ? await TomorrowCheckInCoordinator.loadRecentMissed()
        : null;
    final active = await TomorrowCheckInCoordinator.loadActive();
    final tomorrowKey = _tomorrowDateKey;
    TomorrowCheckIn? activeForTomorrow;
    if (active != null &&
        !active.isCompleted &&
        active.targetDate == tomorrowKey) {
      activeForTomorrow = active;
    }
    WatchForItem? pending;
    if (due == null) {
      pending = await WatchForCoordinator.loadPendingForToday();
    }
    if (due != null || pending != null) {
      await ActivationTracker.trackReturnedNextDayOnce();
    }
    RoutineAnchor? dueAnchor;
    if (due != null) {
      // Seeing yesterday's question is the first return-day step.
      await ReturnDayFrictionCoordinator.markDueShown(due.id);
      dueAnchor = await RoutineAnchorStore.instance().loadForDate(
        due.targetDate,
      );
    }
    ArchiveFeedbackType? feedbackHint;
    try {
      feedbackHint = await ArchiveFeedbackCoordinator.latestDominantIssue();
    } catch (_) {
      // Feedback is optional; never block the record loop.
    }
    if (!mounted) return;
    setState(() {
      _dueCheckInToday = due;
      _dueRoutineAnchor = dueAnchor;
      _missedCheckInForDiagnosis = missed;
      _recentMissedCheckIn = recentMissed;
      _activeCheckInForTomorrow = activeForTomorrow;
      _pendingWatchForToday = pending;
      _feedbackHint = feedbackHint;
    });
  }

  /// ISO date key for tomorrow, matching how check-ins set their targetDate.
  String get _tomorrowDateKey =>
      tomorrowCheckInDateKey(DateTime.now().add(const Duration(days: 1)));

  /// Shows the routine-anchor chooser and stores the chosen moment for the
  /// given target date so the due card can show "Planned for: …".
  Future<void> _promptRoutineAnchorForDate(String targetDate) async {
    if (!mounted) return;
    final anchor = await RoutineAnchorChooser.show(context);
    if (anchor == null) return;
    await RoutineAnchorStore.instance().saveForDate(targetDate, anchor);
  }

  Future<void> _loadJournalEntryCount() async {
    final all = await AppServices.instance.journal.loadAll();
    if (!mounted) return;
    setState(() {
      _journalEntryCount = all.length;
      _journalEntryCountLoaded = true;
      _journalEntries = all;
      _lastReflectionAt = all.isEmpty ? null : all.last.createdAt;
      _entryDates = all.map((e) => e.createdAt).toList();
      _firstArchiveMilestoneCompleted =
          ExamplePromptVisibility.hasCompletedFirstArchiveMilestone(all);
    });
    _logRecordEmptyGate('journal_loaded');
  }

  bool _returnTriggerAccepted = false;
  PersonalReturnPromptSet? _personalReturnPrompts;
  DailyReturnSuggestionSet _dailyReturnSuggestions =
      DailyReturnSuggestionSet.empty;
  OneSmallRecording _oneSmallRecording = OneSmallRecording.none();

  /// Suggestion-to-Pro funnel state. The pending source is set on tap and
  /// consumed on the next successful save — never blocks recording.
  PaywallSource? _pendingSuggestionSource;
  DailyReturnSuggestion? _pendingTappedSuggestion;
  bool _dailySuggestionsSeenTracked = false;
  PaywallSource? _suggestionProNudgeSource;

  /// Post-save "Saved to your archive" receipt for suggestion-sourced saves.
  StartHereSaveReceipt? _saveReceipt;

  /// Post-save "Done for today" closure receipt — every successful save.
  DoneForTodayReceipt? _doneForTodayReceipt;
  DayTwoReturnPreview? _dayTwoReturnPreview;

  /// One optional day-2 reminder offer — only after the very first save.
  bool _offerDayTwoReminder = false;

  /// Post-save archive proof counter — real evidence counts, never fabricated.
  ArchiveProofCounter? _archiveProofCounter;

  /// Post-save optional context tag prompt — only after a successful save.
  bool _showEvidenceContextTag = false;

  /// Post-save anonymous share card — counts only, never user text.
  ShareableArchiveProof? _shareableProof;

  /// Post-save Pro bridge — only after a real value moment, never blocking.
  ValueMomentBridge? _valueMomentBridge;

  /// Record → Return → Pro loop: true only while the very first save's
  /// post-save view is showing.
  bool _recordReturnProJustSaved = false;

  /// Loop persisted progress (return cue, Pro bridge, change-start seen).
  RecordReturnProState? _recordReturnProState;

  /// Pro users never see the commercial-loop Pro bridge.
  bool _recordReturnProIsPro = false;

  /// The post-save Pro nudge shows at most once per app session.
  static bool _suggestionProNudgeShownThisSession = false;

  @visibleForTesting
  static void resetSuggestionProNudgeSessionForTest() {
    _suggestionProNudgeShownThisSession = false;
  }

  SuggestionAttributionStore? get _suggestionAttribution =>
      widget.suggestionAttributionStore ??
      (AppServices.isInitialized
          ? SuggestionAttributionStore.instance()
          : null);

  void _onDailySuggestionTapped(
    DailyReturnSuggestion suggestion,
    bool isPrimary,
  ) {
    final source = isPrimary
        ? PaywallSource.startHereToday
        : PaywallSource.dailySuggestion;
    _pendingSuggestionSource = source;
    _pendingTappedSuggestion = suggestion;
    final store = _suggestionAttribution;
    if (store == null) return;
    unawaited(
      store.record(
        SuggestionAttributionEventType.tappedFor(source),
        suggestionId: suggestion.id,
      ),
    );
  }

  /// Records the saved-from-suggestion event and shows the "Saved to your
  /// archive" receipt for suggestion-sourced saves. Runs only after the save
  /// fully succeeded — generic prompt saves never reach the receipt.
  Future<void> _handleSuggestionAttributionAfterSave(int entryCount) async {
    final source = _pendingSuggestionSource;
    final tapped = _pendingTappedSuggestion;
    if (source == null) return;
    _pendingSuggestionSource = null;
    _pendingTappedSuggestion = null;

    final store = _suggestionAttribution;
    if (store != null) {
      unawaited(store.record(SuggestionAttributionEventType.savedFor(source)));
    }

    final receipt = const StartHereSaveReceiptEngine().build(
      source: source,
      suggestion: tapped,
    );
    if (receipt != null) {
      if (!mounted) return;
      setState(() => _saveReceipt = receipt);
      return;
    }

    // Fallback when no tapped suggestion was retained: the gentle Pro nudge.
    final reader =
        widget.entitlementReader ?? ArchiveEntitlementReader.forAccessCheck();
    final isPro = await reader.isPro;
    if (!SuggestionProTrigger.shouldShow(
      isPro: isPro,
      entryCount: entryCount,
      alreadyShownThisSession: _suggestionProNudgeShownThisSession,
    )) {
      return;
    }
    _suggestionProNudgeShownThisSession = true;
    if (!mounted) return;
    setState(() => _suggestionProNudgeSource = source);
  }

  Future<void> _loadReturnTriggerAccepted() async {
    if (!AppServices.isInitialized) return;
    final accepted = await PressureReturnTriggerStore.instance().accepted;
    if (!mounted) return;
    setState(() => _returnTriggerAccepted = accepted);
  }

  /// Builds "Try saying one of these" and "Worth checking today" from the
  /// user's own pressure entries when there is evidence; otherwise the
  /// section keeps generic prompts and no suggestion card is shown.
  Future<void> _loadPersonalReturnPrompts() async {
    if (!_journalEntryCountReady || _journalEntryCount < 3) return;
    if (widget.pressureCheckInStore == null && !AppServices.isInitialized) {
      return;
    }
    final store =
        widget.pressureCheckInStore ?? PressureCheckInStore.instance();
    final records = await store.loadAll();
    final savedEntryCount = _journalEntryCount;
    if (!mounted) return;
    setState(() {
      _personalReturnPrompts = const PersonalReturnPromptEngine().build(
        records,
      );
      _dailyReturnSuggestions = const DailyReturnSuggestionEngine().build(
        records,
      );
      _oneSmallRecording = const OneSmallRecordingEngine().build(
        records,
        entryCount: savedEntryCount,
      );
      // Day 7 continuity inputs — both from existing engines, never new
      // claims. The loop itself is built at render time with the current
      // entry count.
      _hasWeeklyReviewForContinuity = const WeeklyThreadReviewEngine()
          .build(records)
          .hasReview;
      _hasConnectedThreadForContinuity = const ThreadReturnEvidenceEngine()
          .build(records)
          .hasEvidence;
    });
    await AhaMomentStore.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _ahaCandidate = const AhaMomentEngine().evaluate(
        records: records,
        entryCount: savedEntryCount,
        hasStrongerMemoryCardVisible: false,
        source: 'record',
        trackAnalytics: false,
      );
    });
    if (_dailyReturnSuggestions.hasSuggestions &&
        !_dailySuggestionsSeenTracked) {
      _dailySuggestionsSeenTracked = true;
      final store = _suggestionAttribution;
      if (store != null) {
        unawaited(
          store.record(SuggestionAttributionEventType.dailySuggestionsSeen),
        );
      }
    }
  }

  /// Return cue is on screen — first save only, until answered once.
  bool get _recordReturnCueVisible =>
      _recordReturnProJustSaved &&
      _recordReturnProState != null &&
      !_recordReturnProState!.returnCueResolved;

  Future<void> _loadRecordReturnProState() async {
    if (!AppServices.isInitialized) return;
    final state = await RecordReturnProStore.instance().load();
    final isPro =
        await (widget.entitlementReader ??
                ArchiveEntitlementReader.forAccessCheck())
            .isPro;
    if (!mounted) return;
    setState(() {
      _recordReturnProState = state;
      _recordReturnProIsPro = isPro;
    });
  }

  bool get _hasRealChangeInsight => RecordReturnProGates.hasRealChangeInsight(
    hasReturnComparison: _returnComparison != null,
    hasTomorrowReturnLoopContent: _tomorrowReturnLoop?.hasContent ?? false,
    hasThreadReturnEvidence: _hasConnectedThreadForContinuity,
  );

  /// "Remind me tomorrow" — permission only after this explicit tap.
  Future<void> _acceptRecordReturnReminder() async {
    final outcome = await DayTwoReminderCoordinator().accept();
    await RecordReturnProStore.instance().markReturnCueResolved(
      RecordReturnProReturnCueMethod.reminder,
    );
    if (!mounted) return;
    setState(() {
      _recordReturnProState = _recordReturnProState?.copyWith(
        returnCueResolved: true,
        returnCueMethod: RecordReturnProReturnCueMethod.reminder,
      );
      _offerDayTwoReminder = false;
    });
    final line = outcome == DayTwoReminderOutcome.scheduled
        ? DayTwoReminder.scheduledLine
        : DayTwoReminder.unavailableLine;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(line)));
  }

  /// Local return cue only — no notifications.
  Future<void> _acceptRecordReturnLocalCue() async {
    await RecordReturnProStore.instance().markReturnCueResolved(
      RecordReturnProReturnCueMethod.localCue,
    );
    if (!mounted) return;
    setState(() {
      _recordReturnProState = _recordReturnProState?.copyWith(
        returnCueResolved: true,
        returnCueMethod: RecordReturnProReturnCueMethod.localCue,
      );
    });
  }

  Future<void> _markChangeStartSeen() async {
    await RecordReturnProStore.instance().markChangeStartSeen();
    if (!mounted) return;
    setState(() {
      _recordReturnProState = _recordReturnProState?.copyWith(
        changeStartSeen: true,
      );
    });
  }

  /// Resolves the commercial-loop Pro bridge once.
  Future<void> _resolveRecordReturnProBridge({required bool seePro}) async {
    await RecordReturnProStore.instance().markProBridgeResolved();
    if (!mounted) return;
    setState(() {
      _recordReturnProState = _recordReturnProState?.copyWith(
        proBridgeResolved: true,
      );
    });
    if (seePro) {
      context.push(
        '/subscription',
        extra: PaywallRouteArgs(
          source: PaywallSource.valueMoment,
          sourceRoute: '/record',
        ),
      );
    }
  }

  /// Builds the "Done for today" closure receipt — only ever called after a
  /// save succeeded, so a failed save can never surface it.
  Future<void> _buildDoneForTodayReceipt() async {
    List<PressureCheckInRecord> records = const [];
    if (widget.pressureCheckInStore != null || AppServices.isInitialized) {
      final store =
          widget.pressureCheckInStore ?? PressureCheckInStore.instance();
      records = await store.loadAll();
    }
    final reader =
        widget.entitlementReader ?? ArchiveEntitlementReader.forAccessCheck();
    final isPro = await reader.isPro;
    // Day 2 gentle reminder: offered once, only right after the very first
    // successful save — value exists before anything is asked.
    final offerDayTwoReminder = await DayTwoReminderCoordinator().shouldOffer(
      entryCount: _journalEntryCount,
    );
    // First 60 Seconds: load the persisted return-cue / Pro-bridge answers
    // so neither card ever re-asks after being resolved.
    final recordReturnProState = await RecordReturnProStore.instance().load();
    if (!mounted) return;
    setState(() {
      _offerDayTwoReminder = offerDayTwoReminder;
      _recordReturnProState = recordReturnProState;
      _recordReturnProIsPro = isPro;
      _doneForTodayReceipt = const DoneForTodayReceiptEngine().build(
        saved: true,
        entryCount: _journalEntryCount,
        records: records,
      );
      // Same evidence, one more honest count: the save that just happened.
      _archiveProofCounter = const ArchiveProofCounterEngine().build(
        records,
        savedToday: true,
      );
      // Anonymous share card built from the same counts — never user text.
      _shareableProof = const ShareableArchiveProofEngine().build(
        records,
        savedToday: true,
        entryCount: _journalEntryCount,
      );
      // Pro bridge only after a real value moment — and the save is already
      // done, so it can never block recording or saving.
      _valueMomentBridge = const ValueMomentPaywallTrigger().build(
        records,
        isPro: isPro,
      );
      // Optional, skippable context tag — only reachable after a real save.
      _showEvidenceContextTag = _entriesAfterSave.isNotEmpty;
      // Tomorrow's-check preview — safe labels only, never user text.
      _dayTwoReturnPreview = const DayTwoReturnPreviewEngine().build(
        entryCount: _journalEntryCount,
        contextTagIds: [for (final r in records) ...r.contextIds],
        entryDates: [for (final r in records) r.createdAt],
      );
    });
  }

  /// Persists a one-tap low-effort check-in as a real lightweight evidence
  /// record. The card only confirms "Saved" after this completes.
  Future<void> _saveLowEffortCheckIn(LowEffortCheckInOption option) async {
    if (widget.pressureCheckInStore == null && !AppServices.isInitialized) {
      return;
    }
    final store =
        widget.pressureCheckInStore ?? PressureCheckInStore.instance();
    final existing = await store.loadAll();
    await store.save(
      const LowEffortCheckInEngine().buildRecord(option, existing),
    );
  }

  /// Stores the single optional context tag against the entry that was just
  /// saved, then retires the prompt. Skipping never stores anything.
  Future<void> _saveEvidenceContextTag(PressureContext tag) async {
    setState(() => _showEvidenceContextTag = false);
    if (_entriesAfterSave.isEmpty) return;
    if (widget.pressureCheckInStore == null && !AppServices.isInitialized) {
      return;
    }
    final store =
        widget.pressureCheckInStore ?? PressureCheckInStore.instance();
    await store.addContextTag(
      entryId: _lastSavedEntry!.id,
      contextId: tag.id,
      // A fresh-entry save keeps its optional tag out of connection claims.
      treatAsNew: TreatAsNew.lastSaveWasFresh,
    );
    // The just-saved tag can make tomorrow's-check preview more specific.
    final records = await store.loadAll();
    if (!mounted) return;
    setState(() {
      _dayTwoReturnPreview = const DayTwoReturnPreviewEngine().build(
        entryCount: _journalEntryCount,
        contextTagIds: [for (final r in records) ...r.contextIds],
        entryDates: [for (final r in records) r.createdAt],
      );
    });
  }

  Future<void> _loadFirstThreeJourney() async {
    if (!_journalEntryCountReady || _journalEntryCount < 2) return;
    final model = await FirstThreeJourneyCoordinator.load();
    if (!mounted) return;
    setState(() => _firstThreeJourney = model);
  }

  /// Purchase Intent Return Cue: a previous purchase start without a
  /// completion, surfaced calmly on a later visit. Loaded once at init —
  /// the session that started the purchase never shows it.
  Future<void> _loadPurchaseIntentCue() async {
    if (widget.purchaseIntentStore == null && !AppServices.isInitialized) {
      return;
    }
    final store = widget.purchaseIntentStore ?? PurchaseIntentStore();
    final intent = await store.pendingIntent();
    if (intent == null) return;
    final reader =
        widget.entitlementReader ?? ArchiveEntitlementReader.forAccessCheck();
    final isPro = await reader.isPro;
    if (!mounted) return;
    if (!PurchaseIntentReturnCue.shouldShow(
      isPro: isPro,
      hasPendingIntent: true,
    )) {
      return;
    }
    PurchaseIntentReturnCue.shownThisSession = true;
    setState(() => _purchaseIntentCue = intent);
  }

  /// Invited User Welcome: a locally persisted first-touch invite
  /// attribution tailors the pre-first-save welcome. Loaded once at init;
  /// the render gate also requires a still-empty archive.
  Future<void> _loadInvitedWelcome() async {
    if (widget.inviteAttributionStore == null && !AppServices.isInitialized) {
      return;
    }
    final store = widget.inviteAttributionStore ?? InviteAttributionStore();
    final attribution = await store.firstTouch();
    if (attribution == null || !mounted) return;
    // Any invited surface (welcome, Day 2 return copy) can use the source.
    setState(() => _inviteSource = attribution.source);
    if (!InvitedUserWelcome.shouldShow(entryCount: _journalEntryCount)) return;
    InvitedUserWelcome.shownThisSession = true;
    InvitedUserWelcome.sessionSource = attribution.source;
    setState(() => _invitedWelcomeSource = attribution.source);
  }

  Future<void> _loadFirstLoop() async {
    // Opening the Record tab is the first step of the compressed loop.
    final state = ScreenshotMode.enabled
        ? await FirstLoopActivationCoordinator.load()
        : await FirstLoopActivationCoordinator.markOpenedRecord();
    if (!mounted) return;
    setState(() => _firstLoop = state);
  }

  bool get _showAdvancedRetentionPostSave {
    if (_isFirstSessionPostSave) return false;
    final count = _entriesAfterSave.isNotEmpty
        ? _entriesAfterSave.length
        : _journalEntryCount;
    return count >= 3;
  }

  void _onStartHereSelected(String prompt) {
    setState(() => _selectedPromptLine = prompt);
    if (_ui == RecordUiState.ready && _mic == RecordingPhase.ready) {
      unawaited(_onRecordPressed(source: 'moment'));
    }
  }

  ArchivePromptSet _promptSet() {
    final hasBelief = _journalEntryCount >= 5;
    final movement = _archiveMovement;
    return buildArchivePrompts(
      hasBelief: hasBelief,
      strengthening:
          movement?.kind == ArchiveMovementKind.confidenceChanged &&
          (movement?.headline.toLowerCase().contains('stronger') ?? false),
      weakening: movement?.headline.toLowerCase().contains('weaken') ?? false,
      hasRecentChange: movement != null,
      hasOpenQuestion: hasBelief && _journalEntryCount < 8,
      missingAreaLabel: movement?.kind == ArchiveMovementKind.newLifeArea
          ? 'that area'
          : null,
      beliefSnippet: movement?.headline,
    );
  }

  RecordUiState _uiForMicPhase(RecordingPhase cap) {
    return RecordMicrophonePermissionUi.uiForMicPhase(
      phase: cap,
      userDeniedThisSession: _micPermissionUserDenied,
    );
  }

  Future<void> _loadMicPermissionSimulatorHelper() async {
    final showHelper = await MicrophonePermissionEnvironment.isIosSimulator();
    if (!mounted) return;
    if (_showMicPermissionSimulatorHelper != showHelper) {
      setState(() => _showMicPermissionSimulatorHelper = showHelper);
    }
  }

  Future<void> _openMicSettings() async {
    _ignoreStaleMicRefreshAfterGrant = false;
    await openMicrophoneSettings();
    await _refreshMic();
  }

  Future<void> _typeInsteadFromPermission() async {
    await navigateToTypeInsteadCapture(
      context,
      prompt: _selectedPromptLine,
      onSaved: _finishSuccessfulCapture,
    );
  }

  Future<void> _openTypedFallbackForLastVoiceEntry() async {
    if (_entriesAfterSave.isEmpty) return;
    final entryId = _lastSavedEntry!.id;
    final result = await context.push<CapturePipelineResult>(
      '/quick-capture',
      extra: {'entryId': entryId},
    );
    if (result == null || !mounted) return;
    await _finishSuccessfulCapture(result);
  }

  JournalEntry? get _lastSavedEntry =>
      _entriesAfterSave.isNotEmpty ? _entriesAfterSave.first : null;

  bool get _lastSavedEntryIsDegraded =>
      _auditDegradedVoicePostSave ||
      VoiceCapturePostSave.showTypedFallbackPrimary(_lastSavedEntry);

  bool get _auditDegradedVoicePostSave {
    if (!VisualAuditOverrides.active) return false;
    return VisualAuditOverrides.peekRecordPresentation()?.degradedVoicePostSave ==
        true;
  }

  RecordCtaPolicyResolution _recordCtaPolicy(
    RecordUiState ui, {
    RecordingPhase? micPhase,
    MicrophonePermissionState? micPermissionState,
    bool? userDeniedThisSession,
  }) {
    final phase = micPhase ?? _mic;
    final permission = micPermissionState ?? _micPermissionState;
    // Recorder access (e.g. iOS simulator mismatch) wins over a stale denied phase.
    final effectiveMicPhase =
        permission == MicrophonePermissionState.granted ||
            permission ==
                MicrophonePermissionState.grantedWithPermissionHandlerMismatch
        ? RecordingPhase.ready
        : phase;
    final userDenied = userDeniedThisSession ?? _micPermissionUserDenied;
    return RecordCtaPolicy.resolve(
      ui: ui,
      entryCount: _journalEntryCount,
      entryCountLoaded: _journalEntryCountLoaded,
      showPostSaveLoop: _showPostSaveLoop,
      isDegradedVoiceSave: _lastSavedEntryIsDegraded,
      lastSavedEntry: _lastSavedEntry,
      micPhase: effectiveMicPhase,
      micPermissionState: permission,
      userDeniedThisSession: userDenied,
      sessionRequiresOpenSettings: _micSessionRequiresOpenSettings,
    );
  }

  String? _lastCtaPolicyLogLine;

  void _maybeLogRecordCtaPolicy(RecordCtaPolicyResolution resolution) {
    if (!kDebugMode) return;
    final secondary = resolution.secondaryLabels.isEmpty
        ? 'none'
        : resolution.secondaryLabels.join(',');
    final action = resolution.action?.logLabel ?? 'none';
    final line =
        'state=${resolution.state.logLabel} '
        'mic=${resolution.micPermissionState.name} '
        'primary=${resolution.primaryLabel ?? 'none'} '
        'action=$action '
        'secondary=$secondary';
    if (_lastCtaPolicyLogLine == line) return;
    _lastCtaPolicyLogLine = line;
    RecordCtaPolicy.log(resolution);
  }

  void _logMicRefreshApply(RecordMicRefreshApplyResult applied) {
    if (applied.initialDeniedCanAskAgain) {
      _recordPermissionUiLog(
        'initial deniedCanAskAgain treated_as=requestable',
      );
    }
    if (applied.userDeniedBlocked) {
      _recordPermissionUiLog('user_denied=true show_blocked=true');
    }
    if (applied.permanentDenied) {
      _recordPermissionUiLog('permanent_denied=true show_open_settings=true');
    }
  }

  Future<void> _refreshMic({bool fromUserRequest = false}) async {
    final resolution = await _recording.evaluateMicrophonePermission();
    final cap = resolution.phase;
    if (!mounted) return;

    if (MicrophonePermissionResolver.isRecordable(resolution.state)) {
      setState(() {
        _mic = RecordingPhase.ready;
        _micPermissionState = resolution.state;
        _micPermissionUserDenied = false;
        _micSessionRequiresOpenSettings = false;
        _ui = RecordUiState.ready;
        if (resolution.state == MicrophonePermissionState.granted) {
          _ignoreStaleMicRefreshAfterGrant = true;
        }
      });
      _recordLog('state ui=$_ui mic=$cap recordable=${resolution.state.name} (refresh)');
      _maybeAutostartWithPrompt();
      return;
    }

    final applied = RecordMicrophonePermissionUi.applyMicRefresh(
      phase: cap,
      userDeniedThisSession: _micPermissionUserDenied,
      currentUi: _ui,
      ignoreAfterGrant: _ignoreStaleMicRefreshAfterGrant,
      fromUserRequest: fromUserRequest,
      sessionRequiresOpenSettings: _micSessionRequiresOpenSettings,
    );
    if (applied.ignored) {
      _recordPermissionUiLog('stale refresh ignored after granted=true');
      return;
    }
    _logMicRefreshApply(applied);
    setState(() {
      _mic = applied.mic!;
      _micPermissionState = resolution.state;
      _micPermissionUserDenied = applied.userDenied!;
      _micSessionRequiresOpenSettings = applied.sessionRequiresOpenSettings;
      _ui = applied.ui!;
    });
    _recordLog('state ui=$_ui mic=$cap (refresh)');
    _maybeAutostartWithPrompt();
  }

  void _maybeAutostartWithPrompt() {
    if (_autostartWithPromptAttempted) return;
    if (!widget.autostartWithPrompt) return;
    if (_selectedPromptLine == null || _selectedPromptLine!.isEmpty) return;
    if (_ui != RecordUiState.ready || _mic != RecordingPhase.ready) return;
    _autostartWithPromptAttempted = true;
    unawaited(_onRecordPressed(source: 'main'));
  }

  bool _shouldHideCompetingRecordCtas(RecordUiState ui) =>
      RecordMicrophonePermissionUi.shouldHideCompetingRecordCtas(
        ui: ui,
        micPhase: _mic,
        userDeniedThisSession: _micPermissionUserDenied,
      );

  bool _shouldHideCardRecordButtons(RecordUiState ui) {
    if (_shouldHideCompetingRecordCtas(ui)) return true;
    return RecordCtaPolicy.shouldHideCardRecordCtas(_recordCtaPolicy(ui));
  }

  bool _shouldPromoteMicCaptureActions(RecordCtaPolicyResolution policy) {
    return policy.showMainBottomCta &&
        policy.action != null &&
        policy.action != RecordCtaAction.startRecording;
  }

  Widget _buildCaptureEntryActions({
    required BuildContext context,
    required String? selectedPrompt,
    required RecordCtaPolicyResolution policy,
  }) {
    return CaptureEntryActions(
      onRecord: () => unawaited(_onRecordPressed(source: 'main')),
      recordButtonKey: const Key('capture_entry_record_cta'),
      typeCapturePrompt: selectedPrompt,
      onTextThoughtSaved: _finishSuccessfulCapture,
      onLogPressureMoment: () => context.push('/pressure-check-in'),
      recordButtonLabel: policy.primaryLabel,
      underRecordHelper: null,
    );
  }

  void _trackRecordCtaPressed() {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.recordCtaTapped,
      entryCount: _journalEntryCount,
    );
    InviteFunnelMetrics.recordCtaTapped(entryCount: _journalEntryCount);
    if (_journalEntryCount == 0 && _dueCheckInToday == null) {
      ActivationTracker.trackActivationFirstRecordCtaTapped();
    }
    _recordLog('button pressed');
  }

  RecordCtaPolicyResolution _recordCtaPolicyForSession() {
    if (VisualAuditOverrides.active) {
      final audit = VisualAuditOverrides.peekRecordPresentation();
      if (audit != null) {
        return _recordCtaPolicy(
          audit.ui,
          micPhase: audit.micPhase ?? _mic,
          userDeniedThisSession:
              audit.userDeniedThisSession ?? _micPermissionUserDenied,
        );
      }
    }
    return _recordCtaPolicy(_ui);
  }

  Future<void> _onRecordPressed({required String source}) async {
    _recordCtaLog('tapped source=$source');
    final policy = _recordCtaPolicyForSession();
    final action =
        policy.action ??
        RecordMicrophonePermissionUi.recordCtaAction(
          micPhase: _mic,
          userDeniedThisSession: _micPermissionUserDenied,
        );
    switch (action) {
      case RecordCtaAction.startRecording:
        _recordCtaLog('start_recording=true');
        _trackRecordCtaPressed();
        setState(() {
          _error = null;
          _localSaveTitle = null;
          _syncNote = null;
          _seconds = 0;
          _showPostSaveLoop = false;
          _postSaveFollowUp = null;
          EntryAboutnessSession.clearSaveReceipt();
          MemorySurfacingSession.clearSaveReceipts();
          PreserveOriginalSession.clearSaveReceipt();
        });
        await _beginRecording();
      case RecordCtaAction.requestPermission:
        _trackRecordCtaPressed();
        await _requestPermissionAndRecord();
      case RecordCtaAction.openSettings:
        _recordCtaLog('open_settings=true');
        await _openMicSettings();
      case RecordCtaAction.routeToBlockedPanel:
        final stateLabel = RecordMicrophonePermissionUi.micBlockedStateLabel(
          micPhase: _mic,
          userDeniedThisSession: _micPermissionUserDenied,
        );
        _recordCtaLog('blocked_by_permission state=$stateLabel');
        if (policy.micPermissionState ==
                MicrophonePermissionState.deniedOpenSettings ||
            _mic == RecordingPhase.permissionPermanentlyDenied ||
            _micSessionRequiresOpenSettings ||
            _micPermissionUserDenied) {
          await _openMicSettings();
        } else {
          await _routeToPermissionPanel();
        }
    }
  }

  Future<void> _routeToPermissionPanel() async {
    if (_ui != RecordUiState.permissionBlocked) {
      setState(() {
        _ignoreStaleMicRefreshAfterGrant = false;
        _ui = RecordUiState.permissionBlocked;
        if (_mic == RecordingPhase.permissionPermanentlyDenied) {
          _micPermissionUserDenied = true;
        }
        _error = null;
      });
    }
    _recordCtaLog('routed_to_permission_panel=true');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final panelContext = _permissionPanelKey.currentContext;
      if (panelContext != null) {
        Scrollable.ensureVisible(
          panelContext,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.1,
        );
      }
    });
  }

  Future<void> _requestMic() async {
    _recordLog('button pressed (allow microphone)');
    final existing = await _recording.evaluateMicrophonePermission();
    if (existing.isRecordable) {
      if (!mounted) return;
      setState(() {
        _mic = RecordingPhase.ready;
        _micPermissionState = existing.state;
        _micPermissionUserDenied = false;
        _micSessionRequiresOpenSettings = false;
        _ui = RecordUiState.ready;
      });
      _recordPermissionUiLog(
        'recorder_verified=${existing.state.name} start_recording=true',
      );
      await _beginRecording();
      return;
    }
    if (TrialMode.enabled) {
      await ActivationTracker.trackTrialMicPermissionRequested();
    }
    _recordPermissionUiLog('request started');
    setState(() => _ui = RecordUiState.requestingPermission);
    await _recording.requestMicrophone();
    if (!mounted) return;
    await _refreshMic(fromUserRequest: true);
    if (!mounted) return;
    if (_mic == RecordingPhase.ready) {
      _recordPermissionUiLog('request result=granted start_recording=true');
      await _beginRecording();
      return;
    }
    if (TrialMode.enabled) {
      await ActivationTracker.trackTrialMicPermissionDenied();
    }
    if (_mic == RecordingPhase.permissionPermanentlyDenied) {
      _recordPermissionUiLog('permanent_denied=true show_open_settings=true');
    } else {
      _recordPermissionUiLog('user_denied=true show_blocked=true');
    }
    _recordPermissionUiLog('request result=denied show_blocked=true');
    if (_ui != RecordUiState.permissionBlocked) {
      setState(() {
        _ui = RecordUiState.permissionBlocked;
        _micSessionRequiresOpenSettings = true;
      });
    } else {
      setState(() => _micSessionRequiresOpenSettings = true);
    }
    await _routeToPermissionPanel();
  }

  Future<void> _requestPermissionAndRecord() async {
    setState(() {
      _error = null;
      _localSaveTitle = null;
      _syncNote = null;
      _seconds = 0;
      _showPostSaveLoop = false;
      _postSaveFollowUp = null;
      EntryAboutnessSession.clearSaveReceipt();
      MemorySurfacingSession.clearSaveReceipts();
      PreserveOriginalSession.clearSaveReceipt();
      _ui = RecordUiState.requestingPermission;
    });
    _recordPermissionUiLog('request started');

    if (TrialMode.enabled) {
      await ActivationTracker.trackTrialMicPermissionRequested();
    }
    var cap = await _recording.checkMicrophone();
    _recordLog('permission result $cap');
    if (cap != RecordingPhase.ready) {
      final resolution = await _recording.evaluateMicrophonePermission();
      if (resolution.isRecordable) {
        cap = RecordingPhase.ready;
        if (!mounted) return;
        setState(() {
          _mic = RecordingPhase.ready;
          _micPermissionState = resolution.state;
          _micPermissionUserDenied = false;
          _micSessionRequiresOpenSettings = false;
          _ui = RecordUiState.ready;
        });
      } else if (!await MicrophonePermissionEnvironment.shouldSkipPermissionRequest(
        status: resolution.permissionHandlerStatus ?? PermissionStatus.denied,
        hasRecorder: resolution.hasRecorder,
      )) {
        await _recording.requestMicrophone();
        _recordLog('permission result after request');
      } else {
        cap = await _recording.checkMicrophone();
        _recordLog('permission result after skip-request $cap');
      }
    }
    if (!mounted) return;
    await _refreshMic(fromUserRequest: true);
    if (!mounted) return;
    if (_mic == RecordingPhase.ready) {
      _recordCtaLog('start_recording=true');
      _recordPermissionUiLog('request result=granted start_recording=true');
      await _beginRecording();
      return;
    }
    if (TrialMode.enabled) {
      await ActivationTracker.trackTrialMicPermissionDenied();
    }
    if (_mic == RecordingPhase.permissionPermanentlyDenied) {
      _recordPermissionUiLog('permanent_denied=true show_open_settings=true');
    } else {
      _recordPermissionUiLog('user_denied=true show_blocked=true');
    }
    _recordPermissionUiLog('request result=denied show_blocked=true');
    _recordLog('start failed — permission not granted');
    RecordPipelineLog.microphonePermissionBlocked(blocked: true);
    if (_ui != RecordUiState.permissionBlocked) {
      setState(() {
        _ui = RecordUiState.permissionBlocked;
        _micSessionRequiresOpenSettings = true;
      });
    } else {
      setState(() => _micSessionRequiresOpenSettings = true);
    }
    await _routeToPermissionPanel();
  }

  Future<void> _beginRecording() async {
    _recordLog('start requested');
    try {
      await _recording.startRecording(permissionVerified: true);
      if (!mounted) return;
      setState(() {
        _ui = RecordUiState.recording;
        _stageLabel = 'Recording…';
        _mic = RecordingPhase.ready;
      });
      if (TrialMode.enabled) {
        await ActivationTracker.trackTrialRecordingStarted();
      }
      unawaited(FirstLoopActivationCoordinator.markRecordingStarted());
      if (_dueCheckInToday != null) {
        unawaited(
          ReturnDayFrictionCoordinator.markRecordingStarted(
            _dueCheckInToday!.id,
          ),
        );
      }
      _recordLog('start success');
      _recordLog('state ui=$_ui (recording)');
    } on RecordingException catch (e) {
      _ignoreStaleMicRefreshAfterGrant = false;
      _recordLog('start failed ${e.message}');
      if (!mounted) return;
      setState(() {
        _ui = RecordUiState.error;
        _error = e.message;
      });
    } catch (e, st) {
      _ignoreStaleMicRefreshAfterGrant = false;
      _recordLog('start failed $e');
      if (kDebugMode) {
        debugPrint('$st');
      }
      if (!mounted) return;
      setState(() {
        _ui = RecordUiState.error;
        _error =
            'Could not start recording. Check microphone permission and try again.';
      });
    }
  }

  Future<void> _stopAndProcess() async {
    if (TrialMode.enabled) {
      await ActivationTracker.trackTrialSaveStarted();
    }
    setState(() {
      _ui = RecordUiState.processing;
      _stageLabel = 'Stopping…';
    });
    try {
      final result = await _recording.stopRecording();
      _lastCaptureLikelySilentInput = result.likelySilentInput;
      setState(() => _stageLabel = 'Attesting device…');
      final pipelineResult = await _pipeline.run(
        audioFile: result.file,
        durationSeconds: result.durationSeconds,
        onStage: (stage) {
          if (!mounted) return;
          setState(() {
            _pipelineStage = stage;
            _stageLabel = switch (stage) {
              PipelineStage.attesting => 'Uploading audio…',
              PipelineStage.transcribing => 'Transcribing…',
              PipelineStage.analyzing => 'Finding patterns…',
              PipelineStage.saving => 'Saving…',
              PipelineStage.done => 'Done',
            };
          });
        },
      );
      if (!mounted) return;
      await _finishSuccessfulCapture(pipelineResult);
    } on CapturePipelineFailure catch (e) {
      if (e.message == VoiceCaptureCopy.notEnoughAudio) {
        setState(() {
          _ui = RecordUiState.ready;
          _error = e.message;
          _localSaveTitle = null;
          _syncNote = null;
          _stageLabel = '';
        });
        return;
      }
      setState(() {
        _ui = RecordUiState.error;
        _error = e.message;
        _localSaveTitle = null;
        _syncNote = null;
      });
    } on RecordingException catch (e) {
      setState(() {
        _ui = RecordUiState.error;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _ui = RecordUiState.error;
        _error = 'Something went wrong while saving. Try again.';
        _localSaveTitle = null;
        _syncNote = null;
      });
    }
  }

  Future<void> _finishSuccessfulCapture(
    CapturePipelineResult pipelineResult,
  ) async {
    final all = await AppServices.instance.journal.loadAll();
    final movement = ArchiveMovementEngine.build(
      all,
      newEntryId: pipelineResult.entry.id,
    );
    final cloudOk = pipelineResult.syncSucceeded;
    final savedEntry = pipelineResult.entry;
    final hasSavedTranscript =
        VoiceCaptureQuality.hasUsableSpokenText(savedEntry);
    final state = buildArchiveStateObjectV3(entries: all);
    final priorEntries = all.length > 1
        ? all.sublist(1)
        : const <JournalEntry>[];
    final instantResponse = const InstantReflectionResponseEngine().respond(
      entry: pipelineResult.entry,
      priorEntries: priorEntries,
    );

    final prefs = AppServices.instance.prefs;
    final discoveryFuture = const DailyDiscoveryEngine()
        .detectImmediateDiscovery(
          store: DailyDiscoveryStore(prefs),
          entries: all,
          state: state,
        );
    final evolutionFuture = const ArchiveEvolutionCoordinator()
        .detectAfterRecording(entries: all, state: state);
    final completedCheckIn = await TomorrowCheckInCoordinator.completeAfterSave(
      entries: all,
    );
    final patternMemory = completedCheckIn != null
        ? await PatternMemoryCoordinator.loadActive()
        : null;
    final patternProgress = completedCheckIn != null
        ? await PatternMemoryCoordinator.loadLatestProgress()
        : null;
    final patternNextAction = completedCheckIn != null
        ? await PatternMemoryCoordinator.loadLatestNextAction()
        : null;
    final habitProof = completedCheckIn != null
        ? await PatternMemoryCoordinator.loadLatestHabitProof()
        : null;
    final weeklyRecap = completedCheckIn != null
        ? await PatternMemoryCoordinator.loadLatestWeeklyRecap()
        : null;
    final canShareRecap =
        completedCheckIn != null &&
        (weeklyRecap != null ||
            patternProgress != null ||
            (patternMemory != null && patternMemory.checkInCount >= 2));
    final shareRecap = canShareRecap
        ? await PatternMemoryCoordinator.buildShareRecap()
        : null;

    final latestReflectionText = resolveEntryDisplayText(savedEntry).text.isNotEmpty
        ? resolveEntryDisplayText(savedEntry).text
        : savedEntry.transcript;
    // Detect reflection language so post-save cards can speak the same
    // language. Screenshot mode forces a language for marketing captures.
    final detected = ScreenshotMode.language != null
        ? DetectedLanguage.userSelected(ScreenshotMode.languageCode)
        : detectReflectionLanguage(latestReflectionText);
    final languageCode = detected.uiLanguageCode;
    unawaited(
      ReflectionLanguageStore(
        AppServices.instance.prefs,
      ).recordDetection(detected, originalText: latestReflectionText),
    );
    final inputQuality = assessReflectionQuality(latestReflectionText);
    unawaited(
      InputQualityStore(
        AppServices.instance.prefs,
      ).recordAssessment(inputQuality),
    );

    if (!mounted) return;
    setState(() {
      _ui = RecordUiState.done;
      _entriesAfterSave = all;
      // First 60 Seconds: usable first entry only — degraded voice waits for typed recovery.
      _recordReturnProJustSaved =
          all.length == 1 &&
          !VoiceCaptureQuality.isDegradedVoiceCapture(savedEntry);
      _archiveStateAfterSave = state;
      _inputQuality = inputQuality;
      _inputQualityText = latestReflectionText;
      _inputQualityResolved = false;
      _languageCode = languageCode;
      _detectedLanguageCode = languageCode;
      _instantReflectionResponse = instantResponse;
      _immediateDiscovery = null;
      _immediateDiscoveryLoading = true;
      _postSaveEvolution = null;
      _archiveEvolutionLoading = true;
      _tomorrowReturnLoop = null;
      _returnComparison = null;
      _returnStreak = null;
      _completedWatchForToday = null;
      _suggestedWatchForTomorrow = null;
      _watchForAlternativeIndex = 0;
      _activePatternThread = null;
      _isFirstSessionPostSave = false;
      _firstSessionPattern = null;
      _firstSessionAlternativeIndex = 0;
      _completedCheckInToday = completedCheckIn;
      _patternMemory = patternMemory;
      _patternProgress = patternProgress;
      _patternNextAction = patternNextAction;
      _habitProof = habitProof;
      _weeklyRecap = weeklyRecap;
      _shareRecap = shareRecap;
      _dueCheckInToday = completedCheckIn != null ? null : _dueCheckInToday;
      _trackInstantReflectionSurfaced(instantResponse);
      _error = null;
      if (VoiceCaptureQuality.isDegradedVoiceCapture(savedEntry)) {
        _localSaveTitle = null;
        _syncNote = null;
        _stageLabel = VoiceCaptureCopy.degradedRecoveryTitle;
      } else if (!cloudOk && hasSavedTranscript && !pipelineResult.analysisSucceeded) {
        _localSaveTitle = VoiceCaptureCopy.recordingSavedTitle;
        _syncNote = VoiceCaptureCopy.analysisUnavailableNote;
        _stageLabel = VoiceCaptureCopy.recordingSavedTitle;
      } else {
        _localSaveTitle = cloudOk
            ? null
            : CaptureSaveMessages.savedPrivatelyOnDevice;
        _syncNote = cloudOk
            ? null
            : ConsumerCopyGuard.userFacingSyncNote(pipelineResult.syncNote) ??
                  CaptureSaveMessages.addAnotherMomentTomorrow;
        _stageLabel = cloudOk
            ? 'Saved'
            : CaptureSaveMessages.savedPrivatelyOnDevice;
      }
      if (pipelineResult.attachedTypedTextToVoiceEntry) {
        RecordPipelineLog.typedFallbackInsightShown();
      }
      _archiveMovement = movement;
      _journalEntryCount = all.length;
      _journalEntryCountLoaded = true;
      _journalEntries = all;
      _entryDates = all.map((e) => e.createdAt).toList();
      _firstArchiveMilestoneCompleted =
          ExamplePromptVisibility.hasCompletedFirstArchiveMilestone(all);
      _showPostSaveLoop = cloudOk;
      _lastCaptureAnalysisSucceeded = pipelineResult.analysisSucceeded;
      _lastCaptureLowQualityTranscript = pipelineResult.lowQualityTranscript;
      _postSaveFollowUp = null;
    });

    unawaited(_handleSuggestionAttributionAfterSave(all.length));
    unawaited(_buildDoneForTodayReceipt());

    // Keep a long-term Key Moment so this reflection (or closed loop) is easy
    // to find again by day. Original text is preserved verbatim.
    unawaited(
      KeyMomentCoordinator.captureAfterSave(
        reflectionText: latestReflectionText,
        patternTitle: completedCheckIn?.patternTitle,
        resultHint: completedCheckIn?.selectedOption?.comparisonHint,
        nextCheck: completedCheckIn?.question,
        languageCode: languageCode,
        source: completedCheckIn != null
            ? KeyMomentSource.checkIn
            : KeyMomentSource.reflection,
      ),
    );

    final discovery = await discoveryFuture;
    final evolution = await evolutionFuture;
    final returnLoop =
        await TomorrowReturnLoopCoordinator.persistAfterRecording(
          all,
          immediateDiscovery: discovery,
        );

    final eligibleCount = all
        .where(
          (e) =>
              e.transcript.trim().isNotEmpty &&
              !e.transcript.startsWith('[draft]'),
        )
        .length;
    await ActivationTracker.trackReflectionMilestones(eligibleCount);
    unawaited(LoopModeCoordinator.onRecordingSaved());
    await ReturnReasonCaptureCoordinator.onReflectionSaved(
      eligibleCount: eligibleCount,
      lastReflectionAt: _lastReflectionAt,
    );
    if (eligibleCount == 1) {
      ActivationTracker.trackActivationFirstSaveCompleted();
    }
    if (TrialMode.enabled) {
      await ActivationTracker.trackTrialSaveCompleted();
    }

    // Return day: recording a moment after answering closes the loop.
    if (completedCheckIn != null) {
      await ReturnDayFrictionCoordinator.markMomentSaved(completedCheckIn.id);
      await ReturnDayFrictionCoordinator.markLoopClosed(completedCheckIn.id);
    }

    FirstLoopActivationState? firstLoopAfterSave;
    if (all.isNotEmpty) {
      firstLoopAfterSave =
          await FirstLoopActivationCoordinator.markFirstMomentSaved();
    }

    final firstSession = await FirstSessionCoordinator.isFirstSession(
      reflectionCount: all.length,
    );
    FirstSessionPattern? firstPattern;
    if (firstSession && all.isNotEmpty) {
      firstPattern = await FirstSessionCoordinator.buildFromEntry(
        all.last,
        alternativeIndex: _firstSessionAlternativeIndex,
      );
      firstLoopAfterSave =
          await FirstLoopActivationCoordinator.markFirstPatternShown(
            firstPattern.title,
          );
    }

    ReturnComparison? comparison;
    ReturnStreak? streak;
    WatchForItem? completedWatch;
    WatchForItem? suggestedWatch;
    ActivePatternThread? activeThread;
    SecondSessionComparison? secondComparison;
    FirstSessionPattern? postSavePattern;
    PatternHypothesis? patternHypothesis;

    if (firstSession && all.isNotEmpty) {
      postSavePattern = firstPattern;
    } else if (all.isNotEmpty) {
      postSavePattern = await FirstSessionCoordinator.buildFromEntry(
        all.last,
        alternativeIndex: _firstSessionAlternativeIndex,
      );
      if (all.length >= FirstThreeSessionGates.minEntriesForUsefulArchive ||
          (all.length == FirstThreeSessionGates.minEntriesForRepeatSurface &&
              const SecondSessionSignalEngine().hasGroundedRepeatMatch(all))) {
        secondComparison = const SecondSessionSignalEngine().build(all);
      }
    }
    if (all.length >= FirstThreeSessionGates.minEntriesForUsefulArchive) {
      patternHypothesis = await const PatternHypothesisEngine().build(all);
    }

    final postSaveFeedback = await SignalFeedbackStore.instance().loadAll();
    final postSaveSelected = await SelectedSignalCoordinator.loadCurrent();

    if (firstSession) {
      activeThread = await ActivePatternThreadCoordinator.loadCurrentThread();
    } else {
      completedWatch = await WatchForCoordinator.completePendingAfterSave(
        entries: all,
      );
      comparison = await ReturnComparisonCoordinator.buildAfterSaveIfDue(
        entries: all,
        loop: returnLoop,
      );
      suggestedWatch = returnLoop != null
          ? WatchForCoordinator.buildSuggestedWatchForAfterSave(
              entries: all,
              loop: returnLoop,
              signals: ArchiveBeliefsPresenter.potentialSignalsFromEntry(
                all.last,
              ),
              alternativeIndex: _watchForAlternativeIndex,
            )
          : null;
      streak = comparison != null
          ? await ReturnRetentionCoordinator.loadStreak()
          : null;
      activeThread = completedWatch != null
          ? await ActivePatternThreadCoordinator.loadCurrentThread()
          : await ActivePatternThreadCoordinator.loadCurrentThread();
    }

    if (!mounted) return;
    setState(() {
      _immediateDiscovery = discovery;
      _immediateDiscoveryLoading = false;
      _postSaveEvolution = evolution;
      _archiveEvolutionLoading = false;
      _isFirstSessionPostSave = firstSession;
      _firstSessionPattern = firstPattern;
      _postSavePattern = postSavePattern ?? firstPattern;
      _postSaveInsightFeedback = postSaveFeedback;
      _postSaveSelectedSignal = postSaveSelected;
      _secondSessionComparison = secondComparison;
      _patternHypothesis = patternHypothesis;
      _patternHypothesisDismissed = false;
      _firstLoopJustReady = false;
      _returnDayJustClosed = completedCheckIn != null;
      if (firstLoopAfterSave != null) {
        _firstLoop = firstLoopAfterSave;
      }
      if (TrialMode.enabled && firstSession && firstPattern != null) {
        _watchForAcceptPending = true;
        unawaited(ActivationTracker.markWatchForAcceptPending());
      }
      _returnComparison = comparison;
      _returnStreak = streak;
      _tomorrowReturnLoop = returnLoop;
      _completedWatchForToday = completedWatch;
      _suggestedWatchForTomorrow = suggestedWatch;
      _pendingWatchForToday = null;
      _activePatternThread = activeThread;
      if (returnLoop != null) {
        _postSaveFollowUp = returnLoop.watchForNextTime;
      }
      if (evolution != null) {
        _localSaveTitle = null;
        _stageLabel = '';
      }
    });
    ProductAnalytics.trackStrings('immediate_discovery_surfaced', {
      'has_discovery': discovery != null ? 'yes' : 'no',
      if (discovery != null) 'type': discovery.type.name,
    });
    ProductAnalytics.trackStrings('archive_evolution_after_recording', {
      'has_evolution': evolution != null ? 'yes' : 'no',
      if (evolution != null) 'kind': evolution.kind.name,
    });
    await _loadFirstThreeJourney();
    unawaited(_loadSignalArchive());
  }

  void _trackInstantReflectionSurfaced(InstantReflectionResponse? response) {
    ProductAnalytics.trackStrings('instant_reflection_surfaced', {
      'has_response': response != null ? 'yes' : 'no',
      if (response != null) 'signal': response.signal.name,
    });
  }

  /// True when the just-saved reflection is weak and the user has not yet
  /// added a sentence or chosen to use it anyway. Gates the pattern/result so
  /// the coach is the first thing shown. One sharpening prompt per reflection.
  bool get _showInputQualityCoach =>
      _inputQuality != null &&
      _inputQuality!.shouldAskForSharpening &&
      !_inputQualityResolved;

  bool get _applyEmptyArchiveGates => !ScreenshotMode.enabled;

  bool get _journalEntryCountReady =>
      _journalEntryCountLoaded || ScreenshotMode.enabled;

  void _logRecordEmptyGate([String reason = 'build']) {
    if (kDebugMode) {
      debugPrint(
        'record_empty_gate entryCount=$_journalEntryCount '
        'loaded=$_journalEntryCountLoaded reason=$reason',
      );
    }
  }

  bool get _canShowArchiveProgressCards =>
      RecordEmptyArchiveGates.allowArchiveProgressUi(
        loaded: _journalEntryCountReady,
        entryCount: _journalEntryCount,
      ) ||
      !_applyEmptyArchiveGates;

  DailyMirrorResult get _dailyMirror {
    if (!_journalEntryCountReady) return DailyMirrorResult.empty;
    return const DailyMirrorEngine().build(_journalEntries);
  }

  bool get _showDailyMirrorCard =>
      _applyEmptyArchiveGates &&
      RecordEmptyArchiveGates.showDailyMirrorCard(
        loaded: _journalEntryCountReady,
        entryCount: _journalEntryCount,
      );

  bool get _isPostSaveSurface =>
      _ui == RecordUiState.done || _showPostSaveLoop;

  bool get _showFirstRunPrivacyReassurance {
    if (CreatorDemoMode.isActive) return false;
    if (ScreenshotMode.enabled) {
      return ScreenshotMode.recordCleanFirstRunPreview &&
          _journalEntryCount == 0 &&
          !_isPostSaveSurface;
    }
    return RecordEmptyArchiveGates.showFirstRunPrivacyReassurance(
      loaded: _journalEntryCountReady,
      entryCount: _journalEntryCount,
      isPostSave: _isPostSaveSurface,
    );
  }

  bool get _showReadyToRecordStatus =>
      !_applyEmptyArchiveGates ||
      RecordEmptyArchiveGates.showReadyToRecordStatus(
        loaded: _journalEntryCountReady,
        entryCount: _journalEntryCount,
      );

  bool get _showArchiveContextPrompts =>
      !_applyEmptyArchiveGates ||
      RecordEmptyArchiveGates.showArchiveContextPrompts(
        loaded: _journalEntryCountReady,
        entryCount: _journalEntryCount,
      );

  bool get _showFirstThreeJourneyOnRecord =>
      !_applyEmptyArchiveGates ||
      RecordEmptyArchiveGates.showFirstThreeJourneyCard(
        loaded: _journalEntryCountReady,
        entryCount: _journalEntryCount,
      );

  bool get _showRetentionJourneyCards =>
      !_applyEmptyArchiveGates ||
      RecordEmptyArchiveGates.showRetentionJourneyCards(
        loaded: _journalEntryCountReady,
        entryCount: _journalEntryCount,
      );

  bool get _showTwoDayActivationCard =>
      !_applyEmptyArchiveGates ||
      RecordEmptyArchiveGates.showTwoDayActivationCard(
        loaded: _journalEntryCountReady,
        entryCount: _journalEntryCount,
      );

  bool get _showLegacyEmptyOnboarding =>
      !_applyEmptyArchiveGates ||
      RecordEmptyArchiveGates.showLegacyEmptyOnboarding(
        loaded: _journalEntryCountReady,
        entryCount: _journalEntryCount,
      );

  bool get _showCurrentObjectiveOnRecord =>
      !_applyEmptyArchiveGates ||
      RecordEmptyArchiveGates.showCurrentObjectiveCard(
        loaded: _journalEntryCountReady,
        entryCount: _journalEntryCount,
      );

  bool get _showBottomRetentionCards =>
      !_applyEmptyArchiveGates ||
      RecordEmptyArchiveGates.showBottomRetentionCards(
        loaded: _journalEntryCountReady,
        entryCount: _journalEntryCount,
      );

  bool get _showAhaMomentCards =>
      !_applyEmptyArchiveGates ||
      RecordEmptyArchiveGates.showAhaMomentCards(
        loaded: _journalEntryCountReady,
        entryCount: _journalEntryCount,
      );

  RecordStackDecision _recordStackDecision(RecordUiState ui) {
    final hasDueCheck =
        _dueCheckInToday != null &&
        (ui == RecordUiState.ready || ui == RecordUiState.recording);
    final hasSavedReflection =
        ui == RecordUiState.done && _entriesAfterSave.isNotEmpty;
    final hasCompletedResult =
        _completedCheckInToday != null && !_returnDayJustClosed;
    final hasResultNextCheck = hasCompletedResult && !_showInputQualityCoach;
    final hasArchiveProof =
        _patternMemory != null ||
        _patternProgress != null ||
        _patternNextAction != null ||
        _habitProof != null ||
        _weeklyRecap != null ||
        _shareRecap != null;
    final readyNotPostSave =
        ui == RecordUiState.ready || ui == RecordUiState.recording;
    final retentionState = _buildRetentionState(
      readyNotPostSave: readyNotPostSave,
    );
    final hasRetentionCard = _shouldShowRetentionOnRecord(
      retentionState,
      readyNotPostSave: readyNotPostSave,
      hasDueCheck: hasDueCheck,
      hasResultNextCheck: hasResultNextCheck,
    );

    final returnDay = const ReturnDayJourneyEngine().evaluate(
      journey: _signalJourney,
      reflectionCount: _journalEntryCount,
      now: DateTime.now(),
      lastReflectionAt: _lastReflectionAt,
    );

    return decideRecordStack(
      hasDueCheck: hasDueCheck,
      isFirstRun: _journalEntryCountReady && _journalEntryCount == 0,
      reflectionCount: _journalEntryCount,
      entryCountLoaded: _journalEntryCountReady,
      isTrialMode: TrialMode.enabled,
      isRecording: ui == RecordUiState.recording,
      hasSavedReflection: hasSavedReflection,
      inputQualityNeedsCoach: _showInputQualityCoach,
      hasCompletedResult: hasCompletedResult,
      hasResultNextCheck: hasResultNextCheck,
      hasRoutineAnchorOffer: hasResultNextCheck,
      hasArchiveProof: hasArchiveProof,
      archiveMemoryDemoEligible: !TrialMode.enabled,
      hasRetentionStateCard: hasRetentionCard,
      suppressRetentionForFirstRunDemo:
          retentionState.type == RetentionStateType.noCheckSet,
      suppressRetentionForPostSaveNextCheck:
          retentionState.type == RetentionStateType.loopClosed &&
          hasResultNextCheck,
      showReturnDayJourney:
          returnDay.showCard && readyNotPostSave && !hasDueCheck,
    );
  }

  CurrentObjective _buildCurrentObjective({required bool readyNotPostSave}) {
    final retentionState = _buildRetentionState(
      readyNotPostSave: readyNotPostSave,
    );
    final loopClosed =
        _completedCheckInToday != null &&
        !_returnDayJustClosed &&
        _activeCheckInForTomorrow == null &&
        _dueCheckInToday == null;
    return buildCurrentObjective(
      retentionState: retentionState,
      activeCheckIn: _dueCheckInToday ?? _activeCheckInForTomorrow,
      hasAnyMoment: _journalEntryCount > 0,
      hasClosedLoopToday: loopClosed && readyNotPostSave,
      hasNextCheckChosen: _retentionNextCheckJustChosen,
      latestNextCheck:
          _activeCheckInForTomorrow?.question ??
          _completedCheckInToday?.tomorrowsBetterQuestion,
      latestPatternTitle:
          _activeCheckInForTomorrow?.patternTitle ??
          _completedCheckInToday?.patternTitle,
    );
  }

  void _onCurrentObjectivePrimary(CurrentObjective objective) {
    switch (objective.type) {
      case CurrentObjectiveType.recordFirstMoment:
      case CurrentObjectiveType.recordAnyMoment:
      case CurrentObjectiveType.answerTodayCheck:
      case CurrentObjectiveType.chooseNextCheck:
        unawaited(_onRecordPressed(source: 'moment'));
      case CurrentObjectiveType.doneForToday:
        setState(() => _retentionDismissed = true);
    }
  }

  Widget? _currentObjectiveWidget(RecordStackDecision stack) {
    if (ScreenshotMode.enabled) {
      if (ScreenshotMode.objectiveDueCheckPreview) {
        return CurrentObjectiveCard(
          objective: ScreenshotSampleData.objectiveDueCheckSample,
          onPrimaryTap: () {},
          persistSnapshot: false,
        );
      }
      if (ScreenshotMode.objectiveFirstMomentPreview) {
        return CurrentObjectiveCard(
          objective: ScreenshotSampleData.objectiveFirstMomentSample,
          onPrimaryTap: () => unawaited(_onRecordPressed(source: 'moment')),
          persistSnapshot: false,
        );
      }
      if (ScreenshotMode.objectiveNextReadyPreview) {
        return CurrentObjectiveCard(
          objective: ScreenshotSampleData.objectiveNextReadySample,
          onPrimaryTap: () {},
          persistSnapshot: false,
        );
      }
    }
    if (!stack.showCurrentObjectiveCard) return null;
    final objective = _buildCurrentObjective(
      readyNotPostSave:
          _ui == RecordUiState.ready || _ui == RecordUiState.recording,
    );
    return CurrentObjectiveCard(
      objective: objective,
      onPrimaryTap: () => _onCurrentObjectivePrimary(objective),
      persistSnapshot: !ScreenshotMode.enabled,
      showRecordCta: !_shouldHideCardRecordButtons(_ui),
    );
  }

  RetentionState _buildRetentionState({required bool readyNotPostSave}) {
    final active = _dueCheckInToday ?? _activeCheckInForTomorrow;
    final missed = _missedCheckInForDiagnosis == null
        ? _recentMissedCheckIn
        : null;
    final loopClosed =
        _completedCheckInToday != null &&
        !_returnDayJustClosed &&
        _activeCheckInForTomorrow == null &&
        _dueCheckInToday == null;
    return buildRetentionState(
      now: DateTime.now(),
      activeCheckIn: active,
      missedCheckIn: missed,
      hasClosedLoopToday: loopClosed && readyNotPostSave,
      hasChosenNextCheck: _retentionNextCheckJustChosen,
      latestNextCheck:
          _activeCheckInForTomorrow?.question ??
          _completedCheckInToday?.tomorrowsBetterQuestion,
      latestPatternTitle:
          _activeCheckInForTomorrow?.patternTitle ??
          _completedCheckInToday?.patternTitle,
      compact:
          _retentionNextCheckJustChosen ||
          (_activeCheckInForTomorrow != null && _dueCheckInToday == null),
    );
  }

  bool _shouldShowRetentionOnRecord(
    RetentionState state, {
    required bool readyNotPostSave,
    required bool hasDueCheck,
    required bool hasResultNextCheck,
  }) {
    if (_retentionDismissed &&
        state.type == RetentionStateType.nextCheckChosen) {
      return false;
    }
    if (state.type == RetentionStateType.checkDueToday && hasDueCheck) {
      return false;
    }
    if (state.type == RetentionStateType.checkMissed &&
        _missedCheckInForDiagnosis != null) {
      return false;
    }
    if (state.type == RetentionStateType.loopClosed && hasResultNextCheck) {
      return false;
    }
    if (state.type == RetentionStateType.nextCheckChosen &&
        _retentionNextCheckJustChosen) {
      return true;
    }
    return readyNotPostSave;
  }

  void _onRetentionPrimaryTap(RetentionState state) {
    switch (state.type) {
      case RetentionStateType.noCheckSet:
      case RetentionStateType.checkMissed:
        unawaited(_onRecordPressed(source: 'moment'));
      case RetentionStateType.checkDueToday:
      case RetentionStateType.checkSetForTomorrow:
        break;
      case RetentionStateType.loopClosed:
        break;
      case RetentionStateType.nextCheckChosen:
        setState(() => _retentionDismissed = true);
    }
  }

  Widget? _retentionCardWidget(RecordStackDecision stack) {
    if (!stack.showRetentionStateCard) return null;
    final state = _buildRetentionState(
      readyNotPostSave:
          _ui == RecordUiState.ready ||
          _ui == RecordUiState.recording ||
          _retentionNextCheckJustChosen,
    );
    final compelling = state.checkQuestion != null
        ? buildCompellingCheck(
            baseQuestion: state.checkQuestion!,
            patternTitle: state.patternTitle,
          )
        : null;
    return RetentionStateCard(
      state: state,
      checkWhyThisCheck: compelling?.whyThisCheck,
      checkExampleAnswer: compelling?.exampleAnswer,
      onPrimaryTap: () => _onRetentionPrimaryTap(state),
      onDismiss: () => setState(() => _retentionDismissed = true),
    );
  }

  bool get _weakInput =>
      _inputQuality != null && _inputQuality!.shouldAskForSharpening;

  /// First-session pattern only earns a kinder angle for the harder, more
  /// self-directed triggers; quieter signals stay out of the way.
  KinderAngleTrigger? get _firstSessionKinderTrigger {
    final trigger = detectKinderAngleTrigger(_inputQualityText.trim());
    const allowed = {
      KinderAngleTrigger.selfBlame,
      KinderAngleTrigger.pressure,
      KinderAngleTrigger.tiredness,
    };
    return allowed.contains(trigger) ? trigger : null;
  }

  void _onInputQualityUseAnyway() {
    setState(() => _inputQualityResolved = true);
    unawaited(
      InputQualityStore(AppServices.instance.prefs).recordAcceptedWeak(),
    );
  }

  void _onLanguageSelected(String code) {
    if (code == _languageCode) return;
    setState(() => _languageCode = code);
    if (AppServices.isInitialized) {
      unawaited(
        ReflectionLanguageStore(
          AppServices.instance.prefs,
        ).recordOverride(code),
      );
    }
  }

  Future<void> _onInputQualityAddSentence(String combinedText) async {
    final quality = assessReflectionQuality(combinedText);
    final store = InputQualityStore(AppServices.instance.prefs);
    await store.recordSharpened();
    await store.recordAssessment(quality);
    if (!mounted) return;
    setState(() {
      _inputQuality = quality;
      _inputQualityText = combinedText;
      _inputQualityResolved = true;
    });
  }

  Future<void> _saveNextEvidencePrompt(String prompt) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) return;
    final selected = await SelectedSignalCoordinator.loadCurrent();
    final objective = CurrentObjective(
      type: CurrentObjectiveType.recordAnyMoment,
      title: ConsumerUiCopy.postSaveInsightRecordThisNext,
      body: trimmed,
      checkQuestion: trimmed,
      patternTitle: selected?.title,
      primaryCtaLabel: ConsumerUiCopy.postSaveInsightUseThisPrompt,
      route: '/record',
    );
    await CurrentObjectiveSnapshotStore.instance().saveSnapshot(objective);
    if (!mounted) return;
    setState(() => _nextEvidencePrompt = trimmed);
  }

  void _keepRecording({String? nextEvidencePrompt}) {
    setState(() {
      _showPostSaveLoop = false;
      _returnDayJustClosed = false;
      _inputQuality = null;
      _inputQualityText = '';
      _inputQualityResolved = false;
      _languageCode = ScreenshotMode.languageCode;
      _detectedLanguageCode = ScreenshotMode.languageCode;
      _instantReflectionResponse = null;
      _immediateDiscovery = null;
      _immediateDiscoveryLoading = false;
      _postSaveEvolution = null;
      _archiveEvolutionLoading = false;
      if (_postSaveFollowUp != null) {
        _selectedPromptLine = _postSaveFollowUp;
      }
      _postSaveFollowUp = null;
      _saveReceipt = null;
      _suggestionProNudgeSource = null;
      _doneForTodayReceipt = null;
      _dayTwoReturnPreview = null;
      _offerDayTwoReminder = false;
      _recordReturnProJustSaved = false;
      _archiveProofCounter = null;
      _shareableProof = null;
      _valueMomentBridge = null;
      _showEvidenceContextTag = false;
      _tomorrowReturnLoop = null;
      _returnComparison = null;
      _returnStreak = null;
      _completedWatchForToday = null;
      _suggestedWatchForTomorrow = null;
      _watchForAlternativeIndex = 0;
      _activePatternThread = null;
      _isFirstSessionPostSave = false;
      _firstSessionPattern = null;
      _postSavePattern = null;
      _secondSessionComparison = null;
      _patternHypothesis = null;
      _patternHypothesisDismissed = false;
      _firstSessionAlternativeIndex = 0;
      _localSaveTitle = null;
      _syncNote = null;
      _archiveMovement = null;
      _nextEvidencePrompt = nextEvidencePrompt?.trim().isNotEmpty == true
          ? nextEvidencePrompt!.trim()
          : null;
      _ui = _uiForMicPhase(_mic);
    });
  }

  Future<void> _applyAcquisitionIntentPrompt() async {
    if (widget.initialPrompt?.trim().isNotEmpty == true) return;
    if (_journalEntryCount > 0) return;
    final store = AudienceWedgeStore.instance();
    final wedge = await store.load();
    final loop = await LoopModeCoordinator.loadActive();
    final prompt = loop?.activePrompt.isNotEmpty == true
        ? loop!.activePrompt
        : await store.firstRecordingPrompt();
    if (!mounted) return;
    setState(() {
      _audienceWedge = wedge;
      _activeLoop = loop;
      if (_selectedPromptLine == null || _selectedPromptLine!.isEmpty) {
        _selectedPromptLine = prompt;
      }
    });
    if (prompt.isNotEmpty) {
      unawaited(FirstInsightSpecificityStore.markFirstPromptUsed());
      if (loop != null) {
        unawaited(LoopModeCoordinator.markFirstPromptUsed());
      }
    }
  }

  Future<void> _onSecondSessionEvidence(String prompt) async {
    _keepRecording(nextEvidencePrompt: prompt);
    final journey = await SignalJourneyCoordinator.loadActive();
    if (journey != null) {
      unawaited(
        NextEvidenceReminderService.schedule(
          journeyId: journey.id,
          prompt: prompt,
        ),
      );
    }
    if (mounted) {
      unawaited(
        maybeOfferReminderPrePrompt(
          context,
          trigger: ReminderPrePromptTrigger.secondRecordingComparison,
        ),
      );
    }
  }

  List<String> _postSaveSignals() {
    if (_entriesAfterSave.isEmpty) return const [];
    return ArchiveBeliefsPresenter.potentialSignalsFromEntry(
      _lastSavedEntry!,
    );
  }

  bool _postSaveShowsPossiblePattern() {
    if (_immediateDiscovery != null) return true;
    if (_postSaveSignals().isNotEmpty) return true;
    final noticed = _tomorrowReturnLoop?.noticedToday.toLowerCase() ?? '';
    return noticed.contains('pattern') || noticed.contains('forming');
  }

  void _enoughForNow() {
    if (TrialMode.enabled && _watchForAcceptPending) {
      unawaited(
        ActivationTracker.trackTrialClosedBeforeWatchForAcceptedIfPending(),
      );
      _watchForAcceptPending = false;
    }
    setState(() {
      _showPostSaveLoop = false;
      _postSaveFollowUp = null;
      _saveReceipt = null;
      _suggestionProNudgeSource = null;
      _doneForTodayReceipt = null;
      _dayTwoReturnPreview = null;
      _offerDayTwoReminder = false;
      _recordReturnProJustSaved = false;
      _archiveProofCounter = null;
      _shareableProof = null;
      _valueMomentBridge = null;
      _showEvidenceContextTag = false;
      _tomorrowReturnLoop = null;
      _localSaveTitle = null;
      _syncNote = null;
      _archiveMovement = null;
      _ui = _uiForMicPhase(_mic);
    });
    context.go('/archive-belief');
  }

  bool _compactLayout(RecordUiState ui) =>
      ui == RecordUiState.recording || ui == RecordUiState.processing;

  @override
  Widget build(BuildContext context) {
    var ui = _ui;
    var policyMic = _mic;
    var policyUserDenied = _micPermissionUserDenied;
    var error = _error;
    var localSaveTitle = _localSaveTitle;
    var syncNote = ConsumerCopyGuard.userFacingSyncNote(_syncNote);
    var stageLabel = _stageLabel;
    var entriesAfterSave = _entriesAfterSave;
    if (VisualAuditOverrides.active) {
      final audit = VisualAuditOverrides.peekRecordPresentation();
      if (audit != null) {
        ui = audit.ui;
        if (audit.entriesAfterSave != null) {
          entriesAfterSave = audit.entriesAfterSave!;
        }
        if (audit.micPhase != null) policyMic = audit.micPhase!;
        if (audit.userDeniedThisSession != null) {
          policyUserDenied = audit.userDeniedThisSession!;
        }
        error = audit.error;
        localSaveTitle = audit.localSaveTitle;
        syncNote = ConsumerCopyGuard.userFacingSyncNote(audit.syncNote);
        stageLabel = audit.stageLabel ?? _stageLabel;
      }
    }

    final canRecord =
        (ui == RecordUiState.ready || ui == RecordUiState.recording) &&
        !RecordMicrophonePermissionUi.shouldHideBlockedPanelDuringRequest(ui);
    final showFraming =
        ui == RecordUiState.ready ||
        ui == RecordUiState.idle ||
        ui == RecordUiState.requestingPermission ||
        ui == RecordUiState.permissionBlocked;
    final compact = _compactLayout(ui);
    final stack = _recordStackDecision(ui);
    if (stack.showFirstRecordingHandoff && !_firstRecordCardTracked) {
      _firstRecordCardTracked = true;
      ActivationTracker.trackActivationFirstRecordCardShown();
    }
    final suppressPostResultNextCheckCompetitors =
        stack.suppressDuplicateUseTomorrowCtas;
    final suppressNoisyFirstSaveCards =
        FirstThreeSessionGates.suppressNoisyPostSaveCards(
          justSavedFirst: _recordReturnProJustSaved,
          entryCount: _journalEntryCount,
        );
    final suppressEarlyPatternClaimCards =
        FirstThreeSessionGates.suppressEarlyPatternClaimCards(
          entryCount: _journalEntryCount,
          hasGroundedRepeatMatch:
              _secondSessionComparison?.hasEnoughData == true &&
              const SecondSessionSignalEngine().hasGroundedRepeatMatch(
                _entriesAfterSave.isNotEmpty
                    ? _entriesAfterSave
                    : _journalEntries,
              ),
        );

    _logRecordEmptyGate('build');
    _maybeLogRecordCtaPolicy(
      _recordCtaPolicy(
        ui,
        micPhase: policyMic,
        userDeniedThisSession: policyUserDenied,
      ),
    );

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final showCloseButton = RecordScreenCloseButton.shouldShow(context);
    return ColoredBox(
      color: AppColors.backgroundPrimary,
      child: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              key: const Key('record_screen_scroll'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                24,
                8,
                24,
                (compact ? 12 : 16) + bottomInset,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (kDebugMode)
                      SizedBox(
                        key: ValueKey(
                          'record_empty_gate_${_journalEntryCount}_'
                          '$_journalEntryCountLoaded',
                        ),
                        width: 0,
                        height: 0,
                      ),
                    if (showFraming &&
                        ui == RecordUiState.ready &&
                        _journalEntryCountReady &&
                        _journalEntryCount == 0) ...[
                      const RecordTopArchivePromiseHero(),
                      const SizedBox(height: 16),
                    ],
                    if (ui == RecordUiState.ready &&
                        _journalEntryCountReady &&
                        _journalEntryCount == 0 &&
                        _showFirstRunPrivacyReassurance) ...[
                      const RecordFirstRunPrivacyReassurance(),
                      const SizedBox(height: 12),
                    ],
                    if (showFraming && stack.showFramingTitle) ...[
                      Text(
                        RecordScreenFramingCopy.title,
                        style: ArchiveMobileTypography.recordPageTitle(context),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        RecordScreenFramingCopy.guidance,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: VoiceMemoryColors.textSecondary,
                          fontSize: ArchiveMobileTypography.responsiveBody(
                            context,
                          ).fontSize,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (ui == RecordUiState.ready) ...[
                      Builder(
                        builder: (context) {
                          final readyPolicy = _recordCtaPolicy(
                            ui,
                            micPhase: policyMic,
                            userDeniedThisSession: policyUserDenied,
                          );
                          if (!_shouldPromoteMicCaptureActions(readyPolicy)) {
                            return const SizedBox.shrink();
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildCaptureEntryActions(
                                context: context,
                                selectedPrompt: _selectedPromptLine,
                                policy: readyPolicy,
                              ),
                              const SizedBox(height: 12),
                            ],
                          );
                        },
                      ),
                    ],
                    // Zero-entry intro card removed — [RecordTopArchivePromiseHero]
                    // carries the first-open promise without a second competing card.
                    if (ui == RecordUiState.ready &&
                        _showDailyMirrorCard &&
                        !(_journalEntryCountReady && _journalEntryCount == 0)) ...[
                      DailyMirrorRecordCard(
                        mirror: _dailyMirror,
                        onPrimaryCta: () => unawaited(_onRecordPressed(source: 'moment')),
                        showRecordCta: !_shouldHideCardRecordButtons(ui),
                      ),
                      if (_showFirstRunPrivacyReassurance) ...[
                        const SizedBox(height: 8),
                        const RecordFirstRunPrivacyReassurance(),
                      ],
                      const SizedBox(height: 12),
                    ],
                    if (_missedCheckInForDiagnosis != null &&
                        ui == RecordUiState.ready &&
                        _showBottomRetentionCards) ...[
                      MissedCheckInReasonPrompt(
                        checkIn: _missedCheckInForDiagnosis!,
                        onAnswered: () =>
                            setState(() => _missedCheckInForDiagnosis = null),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if ((_showCurrentObjectiveOnRecord &&
                            stack.showCurrentObjectiveCard &&
                            !_shouldHideCompetingRecordCtas(ui)) ||
                        (ScreenshotMode.enabled &&
                            ScreenshotMode.objective != null)) ...[
                      _currentObjectiveWidget(stack)!,
                      const SizedBox(height: 16),
                    ],
                    if (stack.showRetentionStateCard &&
                        _canShowArchiveProgressCards) ...[
                      _retentionCardWidget(stack)!,
                      const SizedBox(height: 16),
                    ],
                    if (stack.showDueCheckCard &&
                        _journalEntryCountReady &&
                        _journalEntryCount >= 1) ...[
                      Builder(
                        builder: (context) {
                          final guided =
                              _hookRescue?.includes(
                                HookRescueAction.guidedCheckIn,
                              ) ??
                              false;
                          return TomorrowCheckInDueCard(
                            checkIn: _dueCheckInToday!,
                            plannedAnchor: _dueRoutineAnchor,
                            guided: guided,
                            // Fast path by default; only the gated guided flow opts
                            // out so confused users still get the step-by-step card.
                            oneTapMode: !guided,
                            onRecord: () => unawaited(_onRecordPressed(source: 'moment')),
                            onSelectOption: (option) async {
                              final checkInId = _dueCheckInToday!.id;
                              final updated =
                                  await TomorrowCheckInCoordinator.selectOption(
                                    checkInId: checkInId,
                                    optionId: option.id,
                                  );
                              await ReturnDayFrictionCoordinator.markAnswerSelected(
                                checkInId,
                                option.id,
                              );
                              if (!mounted) return;
                              setState(() {
                                _dueCheckInToday = updated;
                              });
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (stack.showReturnDayJourneyCard &&
                        _canShowArchiveProgressCards &&
                        _signalJourney != null &&
                        ui == RecordUiState.ready) ...[
                      ReturnDayJourneyCard(
                        journey: _signalJourney!,
                        recordedToday: const ReturnDayJourneyEngine()
                            .evaluate(
                              journey: _signalJourney,
                              reflectionCount: _journalEntryCount,
                              now: DateTime.now(),
                              lastReflectionAt: _lastReflectionAt,
                            )
                            .recordedToday,
                        onViewChanged: () => context.push('/signal-journey'),
                      ),
                      const SizedBox(height: 12),
                    ] else if (!_shouldHideCompetingRecordCtas(ui) &&
                        stack.showFirstRecordingHandoff &&
                        _activeLoop != null) ...[
                      LoopModeFirstHandoffCard(
                        loop: _activeLoop!,
                        onStartRecording: () => _onRecordPressed(source: 'main'),
                        showRecordCta: !_shouldHideCardRecordButtons(ui),
                      ),
                      const SizedBox(height: 12),
                    ] else if (!_shouldHideCompetingRecordCtas(ui) &&
                        stack.showFirstRecordingHandoff) ...[
                      FirstRecordingHandoffCard(
                        onStartRecording: () => _onRecordPressed(source: 'main'),
                        wedgePrompt: _selectedPromptLine,
                        showRecordCta: !_shouldHideCardRecordButtons(ui),
                      ),
                      const SizedBox(height: 12),
                    ] else if (!_shouldHideCompetingRecordCtas(ui) &&
                        _activeLoop != null &&
                        _canShowArchiveProgressCards &&
                        _postSavePattern == null &&
                        !stack.showReturnDayJourneyCard) ...[
                      LoopModeProgressCard(
                        loop: _activeLoop!,
                        onRecordNext: () => unawaited(_onRecordPressed(source: 'loop')),
                        showRecordCta: !_shouldHideCardRecordButtons(ui),
                      ),
                      const SizedBox(height: 12),
                    ] else if (!_shouldHideCompetingRecordCtas(ui) &&
                        stack.showArchiveMemoryDemo) ...[
                      ArchiveMemoryDemoCard(
                        onRecord: () => unawaited(_onRecordPressed(source: 'main')),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (stack.showFirstLoopStartCard &&
                        !_shouldHideCompetingRecordCtas(ui)) ...[
                      FirstLoopStartCard(
                        onRecord: () => unawaited(_onRecordPressed(source: 'loop')),
                        showRecordCta: !_shouldHideCardRecordButtons(ui),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (stack.showTrialFirstMomentCard &&
                        !_shouldHideCompetingRecordCtas(ui)) ...[
                      TrialFirstMomentCard(
                        onStartRecording: () =>
                            unawaited(_onRecordPressed(source: 'main')),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (RecordMicrophonePermissionUi.shouldRenderBlockedPanel(
                      ui: ui,
                      micPhase: _mic,
                      userDeniedThisSession: _micPermissionUserDenied,
                    )) ...[
                      KeyedSubtree(
                        key: _permissionPanelKey,
                        child: MicrophonePermissionBlockedPanel(
                          showSimulatorHelper: _showMicPermissionSimulatorHelper,
                          onOpenSettings: _openMicSettings,
                          onTypeInstead: _typeInsteadFromPermission,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (ui == RecordUiState.recording) ...[
                      _RecordingStatusCard(
                        seconds: _seconds,
                        stageLabel: stageLabel,
                      ),
                      if (_selectedPromptLine != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _selectedPromptLine!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: VoiceMemoryColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ] else ...[
                      if (ui == RecordUiState.ready &&
                          _showReadyToRecordStatus) ...[
                        Semantics(
                          label: 'Recording status',
                          child: Text(
                            stageLabel.isEmpty
                                ? _statusTextFor(ui, localSaveTitle)
                                : stageLabel,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                      if (ui == RecordUiState.processing) ...[
                        const SizedBox(height: 12),
                        PostSaveListeningCard(stageLabel: stageLabel),
                      ],
                      if (_selectedPromptLine != null &&
                          _showBottomRetentionCards &&
                          (ui == RecordUiState.ready ||
                              ui == RecordUiState.recording)) ...[
                        const SizedBox(height: 12),
                        Text(
                          ConsumerUiCopy.trySayingLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: VoiceMemoryColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedPromptLine!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: VoiceMemoryColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                      if (ui == RecordUiState.ready &&
                          _showArchiveContextPrompts &&
                          _nextEvidencePrompt != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBF5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ConsumerUiCopy.postSaveInsightRecordThisNext,
                                style: ArchiveMobileTypography.cardLabel(
                                  context,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _nextEvidencePrompt!,
                                style: ArchiveMobileTypography.explanationBody(
                                  context,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (ui == RecordUiState.ready &&
                          _canShowArchiveProgressCards &&
                          stack.showActivePatternThread &&
                          _activePatternThread != null) ...[
                        const SizedBox(height: 12),
                        ActivePatternThreadPromptCard(
                          thread: _activePatternThread!,
                          onAddMoment: () => unawaited(_onRecordPressed(source: 'moment')),
                          onPause: () async {
                            await ActivePatternThreadCoordinator.pauseThread();
                            if (!mounted) return;
                            setState(() => _activePatternThread = null);
                          },
                        ),
                      ],
                      if (ui == RecordUiState.ready &&
                          _canShowArchiveProgressCards &&
                          stack.showFirstThreeJourney &&
                          _firstThreeJourney != null &&
                          _firstThreeJourney!.showOnRecord &&
                          _showFirstThreeJourneyOnRecord) ...[
                        const SizedBox(height: 12),
                        FirstThreeJourneyCard(model: _firstThreeJourney!),
                      ],
                      if (ui == RecordUiState.ready &&
                          _canShowArchiveProgressCards &&
                          _postSavePattern == null &&
                          !stack.showReturnDayJourneyCard &&
                          _showRetentionJourneyCards &&
                          _signalJourney != null &&
                          _signalJourney!.isActive) ...[
                        const SizedBox(height: 12),
                        SignalJourneyCard(
                          journey: _signalJourney!,
                          activeLoop: _activeLoop,
                          compact: true,
                        ),
                      ] else if (ui == RecordUiState.ready &&
                          _canShowArchiveProgressCards &&
                          _postSavePattern == null &&
                          _showRetentionJourneyCards &&
                          _signalJourney != null &&
                          _signalJourney!.showCompletion &&
                          !_journeyCompletionDismissed &&
                          _signalReview != null &&
                          _signalReview!.isShowable) ...[
                        const SizedBox(height: 12),
                        SignalReviewCard(
                          review: _signalReview!,
                          onConfirm: () async {
                            await SignalReviewCoordinator.confirm(
                              reviewId: _signalReview!.id,
                            );
                            if (!mounted) return;
                            setState(() => _journeyCompletionDismissed = true);
                            unawaited(_loadSignalArchive());
                          },
                          onCorrect: () {
                            SignalReviewNavigation.openFullReview(context);
                          },
                          onKeepWatching: () async {
                            await SignalReviewCoordinator.keepWatching(
                              reviewId: _signalReview!.id,
                            );
                            final journey =
                                await SignalJourneyCoordinator.loadActive();
                            if (journey != null) {
                              unawaited(
                                NextEvidenceReminderService.schedule(
                                  journeyId: journey.id,
                                  prompt: _signalReview!.nextEvidencePrompt,
                                ),
                              );
                            }
                            if (!mounted) return;
                            setState(() => _journeyCompletionDismissed = true);
                            unawaited(_loadSignalArchive());
                            SignalReviewNavigation.recordNextEvidence(
                              context,
                              prompt: _signalReview!.nextEvidencePrompt,
                            );
                          },
                        ),
                      ] else if (ui == RecordUiState.ready &&
                          _canShowArchiveProgressCards &&
                          _postSavePattern == null &&
                          _showRetentionJourneyCards &&
                          _signalJourney != null &&
                          _signalJourney!.showCompletion &&
                          !_journeyCompletionDismissed) ...[
                        const SizedBox(height: 12),
                        SignalJourneyCompletionCard(
                          journey: _signalJourney!,
                          onKeepWatching: () async {
                            await SignalJourneyCoordinator.acknowledgeCompletion();
                            if (!mounted) return;
                            setState(() => _journeyCompletionDismissed = true);
                            unawaited(_loadSignalArchive());
                          },
                          onViewPattern: () => context.go('/archive-belief'),
                        ),
                      ] else if (ui == RecordUiState.ready &&
                          _canShowArchiveProgressCards &&
                          _postSavePattern == null &&
                          _showRetentionJourneyCards &&
                          _signalArchiveSnapshot?.hasActiveSignal == true) ...[
                        const SizedBox(height: 12),
                        ArchiveWatchingCard(
                          snapshot: _signalArchiveSnapshot!,
                          compact: true,
                        ),
                      ],
                      if (ui == RecordUiState.ready &&
                          _canShowArchiveProgressCards &&
                          stack.showPendingWatchFor &&
                          _pendingWatchForToday != null) ...[
                        const SizedBox(height: 12),
                        TodaysWatchForCard(
                          pending: _pendingWatchForToday!,
                          onRecord: () => unawaited(_onRecordPressed(source: 'moment')),
                          onSkip: () async {
                            await WatchForCoordinator.skipPendingForToday();
                            if (!mounted) return;
                            setState(() => _pendingWatchForToday = null);
                          },
                        ),
                      ],
                      if (ui == RecordUiState.ready &&
                          stack.showStarterPrompts &&
                          _showArchiveContextPrompts) ...[
                        if (_oneSmallRecording.hasRecording) ...[
                          const SizedBox(height: 12),
                          OneSmallRecordingCard(
                            recording: _oneSmallRecording,
                            showRecordCta: !_shouldHideCardRecordButtons(ui),
                            ctaLabel:
                                _recordCtaPolicy(
                                  ui,
                                  micPhase: policyMic,
                                  userDeniedThisSession: policyUserDenied,
                                ).primaryLabel ??
                                OneSmallRecording.recordCtaLabel,
                            onRecordThis: (p) {
                              ActivationTracker.trackActivationStarterPromptSelected();
                              setState(() => _selectedPromptLine = p);
                              unawaited(
                                _onRecordPressed(source: 'one_small_recording'),
                              );
                            },
                          ),
                          // Secondary one-tap fallback: contributes a real
                          // entry on days a full recording feels like too much.
                          const SizedBox(height: 8),
                          LowEffortCheckInCard(onSelect: _saveLowEffortCheckIn),
                        ],
                        if (_dailyReturnSuggestions.hasSuggestions) ...[
                          const SizedBox(height: 12),
                          DailyReturnSuggestionsCard(
                            suggestionSet: _dailyReturnSuggestions,
                            selectedPrompt: _selectedPromptLine,
                            onSuggestionTap: _onDailySuggestionTapped,
                            onSelectPrompt: (p) {
                              ActivationTracker.trackActivationStarterPromptSelected();
                              setState(() => _selectedPromptLine = p);
                            },
                          ),
                        ],
                        const SizedBox(height: 12),
                        ConsumerRecordPromptsSection(
                          selectedPrompt: _selectedPromptLine,
                          personalPrompts: _personalReturnPrompts,
                          // One clear primary action when a one-small-recording
                          // exists — generic prompts stay, but step back.
                          deemphasized: _oneSmallRecording.hasRecording,
                          onSelectPrompt: (p) {
                            ActivationTracker.trackActivationStarterPromptSelected();
                            // Generic prompt picked — the next save is no
                            // longer suggestion-sourced, so no receipt.
                            _pendingSuggestionSource = null;
                            _pendingTappedSuggestion = null;
                            setState(() => _selectedPromptLine = p);
                          },
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Say it plainly. ArchiveMe looks for patterns, '
                          'not judgment.',
                          style: VoiceMemoryTypography.metadataStyle(
                            color: AppColors.textSecondary,
                          ).copyWith(fontSize: 12, height: 1.4),
                        ),
                        const SizedBox(height: 6),
                        QuickHelpButton(
                          languageCode: _languageCode,
                          patternTitle: _activePatternThread?.title,
                          onStartRecording: () => _onRecordPressed(source: 'main'),
                        ),
                      ],
                      if (ui == RecordUiState.done &&
                          entriesAfterSave.isNotEmpty) ...[
                        if (!suppressNoisyFirstSaveCards) ...[
                          if (!VoiceCaptureQuality.isDegradedVoiceCapture(
                            entriesAfterSave.first,
                          )) ...[
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  color: VoiceMemoryColors.captureSuccess,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    BeliefProductCopy.reflectionSavedTitle,
                                    style: VoiceMemoryTypography.cardTitleStyle(
                                      color: VoiceMemoryColors.captureSuccess,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ] else ...[
                            const SizedBox(height: 16),
                          ],
                          PostSaveRecordedSummaryCard(
                            entry: entriesAfterSave.first,
                            allEntries: entriesAfterSave,
                            degradedBodyCopy: _lastCaptureLowQualityTranscript
                                ? VoiceCaptureCopy.lowQualityTranscriptIssue
                                : null,
                            showSilentInputWarning: _lastCaptureLikelySilentInput,
                            showAnalysisPendingNote:
                                !_lastCaptureAnalysisSucceeded &&
                                VoiceCaptureQuality.hasUsableSpokenText(
                                  entriesAfterSave.first,
                                ),
                            mirror: const DailyMirrorEngine().build(
                              entriesAfterSave,
                            ),
                          ),
                        ],
                        if (_languageCode != 'en') ...[
                          const SizedBox(height: 12),
                          LanguageIndicatorChip(
                            languageCode: _languageCode,
                            detectedCode: _detectedLanguageCode,
                            onSelected: _onLanguageSelected,
                          ),
                        ],
                        // Record → Return → Pro: evidence, return cue,
                        // Pro bridge — after the save succeeded, never blocking.
                        if (_recordReturnProJustSaved) ...[
                          const SizedBox(height: 16),
                          FirstSaveEvidenceCard(
                            onViewArchive: () => context.go('/archive-belief'),
                            onRecordAnother: () => unawaited(_onRecordPressed(source: 'main')),
                          ),
                          if (_recordReturnCueVisible &&
                              _journalEntryCount != 1) ...[
                            const SizedBox(height: 16),
                            TomorrowReturnCueCard(
                              reminderAvailable: _offerDayTwoReminder,
                              onLocalCue: _acceptRecordReturnLocalCue,
                              onRemind: _acceptRecordReturnReminder,
                            ),
                          ],
                          if (_recordReturnProState != null &&
                              RecordReturnProGates.showProBridge(
                                entryCount: _journalEntryCount,
                                resolved:
                                    _recordReturnProState!.proBridgeResolved,
                                isPro: _recordReturnProIsPro,
                              )) ...[
                            const SizedBox(height: 16),
                            ProValueClarityCard(
                              entryCount: _journalEntryCount,
                              source: 'record',
                              onSeePro: () =>
                                  _resolveRecordReturnProBridge(seePro: true),
                              onNotNow: () =>
                                  _resolveRecordReturnProBridge(seePro: false),
                            ),
                          ],
                        ],
                        if (_saveReceipt != null &&
                            !suppressNoisyFirstSaveCards) ...[
                          const SizedBox(height: 16),
                          StartHereSaveReceiptCard(
                            receipt: _saveReceipt!,
                            onDismiss: () =>
                                setState(() => _saveReceipt = null),
                          ),
                        ] else if (_suggestionProNudgeSource != null &&
                            !suppressNoisyFirstSaveCards) ...[
                          const SizedBox(height: 16),
                          _SuggestionProNudgeCard(
                            onUnlock: () {
                              final source = _suggestionProNudgeSource!;
                              setState(() => _suggestionProNudgeSource = null);
                              context.push(
                                '/subscription',
                                extra: PaywallRouteArgs(
                                  source: source,
                                  sourceRoute: '/record',
                                ),
                              );
                            },
                            onDismiss: () => setState(
                              () => _suggestionProNudgeSource = null,
                            ),
                          ),
                        ],
                        if (_doneForTodayReceipt != null &&
                            _doneForTodayReceipt!.hasReceipt &&
                            !suppressNoisyFirstSaveCards) ...[
                          const SizedBox(height: 16),
                          DoneForTodayReceiptCard(
                            receipt: _doneForTodayReceipt!,
                          ),
                          // 2-day path day-1 closure: only after the very
                          // first save, alongside (never instead of) the
                          // Done for today receipt.
                          Builder(
                            builder: (context) {
                              final path = const TwoDayActivationEngine()
                                  .buildPostSave(entryCount: _journalEntryCount);
                              if (!path.show) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: TwoDayActivationCard(path: path),
                              );
                            },
                          ),
                          // One optional day-2 reminder offer — first save
                          // only, below (never instead of) the receipt. The
                          // First 60 return cue carries the same single
                          // reminder offer, so the two never show together.
                          if (_offerDayTwoReminder && !_recordReturnCueVisible)
                            const Padding(
                              padding: EdgeInsets.only(top: 16),
                              child: DayTwoReminderCard(),
                            ),
                          // Tomorrow's-check preview — passive, no CTA,
                          // safe labels only.
                          if (_dayTwoReturnPreview != null &&
                              _dayTwoReturnPreview!.show)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: DayTwoReturnPreviewCard(
                                preview: _dayTwoReturnPreview!,
                                entryCount: _journalEntryCount,
                              ),
                            ),
                        ],
                        if (_archiveProofCounter != null &&
                            _archiveProofCounter!.hasProof &&
                            !suppressNoisyFirstSaveCards) ...[
                          const SizedBox(height: 16),
                          ArchiveProofCounterCard(
                            counter: _archiveProofCounter!,
                          ),
                        ],
                        if (_shareableProof != null &&
                            _shareableProof!.hasProof &&
                            !suppressNoisyFirstSaveCards) ...[
                          const SizedBox(height: 16),
                          ShareableArchiveProofCard(proof: _shareableProof!),
                        ],
                        if (_valueMomentBridge != null &&
                            _valueMomentBridge!.show &&
                            !suppressNoisyFirstSaveCards) ...[
                          const SizedBox(height: 16),
                          ValueMomentProBridge(
                            bridge: _valueMomentBridge!,
                            onSeePro: () {
                              setState(() => _valueMomentBridge = null);
                              context.push(
                                '/subscription',
                                extra: PaywallRouteArgs(
                                  source: PaywallSource.valueMoment,
                                  sourceRoute: '/record',
                                ),
                              );
                            },
                            onDismiss: () => setState(() {
                              ValueMomentPaywallTrigger.dismissedThisSession =
                                  true;
                              _valueMomentBridge = null;
                            }),
                          ),
                        ],
                        if (_showEvidenceContextTag &&
                            !suppressNoisyFirstSaveCards) ...[
                          const SizedBox(height: 16),
                          EvidenceContextTagCard(
                            onSaveTag: _saveEvidenceContextTag,
                            onSkip: () =>
                                setState(() => _showEvidenceContextTag = false),
                          ),
                        ],
                        if (stack.showInputQualityCoach) ...[
                          const SizedBox(height: 16),
                          InputQualityCoachCard(
                            result: _inputQuality!,
                            originalText: _inputQualityText,
                            onAddSentence: _onInputQualityAddSentence,
                            onUseAnyway: _onInputQualityUseAnyway,
                            languageCode: _languageCode,
                          ),
                        ],
                        if (!stack.showInputQualityCoach &&
                            stack.showCompletedResult &&
                            _returnDayJustClosed &&
                            !suppressNoisyFirstSaveCards) ...[
                          const SizedBox(height: 16),
                          ReturnDayClosedCard(
                            resultHeadline:
                                _completedCheckInToday!.resultHeadline,
                            usefulLine: _completedCheckInToday!.whatThisMeans,
                            nextCheck:
                                _completedCheckInToday!.tomorrowsBetterQuestion,
                            onDone: () =>
                                setState(() => _returnDayJustClosed = false),
                            onRecordAnother: _keepRecording,
                          ),
                          // First session never reaches here; only surface a fresh
                          // progress moment so the payoff stays one card deep.
                          if (stack.showArchiveProofCards &&
                              _patternProgress != null) ...[
                            const SizedBox(height: 16),
                            PatternProgressAfterSaveCard(
                              progress: _patternProgress!,
                            ),
                          ],
                        ] else if (!stack.showInputQualityCoach &&
                            stack.showCompletedResult &&
                            !suppressNoisyFirstSaveCards) ...[
                          const SizedBox(height: 16),
                          CheckInCompletedCard(
                            checkIn: _completedCheckInToday!,
                            weakInput: _weakInput,
                            languageCode: _languageCode,
                            betterResultIntensity:
                                ScreenshotMode.screenshotBetterResult
                                ? ScreenshotMode.screenshotBetterResultIntensity
                                : ScreenshotMode.completedCheckInPreview
                                ? HookRescueIntensity.elevated
                                : _hookRescue?.intensityFor(
                                        HookRescueAction.betterResult,
                                      ) ??
                                      HookRescueIntensity.normal,
                            notUsefulReason: _hookRescueNotUsefulReason,
                            nextCheckSlot: stack.showResultNextCheck
                                ? ResultNextCheckCard(
                                    checkIn: _completedCheckInToday!,
                                    notUsefulReason: _hookRescueNotUsefulReason,
                                    feedbackHint: _feedbackHint,
                                    showFeedback: stack.showFeedback,
                                    routineAnchorPicker: stack.showRoutineAnchor
                                        ? () =>
                                              RoutineAnchorChooser.show(context)
                                        : null,
                                    onRoutineAnchorChosen:
                                        stack.showRoutineAnchor
                                        ? (anchor) =>
                                              RoutineAnchorStore.instance()
                                                  .saveForDate(
                                                    _tomorrowDateKey,
                                                    anchor,
                                                  )
                                        : null,
                                    onCreateCheckIn: (question) async {
                                      await TomorrowCheckInCoordinator.createForTomorrow(
                                        patternTitle: _completedCheckInToday!
                                            .patternTitle,
                                        specificPrompt:
                                            _completedCheckInToday!.prompt,
                                        checkInQuestion: question,
                                      );
                                      final anchor =
                                          await RoutineAnchorStore.instance()
                                              .loadForDate(_tomorrowDateKey);
                                      final active =
                                          await TomorrowCheckInCoordinator.loadActive();
                                      if (active != null) {
                                        await RetentionReminderCoordinator.maybeScheduleAfterNextCheckChosen(
                                          active,
                                          hasRoutineAnchor: anchor != null,
                                        );
                                      }
                                      if (!mounted) return;
                                      setState(() {
                                        _retentionNextCheckJustChosen = true;
                                        _retentionDismissed = false;
                                        _activeCheckInForTomorrow = active;
                                      });
                                    },
                                  )
                                : null,
                          ),
                          const SizedBox(height: 16),
                          if (shouldShowKinderAngle(
                            _inputQualityText,
                            resultHint:
                                _completedCheckInToday!.selectedOptionId ??
                                'same',
                          ))
                            KinderAngleCard(
                              reflectionText: _inputQualityText,
                              resultHint:
                                  _completedCheckInToday!.selectedOptionId ??
                                  'same',
                              patternTitle:
                                  _completedCheckInToday!.patternTitle,
                              specificPrompt: _completedCheckInToday!.prompt,
                              languageCode: _languageCode,
                              compact: true,
                            )
                          else
                            PerspectiveShiftCard(
                              reflectionText: _inputQualityText,
                              resultHint:
                                  _completedCheckInToday!.selectedOptionId ??
                                  'same',
                              checkInQuestion: _completedCheckInToday!.question,
                              patternTitle:
                                  _completedCheckInToday!.patternTitle,
                              specificPrompt: _completedCheckInToday!.prompt,
                              languageCode: _languageCode,
                              compact: true,
                            ),
                          if (stack.showArchiveProofCards &&
                              _patternMemory != null) ...[
                            const SizedBox(height: 16),
                            PatternMemoryAfterSaveCard(
                              memory: _patternMemory!,
                              onUseNext:
                                  _patternNextAction == null &&
                                      !suppressPostResultNextCheckCompetitors
                                  ? () => _usePatternMemoryNext(_patternMemory!)
                                  : null,
                            ),
                          ],
                          if (stack.showArchiveProofCards &&
                              _patternProgress != null) ...[
                            const SizedBox(height: 16),
                            PatternProgressAfterSaveCard(
                              progress: _patternProgress!,
                            ),
                          ],
                          if (stack.showArchiveProofCards &&
                              _patternNextAction != null &&
                              !suppressPostResultNextCheckCompetitors) ...[
                            const SizedBox(height: 16),
                            PatternNextActionCard(
                              action: _patternNextAction!,
                              onUse: () =>
                                  _usePatternNextAction(_patternNextAction!),
                            ),
                          ],
                          if (stack.showArchiveProofCards &&
                              _habitProof != null &&
                              !suppressPostResultNextCheckCompetitors) ...[
                            const SizedBox(height: 16),
                            HabitProofCard(
                              proof: _habitProof!,
                              onKeepGoing: () =>
                                  _keepHabitProofGoing(_habitProof!),
                            ),
                          ],
                          if (stack.showArchiveProofCards &&
                              _weeklyRecap != null) ...[
                            const SizedBox(height: 16),
                            WeeklyPatternRecapCard(
                              recap: _weeklyRecap!,
                              onUseNext: suppressPostResultNextCheckCompetitors
                                  ? null
                                  : () => _useWeeklyRecapNext(_weeklyRecap!),
                            ),
                          ],
                          if (stack.showArchiveProofCards &&
                              _shareRecap != null) ...[
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => _copyShareRecap(_shareRecap!),
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                label: const Text('Copy recap'),
                              ),
                            ),
                          ],
                        ],
                        if (!stack.showInputQualityCoach &&
                            _tomorrowReturnLoop != null &&
                            !_returnDayJustClosed &&
                            !suppressNoisyFirstSaveCards &&
                            !suppressEarlyPatternClaimCards) ...[
                          if (_secondSessionComparison?.hasEnoughData ==
                              true) ...[
                            const SizedBox(height: 12),
                            SecondSessionComparisonCard(
                              comparison: _secondSessionComparison!,
                              onGoDeeper: () {
                                final prompt =
                                    _secondSessionComparison!.whatToTestNext;
                                if (prompt == null || prompt.isEmpty) return;
                                unawaited(_onSecondSessionEvidence(prompt));
                              },
                              onRecordNextEvidence: () {
                                final prompt =
                                    _secondSessionComparison!.whatToTestNext;
                                if (prompt == null || prompt.isEmpty) return;
                                unawaited(_onSecondSessionEvidence(prompt));
                              },
                              onNotTheSame: () => setState(
                                () => _secondSessionComparison = null,
                              ),
                            ),
                          ],
                          if (!_patternHypothesisDismissed &&
                              _patternHypothesis?.hasEnoughData == true) ...[
                            const SizedBox(height: 12),
                            PatternHypothesisCard(
                              hypothesis: _patternHypothesis!,
                              onFeelsRight: () async {
                                final selected =
                                    await SelectedSignalCoordinator.loadCurrent();
                                if (selected != null) {
                                  await SignalFeedbackCoordinator.track(
                                    action: PostSaveSignalAction.accepted,
                                    signalId: selected.id,
                                    signalTitle: selected.title,
                                    categoryId: selected.categoryId,
                                  );
                                }
                                if (!mounted) return;
                                setState(
                                  () => _patternHypothesisDismissed = true,
                                );
                              },
                              onNotMe: () async {
                                final selected =
                                    await SelectedSignalCoordinator.loadCurrent();
                                if (selected != null) {
                                  await SignalFeedbackCoordinator.track(
                                    action: PostSaveSignalAction.rejected,
                                    signalId: selected.id,
                                    signalTitle: selected.title,
                                    categoryId: selected.categoryId,
                                  );
                                }
                                if (!mounted) return;
                                setState(
                                  () => _patternHypothesisDismissed = true,
                                );
                              },
                              onRecordNext: () => _keepRecording(
                                nextEvidencePrompt:
                                    _patternHypothesis!.watchNext,
                              ),
                              onViewArchive: () =>
                                  context.go('/archive-belief'),
                            ),
                          ],
                          if (_postSavePattern != null) ...[
                            const SizedBox(height: 12),
                            PostSaveInsightChoiceCard(
                              pattern: _postSavePattern!,
                              entry: _lastSavedEntry,
                              priorEntries: _entriesAfterSave.length > 1
                                  ? _entriesAfterSave.sublist(1)
                                  : const [],
                              feedback: _postSaveInsightFeedback,
                              selectedSignal: _postSaveSelectedSignal,
                              audienceWedge: _audienceWedge,
                              activeLoop: _activeLoop,
                              reflectionCount: _entriesAfterSave.length.clamp(
                                1,
                                3,
                              ),
                              categoryRepeated:
                                  _secondSessionComparison?.possibleRepeat ==
                                  true,
                              entryId: _lastSavedEntry?.id,
                              onSaveSignal: (pattern) async {
                                if (_isFirstSessionPostSave) {
                                  final thread =
                                      await FirstSessionCoordinator.acceptForTomorrow(
                                        pattern,
                                        reflectionText:
                                            _lastSavedEntry?.transcript ?? '',
                                        sourceReflectionId: _lastSavedEntry?.id,
                                      );
                                  if (!mounted) return;
                                  if (TrialMode.enabled) {
                                    _watchForAcceptPending = false;
                                    await ActivationTracker.clearWatchForAcceptPending();
                                  }
                                  setState(() => _activePatternThread = thread);
                                }
                              },
                              onUsePrompt: _saveNextEvidencePrompt,
                              onRecordNext: _keepRecording,
                              onRecordNextEvidence: (prompt) =>
                                  _keepRecording(nextEvidencePrompt: prompt),
                              onViewPatterns: () =>
                                  context.go('/archive-belief'),
                            ),
                          ] else if (_isFirstSessionPostSave) ...[
                            const SizedBox(height: 12),
                            FirstReflectionResultCard(
                              onRecordAnother: _keepRecording,
                              onViewPatterns: () =>
                                  context.go('/archive-belief'),
                            ),
                          ] else ...[
                            if (_activePatternThread != null &&
                                _completedWatchForToday != null) ...[
                              const SizedBox(height: 12),
                              ActivePatternThreadCard(
                                thread: _activePatternThread!,
                                compact: true,
                              ),
                            ],
                            if (_completedWatchForToday != null) ...[
                              const SizedBox(height: 12),
                              WatchForResultCard(
                                completed: _completedWatchForToday!,
                                headline: ScreenshotMode.enabled
                                    ? ScreenshotSampleData
                                          .watchForCompletedHeadline
                                    : null,
                                body: ScreenshotMode.enabled
                                    ? ScreenshotSampleData.watchForCompletedBody
                                    : null,
                              ),
                            ],
                            if (_postSavePattern == null) ...[
                              const SizedBox(height: 12),
                              PotentialSignalsCard(
                                signals: _postSaveSignals(),
                                noticedToday: _tomorrowReturnLoop!.noticedToday,
                                showPatternHint:
                                    _postSaveShowsPossiblePattern(),
                              ),
                            ],
                            if (_firstThreeJourney != null &&
                                !_firstThreeJourney!.completed &&
                                _showFirstThreeJourneyOnRecord) ...[
                              const SizedBox(height: 12),
                              FirstThreeJourneyCard(
                                model: _firstThreeJourney!,
                                compact: true,
                              ),
                            ],
                            if (_showAdvancedRetentionPostSave) ...[
                              if (_returnComparison != null) ...[
                                const SizedBox(height: 12),
                                ReturnComparisonCard(
                                  comparison: _returnComparison!,
                                ),
                              ],
                              if (_returnStreak != null &&
                                  _journalEntryCount >= 2 &&
                                  _returnStreak!.currentStreakDays >= 2) ...[
                                const SizedBox(height: 12),
                                ReturnStreakCard(
                                  streak: _returnStreak!,
                                  showCta: false,
                                ),
                              ],
                            ],
                            const SizedBox(height: 12),
                            TomorrowReturnCard(loop: _tomorrowReturnLoop!),
                            if (_suggestedWatchForTomorrow != null) ...[
                              const SizedBox(height: 12),
                              WatchForTomorrowCard(
                                suggestion: _suggestedWatchForTomorrow!,
                                onChooseAnother: () {
                                  setState(() {
                                    _watchForAlternativeIndex =
                                        (_watchForAlternativeIndex + 1) % 3;
                                    _suggestedWatchForTomorrow =
                                        WatchForCoordinator.buildSuggestedWatchForAfterSave(
                                          entries: _entriesAfterSave,
                                          loop: _tomorrowReturnLoop,
                                          signals: _postSaveSignals(),
                                          alternativeIndex:
                                              _watchForAlternativeIndex,
                                        );
                                  });
                                },
                              ),
                            ],
                            if (_showAdvancedRetentionPostSave) ...[
                              const SizedBox(height: 16),
                              TomorrowCommitmentCard(
                                loop: _tomorrowReturnLoop!,
                              ),
                            ],
                          ],
                        ],
                      ],
                      if (_localSaveTitle != null && !_lastSavedEntryIsDegraded) ...[
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: VoiceMemoryColors.captureSuccess,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    localSaveTitle!,
                                    style: VoiceMemoryTypography.cardTitleStyle(
                                      color: VoiceMemoryColors.captureSuccess,
                                    ),
                                  ),
                                  if (syncNote != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      syncNote,
                                      style: const TextStyle(
                                        color: VoiceMemoryColors.textSecondary,
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          error,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 8),
                    ..._buildBottomActions(
                      context,
                      ui: ui,
                      canRecord: canRecord,
                      localSaveTitle: localSaveTitle,
                      selectedPrompt: _selectedPromptLine,
                      suppressDuplicateRecordCtas:
                          stack.suppressDuplicateRecordCtas,
                      policyMicPhase: policyMic,
                      policyUserDenied: policyUserDenied,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
            if (showCloseButton)
              const Align(
                alignment: Alignment.topRight,
                child: RecordScreenCloseButton(),
              ),
          ],
        ),
      ),
    );
  }

  void _resetPostSaveToReady() {
    setState(() {
      _error = null;
      _localSaveTitle = null;
      _syncNote = null;
      _showPostSaveLoop = false;
      _instantReflectionResponse = null;
      _immediateDiscovery = null;
      _immediateDiscoveryLoading = false;
      _ui = _uiForMicPhase(_mic);
    });
  }

  List<Widget> _buildPolicyPrimarySecondaryButtons(
    RecordCtaPolicyResolution policy, {
    VoidCallback? onPrimary,
    Key? primaryKey,
  }) {
    final widgets = <Widget>[];
    final primary = policy.primaryLabel;
    if (primary == null || !policy.showMainBottomCta) return widgets;

    widgets.add(
      SizedBox(
        height: 48,
        width: double.infinity,
        child: FilledButton(
          key: primaryKey,
          onPressed: onPrimary ?? _resetPostSaveToReady,
          child: Text(primary),
        ),
      ),
    );

    for (final (index, label) in policy.secondaryLabels.indexed) {
      widgets.add(const SizedBox(height: 8));
      widgets.add(
        SizedBox(
          height: 48,
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              if (label == ConsumerUiCopy.doneCta) {
                _resetPostSaveToReady();
                return;
              }
              if (label == VoiceCaptureCopy.recordAgainCta ||
                  label == ConsumerUiCopy.recordAnotherCta) {
                _resetPostSaveToReady();
                return;
              }
              _resetPostSaveToReady();
            },
            child: Text(label),
          ),
        ),
      );
    }
    return widgets;
  }

  List<Widget> _buildBottomActions(
    BuildContext context, {
    required RecordUiState ui,
    required bool canRecord,
    required String? localSaveTitle,
    String? selectedPrompt,
    required bool suppressDuplicateRecordCtas,
    RecordingPhase? policyMicPhase,
    bool? policyUserDenied,
  }) {
    RecordCtaPolicyResolution policyForUi() => _recordCtaPolicy(
      ui,
      micPhase: policyMicPhase,
      userDeniedThisSession: policyUserDenied,
    );
    final actions = <Widget>[];

    if (ui == RecordUiState.permissionBlocked) {
      return actions;
    }
    if (ui == RecordUiState.ready) {
      if (_showBottomRetentionCards) {
        // Invited User Welcome: replaces (never joins) the generic
        // first-session explainer for invited installs, so the pre-first-save
        // screen never gets more crowded. Only before the first save.
        final showInvitedWelcome =
            _invitedWelcomeSource != null && _journalEntryCount == 0;
        if (showInvitedWelcome) {
          actions.add(
            InvitedUserWelcomeCard(
              source: _invitedWelcomeSource!,
              onRecord: () => unawaited(_onRecordPressed(source: 'main')),
              onDismiss: () => setState(() => _invitedWelcomeSource = null),
            ),
          );
        }
        // Record once intro: zero saved entries only — one supporting line
        // and one record CTA. Leads the stack but never blocks recording.
        if (_showLegacyEmptyOnboarding &&
            !showInvitedWelcome &&
            RecordOnceIntroCard.shouldShow(_journalEntryCount)) {
          actions.add(
            RecordOnceIntroCard(
              onRecord: () => unawaited(_onRecordPressed(source: 'main')),
            ),
          );
        }
        // First-session explainer: brand-new users (no entries / no pressure
        // check-ins yet) get a clear, emotionally framed starting point.
        if (_showLegacyEmptyOnboarding &&
            !showInvitedWelcome &&
            FirstSessionExplanationCard.shouldShow(_journalEntryCount)) {
          actions.add(
            FirstSessionExplanationCard(
              onLogPressure: () => context.push('/pressure-check-in'),
              onRecord: () => unawaited(_onRecordPressed(source: 'main')),
            ),
          );
        }
        // First Save Rescue: a 10-second, deletable test recording for users
        // with an empty archive. One CTA into the existing recording flow —
        // sits alongside (never instead of) the explainer above.
        if (_showLegacyEmptyOnboarding &&
            FirstSaveRescueCard.shouldShow(_journalEntryCount)) {
          actions.add(
            FirstSaveRescueCard(
              onStart: () => unawaited(_onRecordPressed(source: 'main')),
            ),
          );
        }
        // First Recording Sample: one tiny editable starter sentence for an
        // empty archive. The CTA seeds the existing recording flow (the line
        // shows as the "Try saying" helper) — never a new flow, never a list.
        if (_showLegacyEmptyOnboarding &&
            FirstRecordingSampleCard.shouldShow(_journalEntryCount)) {
          actions.add(
            FirstRecordingSampleCard(
              onUseStarter: () =>
                  _onStartHereSelected(FirstRecordingSample.sample),
            ),
          );
        }
        if (RepeatRecordingNudgeGates.showSecondEntryNudge(
          entryCount: _journalEntryCount,
          justSaved: _recordReturnProJustSaved,
          hiddenThisSession: RepeatRecordingNudgeSession.secondEntryHidden,
        )) {
          actions.add(
            SecondEntryNudgeCard(
              source: 'record',
              onRecord: () => unawaited(_onRecordPressed(source: 'main')),
              onDismiss: () => setState(() {}),
            ),
          );
        }
        if (_showAhaMomentCards &&
            AhaMomentGates.shouldShow(
              candidate: _ahaCandidate,
              entryCount: _journalEntryCount,
            )) {
          actions.add(
            FirstAhaMomentCard(
              candidate: _ahaCandidate!,
              source: 'record',
              onChanged: () => setState(() {}),
            ),
          );
        }
        if (_showAhaMomentCards && AhaProofShareEligibility.shouldShow) {
          actions.add(
            AhaProofShareCard(
              entryCount: _journalEntryCount,
              source: 'record',
              onDismiss: () => setState(() {}),
            ),
          );
        }
        // Calm 2-day path: the plan before the first save, the return moment
        // on day 2, nothing once the loop is running. Passive — never blocks
        // recording.
        final twoDayPath = const TwoDayActivationEngine().build(
          entryCount: _journalEntryCount,
          entryDates: _entryDates,
        );
        if (twoDayPath.show && _showTwoDayActivationCard) {
          // Invited Day 2 return copy: the second visit matches the reason the
          // user was invited. Replaces (never joins) the generic Day 2 card so
          // the return moment never gets more crowded.
          if (InvitedDayTwoReturn.shouldShow(
            inviteSource: _inviteSource,
            stage: twoDayPath.stage,
          )) {
            actions.add(
              InvitedDayTwoReturnCard(
                source: _inviteSource!,
                entryCount: _journalEntryCount,
                onCheck: () => unawaited(_onRecordPressed(source: 'main')),
              ),
            );
          } else if (twoDayPath.stage == TwoDayActivationStage.dayTwoReturn &&
              RepeatRecordingNudgeGates.showDay2ReturnReason(
                entryCount: _journalEntryCount,
                twoDayPath: twoDayPath,
                hasRealChangeInsight: _hasRealChangeInsight,
                hiddenThisSession: RepeatRecordingNudgeSession.day2Hidden,
              )) {
            actions.add(
              Day2ReturnReasonCard(
                source: 'record',
                onRecord: () => unawaited(_onRecordPressed(source: 'main')),
                memoryOff: MemoryScopePolicy.scope == MemoryScope.off,
                onDismiss: () => setState(() {}),
              ),
            );
          } else if (twoDayPath.stage != TwoDayActivationStage.dayTwoReturn) {
            actions.add(TwoDayActivationCard(path: twoDayPath));
          }
        }
        // Change can begin: two or more entries, no real insight yet, and
        // the generic card has not been seen — passive, never blocks recording.
        if (_recordReturnProState != null &&
            RecordReturnProGates.showChangeCanBegin(
              entryCount: _journalEntryCount,
              changeStartSeen: _recordReturnProState!.changeStartSeen,
              hasRealChangeInsight: _hasRealChangeInsight,
            )) {
          actions.add(
            ChangeStartsCard(
              entryCount: _journalEntryCount,
              onViewArchive: () => context.go('/archive-belief'),
              onSearchArchive: () => context.go('/archive-belief'),
              onSeen: () => unawaited(_markChangeStartSeen()),
            ),
          );
        }
        // Day 7 continuity: after the Day 2 return (2+ entries), a calm note
        // on where the archive is — passive until the existing weekly review
        // is genuinely ready, then a single CTA into it. Never blocks
        // recording.
        final continuityLoop = const DaySevenContinuityEngine().build(
          entryCount: _journalEntryCount,
          hasWeeklyReview: _hasWeeklyReviewForContinuity,
        );
        if (continuityLoop.show) {
          actions.add(
            DaySevenContinuityCard(
              loop: continuityLoop,
              entryCount: _journalEntryCount,
              hasConnectedThread: _hasConnectedThreadForContinuity,
              onViewWeeklyReview: () => context.push('/pressure-insights'),
            ),
          );
        }
        // Compact return-trigger reminder for users who accepted it; never
        // shown alongside the first-session card.
        if (PressureReturnTriggerReminder.shouldShow(
          accepted: _returnTriggerAccepted,
          entryCount: _journalEntryCount,
        )) {
          actions.add(
            PressureReturnTriggerReminder(
              onLogPressure: () => context.push('/pressure-check-in'),
            ),
          );
        }
        actions.add(
          EntryDirectionStarters(
            selectedPrompt: _selectedPromptLine,
            onSelect: (prompt) {
              ActivationTracker.trackActivationStarterPromptSelected();
              setState(() => _selectedPromptLine = prompt);
            },
          ),
        );
        actions.add(const SizedBox(height: 8));
      }
      final readyPolicy = policyForUi();
      if (!_shouldPromoteMicCaptureActions(readyPolicy)) {
        actions.add(
          _buildCaptureEntryActions(
            context: context,
            selectedPrompt: selectedPrompt,
            policy: readyPolicy,
          ),
        );
      }
      if (_journalEntryCountReady && _journalEntryCount > 0) {
        actions.add(CleanSlatePromptSection(entryCount: _journalEntryCount));
        actions.add(EntryOptionsSection(entryCount: _journalEntryCount));
      }
      if (_purchaseIntentCue != null && _showBottomRetentionCards) {
        actions.add(
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: PurchaseIntentReturnCueCard(
              intent: _purchaseIntentCue!,
              onSeePro: () {
                final intent = _purchaseIntentCue!;
                setState(() => _purchaseIntentCue = null);
                context.push(
                  '/subscription',
                  extra: PaywallRouteArgs(
                    source:
                        PaywallSource.fromId(intent.source) ??
                        PaywallSource.generalPro,
                    sourceRoute: '/record',
                  ),
                );
              },
              onDismiss: () => setState(() => _purchaseIntentCue = null),
            ),
          ),
        );
      }
    }
    if (ui == RecordUiState.recording) {
      actions.add(
        SizedBox(
          height: 48,
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _stopAndProcess,
            icon: const Icon(Icons.stop),
            label: Text(policyForUi().primaryLabel ?? ConsumerUiCopy.stopRecordingCta),
          ),
        ),
      );
      // Still changeable while recording — the choice applies at save.
      if (_journalEntryCountReady && _journalEntryCount > 0) {
        actions.add(CleanSlatePromptSection(entryCount: _journalEntryCount));
        actions.add(EntryOptionsSection(entryCount: _journalEntryCount));
      }
    }
    // Fresh-entry receipt: only when the save carried "Treat this as new".
    if (ui == RecordUiState.done && TreatAsNew.lastSaveWasFresh) {
      actions.add(
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: FreshEntrySavedReceipt(),
        ),
      );
    }
    if (ui == RecordUiState.done &&
        EntryAboutnessSession.lastSaveWasNonPersonal) {
      actions.add(
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: NotAboutMeReceipt(),
        ),
      );
    }
    if (ui == RecordUiState.done &&
        MemorySurfacingSession.lastSaveWasDoNotSurface) {
      actions.add(
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: DoNotSurfaceReceipt(),
        ),
      );
    }
    if (ui == RecordUiState.done &&
        MemorySurfacingSession.lastSaveWasSensitive) {
      actions.add(
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: SensitiveSurfacingReceipt(),
        ),
      );
    }
    // Exact-evidence receipt: only when the save carried "Keep exact details".
    if (ui == RecordUiState.done && KeepExactDetails.lastSaveKeptExact) {
      actions.add(
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: ExactDetailsSavedReceipt(),
        ),
      );
    }
    if (ui == RecordUiState.done &&
        PreserveOriginalSession.lastSavePreservedOriginal) {
      actions.add(
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: CuratedMemoryReceipt(),
        ),
      );
    }
    if (ui == RecordUiState.done &&
        ArchiveTrustReceipt.shouldShow(entryCount: _journalEntryCount) &&
        !_lastSavedEntryIsDegraded) {
      actions.add(
        ArchivePrivateReceiptCard(
          entryCount: _journalEntryCount,
          source: 'record',
          onDismiss: () => setState(() {}),
        ),
      );
    }
    if (_showPostSaveLoop && _tomorrowReturnLoop != null) {
      actions.add(
        SizedBox(
          height: 48,
          width: double.infinity,
          child: FilledButton(
            onPressed: _keepRecording,
            child: const Text(ConsumerUiCopy.postSaveRecordAnotherReflection),
          ),
        ),
      );
    } else if (_showPostSaveLoop && _postSaveFollowUp != null) {
      actions.addAll([
        SizedBox(
          height: 48,
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _enoughForNow,
            child: const Text("That's enough for now"),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          width: double.infinity,
          child: FilledButton(
            onPressed: _keepRecording,
            child: const Text(ConsumerUiCopy.postSaveRecordAnotherReflection),
          ),
        ),
      ]);
    }
    if (ui == RecordUiState.done && !_showPostSaveLoop) {
      final policy = policyForUi();
      if (policy.state == RecordCtaPolicyState.postSaveDegraded) {
        actions.addAll(
          _buildPolicyPrimarySecondaryButtons(
            policy,
            primaryKey: const Key('post_save_type_what_you_said'),
            onPrimary: () => unawaited(_openTypedFallbackForLastVoiceEntry()),
          ),
        );
      } else if (policy.state == RecordCtaPolicyState.postSaveSuccess) {
        actions.addAll(_buildPolicyPrimarySecondaryButtons(policy));
      }
    }
    if (ui == RecordUiState.error) {
      actions.addAll(
        _buildPolicyPrimarySecondaryButtons(policyForUi()),
      );
    }
    if (!canRecord && ui == RecordUiState.idle) {
      actions.add(
        SizedBox(
          height: 48,
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _requestMic,
            child: const Text('Set up microphone'),
          ),
        ),
      );
    }
    return actions;
  }

  String _statusTextFor(RecordUiState ui, String? localSaveTitle) {
    switch (ui) {
      case RecordUiState.permissionBlocked:
        return MicrophonePermissionCopy.statusBlocked;
      case RecordUiState.requestingPermission:
        return 'Allowing microphone access';
      case RecordUiState.ready:
        return 'Ready to record';
      case RecordUiState.recording:
        return 'Recording';
      case RecordUiState.processing:
        return 'Processing';
      case RecordUiState.done:
        return localSaveTitle ?? 'Saved';
      default:
        return 'Recording';
    }
  }
}

/// Gentle post-save Pro nudge shown after a recording that started from a
/// daily suggestion. Dismissible, shows at most once per session, and never
/// appears for Pro users or before three saved entries.
class _SuggestionProNudgeCard extends StatelessWidget {
  const _SuggestionProNudgeCard({
    required this.onUnlock,
    required this.onDismiss,
  });

  final VoidCallback onUnlock;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('suggestion_pro_nudge_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Keep your daily archive prompts improving',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'ArchiveMe uses what you record to surface sharper things '
            'worth checking each day.',
            style: TextStyle(
              fontSize: 13,
              color: VoiceMemoryColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  // Compact override: the app-wide FilledButton theme is
                  // full-width, which cannot live inside this Row.
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: onUnlock,
                  child: const Text(
                    'Unlock Pro',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(onPressed: onDismiss, child: const Text('Not now')),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecordingStatusCard extends StatelessWidget {
  const _RecordingStatusCard({required this.seconds, required this.stageLabel});

  final int seconds;
  final String stageLabel;

  @override
  Widget build(BuildContext context) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    final timer =
        '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return Semantics(
      label: 'Recording in progress, $seconds seconds',
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: VoiceMemoryColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.18),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic, size: 44, color: VoiceMemoryColors.primaryIndigo),
            const SizedBox(height: 14),
            const IndigoCaptureWaveform(),
            const SizedBox(height: 12),
            Text(
              stageLabel.isEmpty ? 'Recording' : stageLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              timer,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap Stop and save when you are finished.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: VoiceMemoryColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
