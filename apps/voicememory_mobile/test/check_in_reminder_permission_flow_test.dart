import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/tomorrow_return/check_in_reminder_prompt.dart';
import 'package:voicememory_mobile/features/tomorrow_return/check_in_reminder_service.dart';
import 'package:voicememory_mobile/features/tomorrow_return/tomorrow_check_in_coordinator.dart';
import 'package:voicememory_mobile/features/tomorrow_return/tomorrow_check_in_model.dart';
import 'package:voicememory_mobile/features/trial/trial_reset_service.dart';
import 'package:voicememory_mobile/services/app_services.dart';

/// Every case is bounded so this suite can never hang silently again.
const _guard = Timeout(Duration(seconds: 10));

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_reminder_flow_journal_$stamp.json',
    prefsPath: '/tmp/vm_reminder_flow_prefs_$stamp.json',
  );
}

String _stamp() => DateTime.now().microsecondsSinceEpoch.toString();

TomorrowCheckIn _checkIn() => TomorrowCheckIn(
      id: 'tci1',
      createdAt: DateTime(2026, 5, 25),
      targetDate: '2026-05-26',
      patternTitle: 'Pattern',
      prompt: 'Tomorrow, check whether this pattern shows up again.',
      question: 'Did this pattern show up again?',
      options: kDefaultTomorrowCheckInOptions,
    );

/// Deterministic, fully in-memory reminder backend. Never touches the platform.
class _FakeBackend implements CheckInReminderBackend {
  _FakeBackend({
    this.available = true,
    this.permission = true,
    this.scheduleThrows = false,
  });

  final bool available;
  final bool permission;
  final bool scheduleThrows;

  int initializeCalls = 0;
  int permissionCalls = 0;
  int scheduleCalls = 0;
  int cancelCalls = 0;
  int clearAllCalls = 0;
  String? lastPayload;

  @override
  bool get isAvailable => available;

  @override
  Future<void> initialize() async => initializeCalls++;

  @override
  Future<bool> requestPermission() async {
    permissionCalls++;
    return permission;
  }

  @override
  Future<void> schedule({
    required String checkInId,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
  }) async {
    if (scheduleThrows) throw StateError('schedule failed');
    scheduleCalls++;
    lastPayload = payload;
  }

  @override
  Future<void> cancel(String checkInId) async => cancelCalls++;

  @override
  Future<void> clearAll() async => clearAllCalls++;
}

