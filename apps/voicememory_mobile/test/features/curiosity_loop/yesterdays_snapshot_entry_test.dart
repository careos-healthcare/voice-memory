import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/curiosity_loop/models/curiosity_hook.dart';
import 'package:voicememory_mobile/features/curiosity_loop/repositories/curiosity_hook_repository.dart';
import 'package:voicememory_mobile/features/curiosity_loop/services/yesterdays_snapshot_coordinator.dart';
import 'package:voicememory_mobile/features/curiosity_loop/yesterdays_snapshot_gates.dart';
import 'package:voicememory_mobile/features/curiosity_loop/yesterdays_snapshot_store.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/app_services.dart';

const _strongRepeat =
    'I had no capacity but I said yes again to the extra meeting today.';

JournalEntry _entry(
  String id,
  String transcript, {
  DateTime? createdAt,
}) =>
    JournalEntry(
      id: id,
      createdAt: createdAt ?? DateTime(2026, 6, 12, 10),
      transcript: transcript,
      durationSeconds: 24,
      localAudioPath: '/tmp/$id.m4a',
      reflection: const Reflection(
        mood: 'thoughtful',
        emotionalIntensity: 2,
        recurringThemes: ['work'],
        exactLanguagePattern: '',
        concreteObservation: 'Work pressure showed up again today.',
        repeatedSignal: '',
      ),
    );

List<JournalEntry> _returnDayEntries(DateTime now) {
  final yesterday = now.subtract(const Duration(days: 1));
  return [
    _entry('1', _strongRepeat, createdAt: yesterday.subtract(const Duration(days: 2))),
    _entry(
      '2',
      'Same thing — said yes when I had no capacity for one more thing.',
      createdAt: yesterday.subtract(const Duration(days: 1)),
    ),
    _entry(
      '3',
      'I said yes again even though I had no capacity for one more ask.',
      createdAt: yesterday,
    ),
  ];
}

CuriosityHook _hook({required String entryId}) => CuriosityHook(
      id: 'hook_$entryId',
      entryId: entryId,
      createdAt: DateTime.utc(2026, 6, 11, 12),
      primaryAnchor: 'said yes again',
      hookType: CuriosityHookType.blocker,
      dynamicPrompt:
          'Before "said yes again" showed up again, what got in the way?',
    );

Future<void> _resetStores(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_yesterday_entry_journal_$stamp.json',
    prefsPath: '/tmp/vm_yesterday_entry_prefs_$stamp.json',
    skipRevenueCat: true,
  );
  await LocalCuriosityHookRepository.resetForTest(AppServices.instance.prefs);
  await YesterdaysSnapshotStore.resetForTest(AppServices.instance.prefs);
}

void main() {
  setUp(() async {
    await _resetStores('${DateTime.now().microsecondsSinceEpoch}');
  });

  group('YesterdaysSnapshotGates', () {
    test('allows return day when unconsumed hook exists', () {
      final now = DateTime(2026, 6, 12, 10);
      final entries = _returnDayEntries(now);
      final hook = _hook(entryId: '3');

      expect(
        YesterdaysSnapshotGates.shouldPresentOnReturnDay(
          entries: entries,
          hook: hook,
          now: now,
        ),
        isTrue,
      );
    });

    test('blocks same-day reopen and consumed hooks', () async {
      final now = DateTime(2026, 6, 12, 10);
      final entries = _returnDayEntries(now);
      final hook = _hook(entryId: '3');

      await YesterdaysSnapshotStore.instance().markPresentedToday(hook.id);
      expect(
        YesterdaysSnapshotGates.shouldPresentOnReturnDay(
          entries: entries,
          hook: hook,
          now: now,
        ),
        isFalse,
      );

      expect(
        YesterdaysSnapshotGates.shouldPresentOnReturnDay(
          entries: entries,
          hook: hook.copyWith(isConsumed: true),
          now: now,
        ),
        isFalse,
      );
    });
  });

  group('YesterdaysSnapshotCoordinator', () {
    test('resolveReturnDayHook returns latest unconsumed hook on return day', () async {
      final now = DateTime(2026, 6, 12, 10);
      final entries = _returnDayEntries(now);
      final repo = LocalCuriosityHookRepository.instance();
      final hook = _hook(entryId: '3');
      await repo.saveHook(hook);

      final resolved = await YesterdaysSnapshotCoordinator.resolveReturnDayHook(
        entries: entries,
        repository: repo,
        now: now,
      );

      expect(resolved?.id, hook.id);
    });

    test('resolveReturnDayHook returns null when not return day', () async {
      final now = DateTime(2026, 6, 12, 10);
      final entries = [
        _entry('1', _strongRepeat, createdAt: now),
      ];
      final repo = LocalCuriosityHookRepository.instance();
      await repo.saveHook(_hook(entryId: '1'));

      final resolved = await YesterdaysSnapshotCoordinator.resolveReturnDayHook(
        entries: entries,
        repository: repo,
        now: now,
      );

      expect(resolved, isNull);
    });

    test('dismissForDay suppresses further presentation', () async {
      final now = DateTime(2026, 6, 12, 10);
      final entries = _returnDayEntries(now);
      final repo = LocalCuriosityHookRepository.instance();
      await repo.saveHook(_hook(entryId: '3'));

      await YesterdaysSnapshotCoordinator.dismissForDay();

      final resolved = await YesterdaysSnapshotCoordinator.resolveReturnDayHook(
        entries: entries,
        repository: repo,
        now: now,
      );

      expect(resolved, isNull);
    });
  });
}
