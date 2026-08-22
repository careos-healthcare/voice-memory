import 'package:archiveme_mobile/features/tomorrow_return/check_in_reminder_service.dart';
import 'package:archiveme_mobile/features/tomorrow_return/local_check_in_reminder_backend_stub.dart';

/// Selects the local reminder backend for this build flavor.
LocalCheckInReminderBackend createLocalCheckInReminderBackend() =>
    LocalCheckInReminderBackend();
