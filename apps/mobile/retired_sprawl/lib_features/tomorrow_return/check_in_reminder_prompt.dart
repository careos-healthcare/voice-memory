import 'package:archiveme_mobile/features/tomorrow_return/check_in_reminder_service.dart';
import 'package:archiveme_mobile/features/tomorrow_return/tomorrow_check_in_model.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:flutter/material.dart';

/// Soft-ask flow for tomorrow check-in reminders.
///
/// Shown only after the user has chosen tomorrow's check, never on launch.
abstract class CheckInReminderPrompt {
  CheckInReminderPrompt._();

  /// Asks the user if they want a reminder, then schedules one if they agree
  /// and permission is granted. Returns the schedule outcome (or null if the
  /// user declined the soft ask). Never throws.
  static Future<ReminderScheduleOutcome?> ask(
    BuildContext context,
    TomorrowCheckIn checkIn,
  ) async {
    final wants = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(ConsumerUiCopy.reminderSoftAskTitle),
        content: const Text(ConsumerUiCopy.reminderSoftAskBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(ConsumerUiCopy.reminderSoftAskNotNowCta),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(ConsumerUiCopy.reminderSoftAskRemindCta),
          ),
        ],
      ),
    );

    if (wants != true) return null;

    await CheckInReminderService.setRemindersEnabled(true);
    final outcome =
        await CheckInReminderService.scheduleTomorrowCheckInReminder(checkIn);

    if (!context.mounted) return outcome;
    final messenger = ScaffoldMessenger.of(context);
    if (outcome == ReminderScheduleOutcome.scheduled) {
      messenger.showSnackBar(
        const SnackBar(content: Text(ConsumerUiCopy.reminderSetConfirmation)),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text(ConsumerUiCopy.reminderDeniedMessage)),
      );
    }
    return outcome;
  }
}