void main() {
  tearDown(CheckInReminderService.resetBackendForTest);

  group('reminder permission flow (service-level, no platform)', () {
    test('granted permission schedules a reminder', () async {
      await _reset(_stamp());
      final backend = _FakeBackend();
      CheckInReminderService.setBackendForTest(backend);
      await CheckInReminderService.setRemindersEnabled(true);

      final outcome =
          await CheckInReminderService.scheduleTomorrowCheckInReminder(
        _checkIn(),
      );

      expect(outcome, ReminderScheduleOutcome.scheduled);
      expect(backend.permissionCalls, 1);
      expect(backend.scheduleCalls, 1);
      expect(backend.lastPayload, 'tci1');
    }, timeout: _guard);

    test('denied permission does not block check-in creation', () async {
      await _reset(_stamp());
      final backend = _FakeBackend(permission: false);
      CheckInReminderService.setBackendForTest(backend);
      await CheckInReminderService.setRemindersEnabled(true);

      // Scheduling is declined gracefully, never throws.
      final outcome =
          await CheckInReminderService.scheduleTomorrowCheckInReminder(
        _checkIn(),
      );
      expect(outcome, ReminderScheduleOutcome.permissionDenied);
      expect(backend.scheduleCalls, 0);

      // The check-in is still created even though permission was denied.
      final created = await TomorrowCheckInCoordinator.createForTomorrow(
        patternTitle: 'Pattern',
        specificPrompt: 'Notice',
      );
      expect(created.id, isNotEmpty);
    }, timeout: _guard);

    test('unavailable backend does not crash', () async {
      await _reset(_stamp());
      final backend = _FakeBackend(available: false);
      CheckInReminderService.setBackendForTest(backend);
      await CheckInReminderService.setRemindersEnabled(true);

      final outcome =
          await CheckInReminderService.scheduleTomorrowCheckInReminder(
        _checkIn(),
      );
      expect(outcome, ReminderScheduleOutcome.notAvailable);
      expect(backend.permissionCalls, 0);
      expect(backend.scheduleCalls, 0);

      // Cancel / clear are also safe no-ops on an unavailable backend.
      await CheckInReminderService.cancelCheckInReminder('tci1');
      await CheckInReminderService.clearAll();
      expect(backend.cancelCalls, 0);
      expect(backend.clearAllCalls, 0);
    }, timeout: _guard);

    test('reminders disabled prevents scheduling', () async {
      await _reset(_stamp());
      final backend = _FakeBackend();
      CheckInReminderService.setBackendForTest(backend);
      // Reminders left disabled (the default).

      final outcome =
          await CheckInReminderService.scheduleTomorrowCheckInReminder(
        _checkIn(),
      );
      expect(outcome, ReminderScheduleOutcome.disabled);
      expect(backend.permissionCalls, 0);
      expect(backend.scheduleCalls, 0);
    }, timeout: _guard);

    test('completed check-in cancels the reminder', () async {
      await _reset(_stamp());
      final backend = _FakeBackend();
      CheckInReminderService.setBackendForTest(backend);
      await CheckInReminderService.setRemindersEnabled(true);

      final today = DateTime(2026, 6, 4, 9);
      final yesterday = today.subtract(const Duration(days: 1));

      final checkIn = await TomorrowCheckInCoordinator.createForTomorrow(
        patternTitle: 'Pattern',
        specificPrompt: 'Notice',
        now: yesterday,
      );
      await TomorrowCheckInCoordinator.selectOption(
        checkInId: checkIn.id,
        optionId: 'lighter',
      );
      await TomorrowCheckInCoordinator.completeAfterSave(
        entries: const [],
        now: today,
      );

      // Completion cancels the reminder fire-and-forget; let it flush.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(backend.cancelCalls, greaterThanOrEqualTo(1));
    }, timeout: _guard);

    test('reset clears scheduled reminders', () async {
      await _reset(_stamp());
      final backend = _FakeBackend();
      CheckInReminderService.setBackendForTest(backend);

      await const TrialResetService().resetForNewParticipant();

      expect(backend.clearAllCalls, greaterThanOrEqualTo(1));
    }, timeout: _guard);

    test('a failing schedule fails fast and never hangs', () async {
      await _reset(_stamp());
      CheckInReminderService.setBackendForTest(
        _FakeBackend(scheduleThrows: true),
      );
      await CheckInReminderService.setRemindersEnabled(true);

      await expectLater(
        CheckInReminderService.scheduleTomorrowCheckInReminder(_checkIn()),
        throwsA(isA<StateError>()),
      );
    }, timeout: _guard);
  });

  group('reminder soft-ask (bounded widget smoke test)', () {
    // Renders the real soft-ask dialog with bounded pumps only — never
    // pumpAndSettle — and drives the decline path, which stays entirely in the
    // fake-async zone (no platform calls, no prefs I/O, no SnackBar timer).
    // The granted/scheduling path is covered deterministically by the
    // service-level tests above, which avoids mixing real file I/O with the
    // widget-test fake clock.
    testWidgets('soft-ask dialog renders and Not now declines without '
        'scheduling', (tester) async {
      final backend = _FakeBackend();
      CheckInReminderService.setBackendForTest(backend);

      ReminderScheduleOutcome? outcome;
      var returned = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  outcome = await CheckInReminderPrompt.ask(context, _checkIn());
                  returned = true;
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Want a reminder tomorrow?'), findsOneWidget);
      expect(find.text('Remind me'), findsOneWidget);

      await tester.tap(find.text('Not now'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(returned, isTrue);
      expect(outcome, isNull);
      expect(backend.scheduleCalls, 0);
      expect(backend.permissionCalls, 0);
    }, timeout: _guard);
  });
}
