import 'package:archiveme_mobile/features/activation/activation_events_store.dart';
import 'package:archiveme_mobile/features/tomorrow_return/check_in_reminder_service.dart';
import 'package:archiveme_mobile/features/tomorrow_return/tomorrow_check_in_model.dart';
import 'package:archiveme_mobile/features/trial/hook_diagnosis_model.dart';
import 'package:archiveme_mobile/features/trial/hook_diagnosis_store.dart';
import 'package:archiveme_mobile/features/trial/trial_reset_service.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_reminder_journal_$stamp.json',
    prefsPath: '/tmp/vm_reminder_prefs_$stamp.json',
  );
}

TomorrowCheckIn _checkIn() => TomorrowCheckIn(
  id: 'tci1',
  createdAt: DateTime(2026, 5, 25),
  targetDate: '2026-05-26',
  patternTitle: 'Pattern',
  prompt: 'Tomorrow, check whether this pattern shows up again.',
  question: 'Did this pattern show up again?',
  options: kDefaultTomorrowCheckInOptions,
);

/// Fake backend that reports as available and records calls.
class _FakeBackend implements CheckInReminderBackend {
  _FakeBackend({this.permission = true});

  final bool permission;
  int scheduleCalls = 0;
  int cancelCalls = 0;
  int clearAllCalls = 0;
  String? lastPayload;

  @override
  bool get isAvailable => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<void> schedule({
    required String checkInId,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
  }) async {
    scheduleCalls++;
    lastPayload = payload;
  }

  @override
  Future<void> cancel(String checkInId) async {
    cancelCalls++;
  }

  @override
  Future<void> clearAll() async {
    clearAllCalls++;
  }
}

/// Makes the trial summary report reminders as ready.
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

  test('reminder copy is consumer friendly', () {
    expect(CheckInReminderService.reminderTitle, 'Your check is ready');
    expect(
      CheckInReminderService.reminderBody,
      'Answer the check you chose yesterday.',
    );
  });

  test('no-op backend records fallback and never crashes', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);

    expect(CheckInReminderService.pluginAvailable, isFalse);
    await CheckInReminderService.setRemindersEnabled(true);

    final scheduled =
        await CheckInReminderService.scheduleTomorrowCheckInReminder(
          _checkIn(),
        );
    expect(scheduled, ReminderScheduleOutcome.notAvailable);

    await CheckInReminderService.cancelCheckInReminder('tci1');
    await CheckInReminderService.clearAll();
  });

  test('not ready does not schedule', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    CheckInReminderService.setBackendForTest(_FakeBackend());

    final maybe = await CheckInReminderService.maybeScheduleForCheckIn(
      _checkIn(),
    );
    expect(maybe, ReminderScheduleOutcome.notGated);
  });

  test('ready schedules only when reminders are enabled', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await _makeReady();
    final backend = _FakeBackend();
    CheckInReminderService.setBackendForTest(backend);
    await CheckInReminderService.setRemindersEnabled(true);

    final outcome = await CheckInReminderService.maybeScheduleForCheckIn(
      _checkIn(),
    );

    expect(outcome, ReminderScheduleOutcome.scheduled);
    expect(backend.scheduleCalls, 1);
    expect(backend.lastPayload, 'tci1');
  });

  test('does not schedule when reminders are disabled', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await _makeReady();
    final backend = _FakeBackend();
    CheckInReminderService.setBackendForTest(backend);
    // Reminders left disabled (the default).

    final outcome = await CheckInReminderService.maybeScheduleForCheckIn(
      _checkIn(),
    );

    expect(outcome, ReminderScheduleOutcome.disabled);
    expect(backend.scheduleCalls, 0);
  });

  test('denied permission records permissionDenied', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await _makeReady();
    CheckInReminderService.setBackendForTest(_FakeBackend(permission: false));
    await CheckInReminderService.setRemindersEnabled(true);

    final outcome = await CheckInReminderService.maybeScheduleForCheckIn(
      _checkIn(),
    );

    expect(outcome, ReminderScheduleOutcome.permissionDenied);
  });

  test('ready stays no-op when plugin unavailable', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await _makeReady();
    await CheckInReminderService.setRemindersEnabled(true);
    // Default no-op backend.

    final outcome = await CheckInReminderService.maybeScheduleForCheckIn(
      _checkIn(),
    );
    expect(outcome, ReminderScheduleOutcome.notAvailable);
  });

  test('trial reset clears scheduled reminders', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final backend = _FakeBackend();
    CheckInReminderService.setBackendForTest(backend);

    await const TrialResetService().resetForNewParticipant();

    expect(backend.clearAllCalls, greaterThanOrEqualTo(1));
  });
}