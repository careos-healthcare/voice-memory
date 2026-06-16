import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/activation_events_store.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_memory_coordinator.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_memory_model.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_memory_store.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_next_action_model.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_next_action_store.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_progress_model.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_progress_store.dart';
import 'package:voicememory_mobile/features/tomorrow_return/check_in_reminder_service.dart';
import 'package:voicememory_mobile/features/tomorrow_return/tomorrow_check_in_coordinator.dart';
import 'package:voicememory_mobile/features/tomorrow_return/tomorrow_check_in_model.dart';
import 'package:voicememory_mobile/services/app_services.dart';

class _FakeBackend implements CheckInReminderBackend {
  int scheduleCalls = 0;
  int cancelCalls = 0;

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
  Future<void> cancel(String checkInId) async {
    cancelCalls++;
  }

  @override
  Future<void> clearAll() async {}
}

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_tci_coord_journal_$stamp.json',
    prefsPath: '/tmp/vm_tci_coord_prefs_$stamp.json',
  );
}

void main() {
  tearDown(CheckInReminderService.resetBackendForTest);

  test('reminder is cancelled when the check-in is completed', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
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

    // The fire-and-forget cancel runs after completion.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(backend.cancelCalls, greaterThanOrEqualTo(1));
  });

  test('fallback question when checkInQuestion empty', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final checkIn = await TomorrowCheckInCoordinator.createForTomorrow(
      patternTitle: 'Test',
      specificPrompt: 'Notice',
      checkInQuestion: '',
    );
    expect(checkIn.question, 'Did this pattern show up again?');
    expect(checkIn.prompt, contains('Tomorrow'));
    final events = await ActivationEventsStore(
      AppServices.instance.prefs,
    ).read();
    expect(events.tomorrowCheckInCreated, 1);
  });

  test('completing a check-in builds a pattern memory thread', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final today = DateTime(2026, 6, 4, 9);
    final yesterday = today.subtract(const Duration(days: 1));

    final checkIn = await TomorrowCheckInCoordinator.createForTomorrow(
      patternTitle: 'Taking responsibility before asking for help',
      specificPrompt: 'Notice',
      now: yesterday,
    );
    await TomorrowCheckInCoordinator.selectOption(
      checkInId: checkIn.id,
      optionId: 'lighter',
    );
    final completed = await TomorrowCheckInCoordinator.completeAfterSave(
      entries: const [],
      now: today,
    );
    expect(completed, isNotNull);

    final memory = await PatternMemoryStore(
      AppServices.instance.prefs,
    ).loadActive();
    expect(memory, isNotNull);
    expect(memory!.checkInCount, 1);
    expect(memory.lastResult, PatternMemoryResultHint.lighter);
    expect(memory.status, PatternMemoryStatus.forming);

    // Metrics are tracked fire-and-forget; let the write flush.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final events = await ActivationEventsStore(
      AppServices.instance.prefs,
    ).read();
    expect(events.patternMemoryCreated, 1);
  });

  TomorrowCheckIn _completed(String optionId, int day) => TomorrowCheckIn(
    id: 'tci_$day',
    createdAt: DateTime(2026, 6, day),
    targetDate: '2026-06-0$day',
    patternTitle: 'Taking responsibility before asking for help',
    prompt: 'Tomorrow, check whether this pattern shows up again.',
    question: 'Did this pattern show up again?',
    options: kDefaultTomorrowCheckInOptions,
    selectedOptionId: optionId,
    completedAt: DateTime(2026, 6, day),
  );

  test(
    'progress is saved after the third check-in, without duplicates',
    () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);
      final progressStore = PatternProgressStore(AppServices.instance.prefs);

      await PatternMemoryCoordinator.recordCheckInCompletion(
        completed: _completed('showed_up_again', 1),
        now: DateTime(2026, 6, 1),
      );
      expect(await progressStore.loadLatest(), isNull);

      await PatternMemoryCoordinator.recordCheckInCompletion(
        completed: _completed('showed_up_again', 2),
        now: DateTime(2026, 6, 2),
      );
      expect(await progressStore.loadLatest(), isNull);

      await PatternMemoryCoordinator.recordCheckInCompletion(
        completed: _completed('showed_up_again', 3),
        now: DateTime(2026, 6, 3),
      );
      final latest = await progressStore.loadLatest();
      expect(latest, isNotNull);
      expect(latest!.type, PatternProgressType.stillRepeating);
      expect(latest.checkInCount, 3);

      final history = await progressStore.loadHistory();
      expect(history, hasLength(1));

      await Future<void>.delayed(const Duration(milliseconds: 100));
      final events = await ActivationEventsStore(
        AppServices.instance.prefs,
      ).read();
      expect(events.patternProgressMomentCreated, 1);
    },
  );

  test(
    'next action is generated after progress and CTA locks a check-in',
    () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);
      final actionStore = PatternNextActionStore(AppServices.instance.prefs);

      for (var day = 1; day <= 3; day++) {
        await PatternMemoryCoordinator.recordCheckInCompletion(
          completed: _completed('showed_up_again', day),
          now: DateTime(2026, 6, day),
        );
      }

      final action = await PatternMemoryCoordinator.loadLatestNextAction();
      expect(action, isNotNull);
      expect(action!.type, PatternNextActionType.repeatCheck);
      expect(action.question, 'What happens right before it shows up?');

      // One action per check-in (sharpen, sharpen, then repeatCheck), each a
      // distinct id, so no duplicate is recorded for the same memory + count.
      final history = await actionStore.loadHistory();
      expect(history, hasLength(3));
      expect(history.map((a) => a.id).toSet(), hasLength(3));

      final checkIn = await PatternMemoryCoordinator.useNextAction(
        action,
        now: DateTime(2026, 6, 3, 12),
      );
      expect(checkIn, isNotNull);

      final due = await TomorrowCheckInCoordinator.loadDueToday(
        now: DateTime(2026, 6, 4, 9),
      );
      expect(due, isNotNull);
      expect(due!.question, 'What happens right before it shows up?');

      await Future<void>.delayed(const Duration(milliseconds: 100));
      final events = await ActivationEventsStore(
        AppServices.instance.prefs,
      ).read();
      expect(events.patternNextActionCreated, 3);
      expect(events.patternNextActionUsed, 1);
    },
  );
}
