import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/tomorrow_return/tomorrow_check_in_coordinator.dart';
import 'package:voicememory_mobile/features/tomorrow_return/tomorrow_check_in_model.dart';
import 'package:voicememory_mobile/features/tomorrow_return/tomorrow_check_in_store.dart';
import 'package:voicememory_mobile/services/app_services.dart';

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_tci_journal_$stamp.json',
    prefsPath: '/tmp/vm_tci_prefs_$stamp.json',
  );
}

void main() {
  test('createForTomorrow sets target to tomorrow', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final now = DateTime(2026, 5, 25, 10);
    final checkIn = await TomorrowCheckInCoordinator.createForTomorrow(
      patternTitle: 'Carrying it alone',
      specificPrompt: 'Notice help',
      checkInQuestion: 'Did you ask for help?',
      now: now,
    );
    expect(
      checkIn.targetDate,
      tomorrowCheckInDateKey(now.add(const Duration(days: 1))),
    );
    expect(checkIn.question, 'Did you ask for help?');
  });

  test('loadDueToday returns active check-in on target day', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final store = TomorrowCheckInStore(AppServices.instance.prefs);
    final today = DateTime(2026, 5, 26, 9);
    await store.save(
      TomorrowCheckIn(
        id: 'tci1',
        createdAt: DateTime(2026, 5, 25),
        targetDate: tomorrowCheckInDateKey(today),
        patternTitle: 'Pattern',
        prompt: 'Tomorrow, check whether this pattern shows up again.',
        question: 'Did this pattern show up again?',
        options: kDefaultTomorrowCheckInOptions,
      ),
    );
    final due = await store.loadDueToday(now: today);
    expect(due?.id, 'tci1');
  });

  test('selectOption persists comparison hint via coordinator', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final now = DateTime(2026, 5, 26);
    await TomorrowCheckInCoordinator.createForTomorrow(
      patternTitle: 'Pattern',
      specificPrompt: 'x',
      now: DateTime(2026, 5, 25),
    );
    final due = await TomorrowCheckInCoordinator.loadDueToday(now: now);
    expect(due, isNotNull);
    final updated = await TomorrowCheckInCoordinator.selectOption(
      checkInId: due!.id,
      optionId: 'lighter',
    );
    expect(updated?.selectedOptionId, 'lighter');
    expect(updated?.selectedOption?.comparisonHint, 'lighter');
  });

  test('markCompleted moves to history', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final store = TomorrowCheckInStore(AppServices.instance.prefs);
    await store.save(
      TomorrowCheckIn(
        id: 'tci2',
        createdAt: DateTime(2026, 5, 25),
        targetDate: tomorrowCheckInDateKey(DateTime(2026, 5, 26)),
        patternTitle: 'P',
        prompt: 'Tomorrow, check whether this pattern shows up again.',
        question: 'Q?',
        options: kDefaultTomorrowCheckInOptions,
        selectedOptionId: 'heavier',
      ),
    );
    final done = await store.markCompleted('tci2');
    expect(done?.completedAt, isNotNull);
    expect(await store.loadActive(), isNull);
    expect((await store.loadHistory()).first.id, 'tci2');
  });
}
