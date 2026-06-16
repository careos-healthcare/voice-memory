import 'dart:async';

import '../activation/activation_tracker.dart';
import '../tomorrow_return/check_in_reminder_service.dart';
import '../tomorrow_return/tomorrow_check_in_model.dart';
import '../trial/trial_summary_engine.dart';
import '../trial/trial_summary_model.dart';

/// Schedules a reminder after the user locks in tomorrow's check from retention.
abstract class RetentionReminderCoordinator {
  RetentionReminderCoordinator._();

  static Future<void> maybeScheduleAfterNextCheckChosen(
    TomorrowCheckIn checkIn, {
    bool hasRoutineAnchor = false,
  }) async {
    try {
      final summary = await const TrialSummaryEngine().build();
      final ready = summary.reminderReadiness == ReminderReadiness.ready;
      if (!ready && !hasRoutineAnchor) return;

      final outcome = await CheckInReminderService.maybeScheduleForCheckIn(
        checkIn,
      );
      if (outcome == ReminderScheduleOutcome.scheduled) {
        unawaited(ActivationTracker.trackReminderScheduledFromRetention());
      }
    } catch (_) {
      // Fail softly when summary or backend is unavailable.
    }
  }
}
