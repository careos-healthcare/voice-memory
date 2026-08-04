import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/activation_events_store.dart';
import 'package:voicememory_mobile/features/retention/retention_reminder_coordinator.dart';
import 'package:voicememory_mobile/features/tomorrow_return/check_in_reminder_service.dart';
import 'package:voicememory_mobile/features/tomorrow_return/tomorrow_check_in_model.dart';
import 'package:voicememory_mobile/features/trial/hook_diagnosis_model.dart';
import 'package:voicememory_mobile/features/trial/hook_diagnosis_store.dart';
import 'package:voicememory_mobile/services/app_services.dart';

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_ret_rem_journal_$stamp.json',
    prefsPath: '/tmp/vm_ret_rem_prefs_$stamp.json',
  );
}

TomorrowCheckIn _checkIn() => TomorrowCheckIn(
  id: 'tci-ret',
  createdAt: DateTime(2026, 5, 25),
  targetDate: '2026-05-26',
  patternTitle: 'Pattern',
  prompt: 'Tomorrow, check whether this pattern shows up again.',
  question: 'What happens right before it shows up?',
  options: kDefaultTomorrowCheckInOptions,
);

class _FakeBackend implements CheckInReminderBackend {
  int scheduleCalls = 0;

  @override
  bool get isAvailable => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> schedule({
    required String checkInId,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
  }) async {
    scheduleCalls++;
  }

  @override
  Future<void> cancel(String checkInId) async {}

  @override
  Future<void> clearAll() async {}
}

Future<void> _makeReady() async {
  final prefs = AppServices.instance.prefs;
  await ActivationEventsStore(prefs).write(
    const ActivationEventCounts(
      firstReflectionSaved: 1,
      tomorrowCheckInCreated: 2,
    ),
  );
  final hook = HookDiagnosisStore(prefs);
  await hook.append(
    HookDiagnosisEvent(
      id: 'q1',
      createdAt: DateTime(2026, 5, 26),
      type: HookDiagnosisEventType.checkInQuestionRated,
      rating: HookDiagnosisRating.yes,
    ),
  );
  await hook.append(
    HookDiagnosisEvent(
      id: 'q2',
      createdAt: DateTime(2026, 5, 26),
      type: HookDiagnosisEventType.checkInQuestionRated,
      rating: HookDiagnosisRating.sortOf,
    ),
  );
}

void main() {
  tearDown(CheckInReminderService.resetBackendForTest);

  test('schedules when readiness is ready and routine anchor exists', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await _makeReady();
    final backend = _FakeBackend();
    CheckInReminderService.setBackendForTest(backend);
    await CheckInReminderService.setRemindersEnabled(true);

    await RetentionReminderCoordinator.maybeScheduleAfterNextCheckChosen(
      _checkIn(),
      hasRoutineAnchor: true,
    );

    expect(backend.scheduleCalls, 1);
  });

  test('does not schedule without readiness or anchor', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final backend = _FakeBackend();
    CheckInReminderService.setBackendForTest(backend);
    await CheckInReminderService.setRemindersEnabled(true);

    await RetentionReminderCoordinator.maybeScheduleAfterNextCheckChosen(
      _checkIn(),
      hasRoutineAnchor: false,
    );

    expect(backend.scheduleCalls, 0);
  });

  test('denied permission does not throw from coordinator', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await _makeReady();
    CheckInReminderService.setBackendForTest(_FakeBackendDenied());
    await CheckInReminderService.setRemindersEnabled(true);

    await expectLater(
      RetentionReminderCoordinator.maybeScheduleAfterNextCheckChosen(
        _checkIn(),
        hasRoutineAnchor: true,
      ),
      completes,
    );
  });
}

class _FakeBackendDenied implements CheckInReminderBackend {
  @override
  bool get isAvailable => true;

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
