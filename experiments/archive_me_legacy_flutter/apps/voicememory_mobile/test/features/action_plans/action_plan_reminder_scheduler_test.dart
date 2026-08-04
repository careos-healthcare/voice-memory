import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/action_plans/action_plan_models.dart';
import 'package:voicememory_mobile/features/action_plans/action_plan_reminder_scheduler.dart';
import 'package:voicememory_mobile/features/tomorrow_return/check_in_reminder_service.dart';

void main() {
  tearDown(CheckInReminderService.resetBackendForTest);

  test(
    'local scheduler uses generic namespaced notification on next custom day',
    () async {
      final backend = _FakeReminderBackend();
      CheckInReminderService.setBackendForTest(backend);
      final scheduler = LocalActionPlanReminderScheduler(
        clock: () => DateTime(2026, 7, 24, 10), // Friday after reminder time.
      );
      final plan = _plan(
        title: 'Private anxiety recovery plan',
        targetOutcome: 'Discuss a private relationship',
        frequency: ActionPlanFrequency.customDays({
          DateTime.monday,
          DateTime.wednesday,
        }),
      );

      await scheduler.schedule(plan, plan.steps.single);

      expect(backend.permissionRequests, 1);
      expect(backend.scheduled, hasLength(1));
      final reminder = backend.scheduled.single;
      expect(reminder.checkInId, 'action-plan:private-step-id');
      expect(reminder.payload, 'action_plan_checkin_v1:private-step-id');
      expect(reminder.when, DateTime(2026, 7, 27, 9));
      expect(reminder.title, 'A small step is ready');
      expect(reminder.body, 'Open ArchiveMe when you are ready.');
      final visibleText = '${reminder.title} ${reminder.body}';
      expect(visibleText, isNot(contains(plan.title)));
      expect(visibleText, isNot(contains(plan.targetOutcome)));
      expect(visibleText, isNot(contains(plan.steps.single.title)));

      await scheduler.cancel(plan.steps.single.id);
      expect(backend.cancelled, ['action-plan:private-step-id']);
    },
  );
}

typedef _ScheduledReminder = ({
  String checkInId,
  String title,
  String body,
  DateTime when,
  String payload,
});

final class _FakeReminderBackend implements CheckInReminderBackend {
  int permissionRequests = 0;
  final List<_ScheduledReminder> scheduled = [];
  final List<String> cancelled = [];

  @override
  bool get isAvailable => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return true;
  }

  @override
  Future<void> schedule({
    required String checkInId,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
  }) async {
    scheduled.add((
      checkInId: checkInId,
      title: title,
      body: body,
      when: when,
      payload: payload,
    ));
  }

  @override
  Future<void> cancel(String checkInId) async {
    cancelled.add(checkInId);
  }

  @override
  Future<void> clearAll() async {}
}

ActionPlan _plan({
  required String title,
  required String targetOutcome,
  required ActionPlanFrequency frequency,
}) => ActionPlan(
  id: 'private-plan-id',
  clusterId: 'private-cluster-id',
  title: title,
  targetOutcome: targetOutcome,
  createdAt: DateTime.utc(2026, 7, 1),
  steps: [
    MicroHabitStep(
      id: 'private-step-id',
      planId: 'private-plan-id',
      title: 'Call a private person',
      frequency: frequency,
      targetNodeId: 'private-node-id',
    ),
  ],
);
