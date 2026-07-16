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
    if (_skippedWatchPromptToday()) return false;
    return true;
  }

  /// Beta feedback surfaces stay off unless an explicit beta/developer flag is on.
  static bool showBetaFeedbackSurfaces() => ArchiveBetaMissionGate.isEnabled;

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
