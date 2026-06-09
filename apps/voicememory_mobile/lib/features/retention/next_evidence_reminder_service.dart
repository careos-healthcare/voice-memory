import '../../product/consumer_ui_copy.dart';
import '../../product/loop_mode_copy.dart';
import '../loop_mode/loop_mode_coordinator.dart';
import '../activation/activation_tracker.dart';
import '../tomorrow_return/check_in_reminder_service.dart';
import 'retention_metrics_tracker.dart';

/// Schedules a local reminder for the next evidence moment — no transcript.
abstract final class NextEvidenceReminderService {
  NextEvidenceReminderService._();

  static const _idPrefix = 'next_evidence_';

  static String bodyFor({String? prompt}) {
    final trimmed = prompt?.trim() ?? '';
    if (trimmed.isEmpty) {
      return ConsumerUiCopy.nextEvidenceReminderBodyDefault;
    }
    final short = trimmed.length > 72 ? '${trimmed.substring(0, 71)}…' : trimmed;
    return ConsumerUiCopy.nextEvidenceReminderBodyWithPrompt
        .replaceAll('{prompt}', short);
  }

  static Future<ReminderScheduleOutcome> schedule({
    required String journeyId,
    String? prompt,
    DateTime? when,
  }) async {
    if (!CheckInReminderService.backend.isAvailable) {
      ActivationTracker.trackReminderNotAvailable();
      return ReminderScheduleOutcome.notAvailable;
    }

    await CheckInReminderService.ensureInitialized();
    if (!CheckInReminderService.backend.isAvailable) {
      ActivationTracker.trackReminderNotAvailable();
      return ReminderScheduleOutcome.notAvailable;
    }

    ActivationTracker.trackReminderPermissionRequested();
    final granted = await CheckInReminderService.backend.requestPermission();
    if (!granted) {
      ActivationTracker.trackReminderPermissionDenied();
      return ReminderScheduleOutcome.permissionDenied;
    }
    ActivationTracker.trackReminderPermissionGranted();

    final scheduleWhen = when ?? DateTime.now().add(const Duration(hours: 20));
    final loop = await LoopModeCoordinator.loadActive();
    final title = loop?.isCapacityYes == true
        ? LoopModeCopy.capacityReminderNotificationTitle
        : loop?.isProveEnough == true
            ? LoopModeCopy.proveEnoughReminderNotificationTitle
            : ConsumerUiCopy.nextEvidenceReminderTitle;
    final body = loop?.isCapacityYes == true
        ? LoopModeCopy.capacityReminderNotificationBody
        : loop?.isProveEnough == true
            ? LoopModeCopy.proveEnoughReminderNotificationBody
            : bodyFor(prompt: prompt);
    await CheckInReminderService.backend.schedule(
      checkInId: '$_idPrefix$journeyId',
      title: title,
      body: body,
      when: scheduleWhen,
      payload: 'next_evidence:$journeyId',
    );
    ActivationTracker.trackReminderScheduled();
    await RetentionMetricsTracker.track(
      RetentionMetricsTracker.nextEvidenceReminderScheduled,
    );
    return ReminderScheduleOutcome.scheduled;
  }

  static Future<void> cancel(String journeyId) async {
    await CheckInReminderService.cancelCheckInReminder('$_idPrefix$journeyId');
  }
}
