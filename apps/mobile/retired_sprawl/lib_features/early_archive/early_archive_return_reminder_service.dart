import 'package:archiveme_mobile/features/early_archive/early_archive_return_reminder_copy.dart';
import 'package:archiveme_mobile/features/early_archive/early_archive_return_reminder_store.dart';
import 'package:archiveme_mobile/features/tomorrow_return/check_in_reminder_service.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';

/// Schedules a lightweight local reminder for the next archive return.
abstract final class EarlyArchiveReturnReminderService {
  EarlyArchiveReturnReminderService._();

  static const _checkInId = 'early_archive_return';

  static Future<ReminderScheduleOutcome> schedule() async {
    await CheckInReminderService.ensureInitialized();
    if (!CheckInReminderService.backend.isAvailable) {
      return ReminderScheduleOutcome.notAvailable;
    }

    await CheckInReminderService.setRemindersEnabled(true);

    final granted = await CheckInReminderService.requestPermissionOnly();
    if (!granted) {
      return ReminderScheduleOutcome.permissionDenied;
    }

    final when = DateTime.now().add(const Duration(hours: 20));
    await CheckInReminderService.backend.schedule(
      checkInId: _checkInId,
      title: EarlyArchiveReturnReminderCopy.title,
      body: EarlyArchiveReturnReminderCopy.body,
      when: when,
      payload: _checkInId,
    );
    await EarlyArchiveReturnReminderStore.instance().markReminderSet();
    return ReminderScheduleOutcome.scheduled;
  }

  static String confirmationMessage(ReminderScheduleOutcome outcome) {
    return switch (outcome) {
      ReminderScheduleOutcome.scheduled =>
        ConsumerUiCopy.reminderSetConfirmation,
      ReminderScheduleOutcome.permissionDenied ||
      ReminderScheduleOutcome.notAvailable =>
        ConsumerUiCopy.reminderDeniedMessage,
      _ => ConsumerUiCopy.reminderDeniedMessage,
    };
  }
}