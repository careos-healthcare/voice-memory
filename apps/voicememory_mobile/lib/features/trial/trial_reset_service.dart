import '../../services/app_services.dart';
import '../acquisition/acquisition_cohort_coordinator.dart';
import '../activation/activation_events_store.dart';
import '../activation/first_loop_activation_store.dart';
import '../activation/return_day_friction_store.dart';
import '../activation/first_pattern_correction_store.dart';
import '../activation/return_capture_metrics_store.dart';
import '../activation/watch_for_prompt_metrics_store.dart';
import '../first_session/pattern_correction_learning_store.dart';
import '../tomorrow_return/active_pattern_thread_store.dart';
import '../tomorrow_return/change_summary_store.dart';
import '../tomorrow_return/return_capture_store.dart';
import '../tomorrow_return/return_comparison_store.dart';
import '../tomorrow_return/return_streak_store.dart';
import '../tomorrow_return/tomorrow_commitment_store.dart';
import '../tomorrow_return/tomorrow_return_loop_store.dart';
import 'hook_diagnosis_store.dart';
import '../pattern_memory/habit_proof_store.dart';
import '../pattern_memory/pattern_memory_store.dart';
import '../pattern_memory/pattern_next_action_store.dart';
import '../pattern_memory/pattern_progress_store.dart';
import '../pattern_memory/weekly_pattern_recap_store.dart';
import '../tomorrow_return/check_in_reminder_service.dart';
import '../tomorrow_return/tomorrow_check_in_store.dart';
import '../tomorrow_return/watch_for_store.dart';
import '../objective/current_objective_snapshot_store.dart';
import '../objective/objective_widget_pending_route_store.dart';

/// Clears local trial participant state for a fresh 3-day run.
class TrialResetService {
  const TrialResetService();

  static const _trialFlagsKey = 'trial_session_flags';

  Future<void> resetForNewParticipant() async {
    final services = AppServices.instance;
    final prefs = services.prefs;

    await services.journalStore.file.writeAsString('[]');

    final watchStore = WatchForStore(prefs);
    await watchStore.writePending(null);
    await watchStore.writeLatestCompleted(null);
    await prefs.writeMap('watchForPending', {});
    await prefs.writeMap('watchForLatestCompleted', {});
    await prefs.writeMap('watchForHistory', {});

    await TomorrowCommitmentStore(prefs).write(null);
    await ReturnCaptureStore.instance().clear();
    await ReturnComparisonStore(prefs).write(null);
    await prefs.writeMap('returnComparisonHistory', {});
    await ReturnStreakStore(prefs).write(null);
    await ChangeSummaryStore(prefs).write(null);

    final threadStore = ActivePatternThreadStore(prefs);
    await threadStore.writeCurrent(null);
    await threadStore.writeLatestInactive(null);
    await prefs.writeMap('activePatternThreadHistory', {});

    await TomorrowReturnLoopStore(prefs).write(null);

    await TomorrowCheckInStore(prefs).clear();
    await PatternMemoryStore(prefs).clear();
    await PatternProgressStore(prefs).clear();
    await PatternNextActionStore(prefs).clear();
    await HabitProofStore(prefs).clear();
    await WeeklyPatternRecapStore(prefs).clear();
    await CheckInReminderService.setRemindersEnabled(false);
    await HookDiagnosisStore(prefs).clear();
    await ActivationEventsStore(prefs).clear();
    await FirstLoopActivationStore(prefs).clear();
    await ReturnDayFrictionStore(prefs).clear();
    await prefs.writeMap('activation_first_pattern_corrections', {'items': []});
    await prefs.writeMap('activation_watch_for_prompt_metrics', {});
    await prefs.writeMap('activation_return_capture_metrics', {});

    await PatternCorrectionLearningStore(prefs).clear();

    await CurrentObjectiveSnapshotStore(prefs).clear();
    await ObjectiveWidgetPendingRouteStore(prefs).clear();
    await AcquisitionCohortCoordinator.clear();

    await prefs.writeMap(_trialFlagsKey, {});
    await prefs.writeBool('trial_returned_next_day_logged', false);
    await prefs.writeBool('trial_first_reflection_logged', false);
    await prefs.writeBool('trial_second_reflection_logged', false);
    await prefs.writeBool('trial_third_reflection_logged', false);
    await prefs.writeBool('trial_app_opened_logged', false);
    await prefs.writeBool('trial_watch_for_pending_accept', false);
    await prefs.writeBool('trial_check_in_due_shown_logged', false);
  }
}
