import 'package:archiveme_mobile/features/tomorrow_return/check_in_reminder_service.dart';

/// Stub local-notification backend for V1 beta (`notifications = false`).
///
/// Plugin-backed implementation:
/// `experiments/archive/local_notifications/local_check_in_reminder_backend_impl.dart`
class LocalCheckInReminderBackend implements CheckInReminderBackend {
  LocalCheckInReminderBackend();

  static Object? sharedPlugin;
  static final List<void Function(Object response)> _responseHandlers = [];

  /// Called when the user taps a scheduled reminder (payload = checkInId).
  void Function(String payload)? onTapPayload;

  static void addResponseHandler(void Function(Object response) handler) {
    if (_responseHandlers.contains(handler)) return;
    _responseHandlers.add(handler);
  }

  static void resetResponseHandlersForTest() {
    _responseHandlers.clear();
    sharedPlugin = null;
  }

  @override
  bool get isAvailable => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> schedule({
    required String checkInId,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
  }) async {}

  @override
  Future<void> cancel(String checkInId) async {}

  @override
  Future<void> clearAll() async {}
}
