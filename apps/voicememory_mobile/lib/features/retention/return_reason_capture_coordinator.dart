import '../signal_journey/signal_journey_coordinator.dart';
import 'return_reason_capture_store.dart';

/// Records how users return for additional evidence moments.
abstract final class ReturnReasonCaptureCoordinator {
  ReturnReasonCaptureCoordinator._();

  static Future<void> onReflectionSaved({
    required int eligibleCount,
    required DateTime? lastReflectionAt,
  }) async {
    if (eligibleCount < 2) return;
    final pending = await ReturnReasonCaptureStore.instance().consumePending();
    final source = pending ?? ReturnSourceKind.manual;
    final journey = await SignalJourneyCoordinator.loadActive();
    var hours = 0;
    if (lastReflectionAt != null) {
      hours = DateTime.now().difference(lastReflectionAt).inHours.clamp(0, 9999);
    }
    await ReturnReasonCaptureStore.instance().recordReturn(
      source: source,
      activeJourneyAtReturn: journey?.isActive == true,
      timeSinceLastMomentHours: hours,
      reflectionCountAfter: eligibleCount,
    );
  }

  static Future<void> markOpenedFromReminder() =>
      ReturnReasonCaptureStore.instance().markPendingReminder();

  static Future<void> markOpenedFromObjective() =>
      ReturnReasonCaptureStore.instance().markPendingWidgetOrObjective();
}
