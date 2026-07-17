import '../app_review/archive_app_review_access_gate.dart';
import '../beta/archive_beta_mission_gate.dart';
import '../come_back_tomorrow/come_back_tomorrow_v2_store.dart';
import '../daily_archive_memory/daily_archive_memory_model.dart';
import '../low_friction_return/low_friction_return_engine.dart';

/// Presentation-only gates for returning Record with a grounded watch target.
abstract final class ReturningRecordWatchTargetUiGates {
  ReturningRecordWatchTargetUiGates._();

  /// One focused "Did this come back?" card instead of competing guidance.
  static bool showFocusedSurface({
    required bool showDailyArchiveMemory,
    required DailyArchiveMemoryResult? dailyArchiveMemory,
  }) {
    if (!showDailyArchiveMemory) return false;
    final memory = dailyArchiveMemory;
    if (memory == null || !memory.hasWatchTarget) return false;
    if (watchPromptSkippedToday()) return false;
    return true;
  }

  /// True after the user taps Not today on the watch-target card (today only).
  static bool watchPromptSkippedToday() => _skippedWatchPromptToday();

  /// Hide daily streak, homework, and program framing after Not today.
  static bool suppressDailyStreakPressureToday() => watchPromptSkippedToday();

  /// Beta Record surfaces only for explicit beta builds — never App Review.
  static bool showBetaRecordSurfaces() =>
      ArchiveBetaMissionGate.isEnabled &&
      !ArchiveAppReviewAccessGate.isEnabled;

  /// @deprecated Use [showBetaRecordSurfaces].
  static bool showBetaFeedbackSurfaces() => showBetaRecordSurfaces();

  /// Hide map prompt, reassurance helper, next-action line, and entry options.
  static bool suppressCompetingReadyGuidance({
    required bool showFocusedSurface,
  }) =>
      showFocusedSurface;

  /// Hide the full archive education / proof stack below the watch card.
  static bool suppressArchiveEducationStack({
    required bool showFocusedSurface,
  }) =>
      showFocusedSurface;

  static bool _skippedWatchPromptToday() {
    if (LowFrictionReturnStore.isDismissedToday) return true;
    final active = ComeBackTomorrowV2Store.active;
    if (active == null) return false;
    if (active.lastResponseType != 'not_today') return false;
    final answered = active.lastAnsweredDateKey;
    if (answered == null || answered.isEmpty) return false;
    return answered == _todayUtcKey();
  }

  static String _todayUtcKey() {
    final now = DateTime.now().toUtc();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}
