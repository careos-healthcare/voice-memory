import 'package:flutter/foundation.dart';

/// In-memory dismiss for the current app session.
class EarlyArchiveReturnReminderSession {
  EarlyArchiveReturnReminderSession._();

  static var _dismissed = false;

  static bool get dismissedThisSession => _dismissed;

  static void dismiss() => _dismissed = true;

  static void resetSession() => _dismissed = false;

  @visibleForTesting
  static void resetForTest() => resetSession();
}
