import 'action_plan_models.dart';
import '../tomorrow_return/check_in_reminder_service.dart';

/// Platform-neutral reminder boundary. The domain only controls lifecycle;
/// notification permissions, times, and platform APIs stay in an adapter.
abstract interface class ActionPlanReminderScheduler {
  Future<void> schedule(ActionPlan plan, MicroHabitStep step);

  Future<void> cancel(String stepId);
}

/// Deterministic scheduler for domain and integration tests.
final class FakeActionPlanReminderScheduler
    implements ActionPlanReminderScheduler {
  final Map<String, ({ActionPlan plan, MicroHabitStep step})> scheduled = {};
  final List<String> cancelled = [];

  @override
  Future<void> schedule(ActionPlan plan, MicroHabitStep step) async {
    scheduled[step.id] = (plan: plan, step: step);
  }

  @override
  Future<void> cancel(String stepId) async {
    scheduled.remove(stepId);
    cancelled.add(stepId);
  }
}

final class NoopActionPlanReminderScheduler
    implements ActionPlanReminderScheduler {
  const NoopActionPlanReminderScheduler();

  @override
  Future<void> cancel(String stepId) async {}

  @override
  Future<void> schedule(ActionPlan plan, MicroHabitStep step) async {}
}

/// Schedules privacy-safe, one-shot local reminders for the next planned day.
///
/// The notification deliberately omits the plan and habit text so private
/// behavioral context is not exposed on a locked screen.
final class LocalActionPlanReminderScheduler
    implements ActionPlanReminderScheduler {
  LocalActionPlanReminderScheduler({DateTime Function()? clock, this.hour = 9})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final int hour;
  bool? _permissionGranted;

  @override
  Future<void> schedule(ActionPlan plan, MicroHabitStep step) async {
    await CheckInReminderService.ensureInitialized();
    final backend = CheckInReminderService.backend;
    if (!backend.isAvailable) return;
    _permissionGranted ??= await backend.requestPermission();
    if (!_permissionGranted!) return;
    final now = _clock();
    var day = DateTime(now.year, now.month, now.day, hour);
    if (!day.isAfter(now)) day = day.add(const Duration(days: 1));
    while (!step.frequency.isScheduled(day)) {
      day = day.add(const Duration(days: 1));
    }
    await backend.schedule(
      checkInId: _notificationId(step.id),
      title: 'A small step is ready',
      body: 'Open ArchiveMe when you are ready.',
      when: day,
      payload: 'action_plan_checkin_v1:${step.id}',
    );
  }

  @override
  Future<void> cancel(String stepId) async {
    final backend = CheckInReminderService.backend;
    if (backend.isAvailable) await backend.cancel(_notificationId(stepId));
  }

  static String _notificationId(String stepId) => 'action-plan:$stepId';
}
