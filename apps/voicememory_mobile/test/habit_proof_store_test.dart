import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/pattern_memory/habit_proof_model.dart';
import 'package:voicememory_mobile/features/pattern_memory/habit_proof_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

Future<HabitProofStore> _store(String stamp) async {
  final path = '/tmp/vm_hp_store_$stamp.json';
  final file = File(path);
  if (await file.exists()) await file.delete();
  final prefs = await MobilePrefsStore.open(path);
  return HabitProofStore(prefs);
}

HabitProofMoment _proof({
  String id = 'hp_pm1_3_progressFound',
  HabitProofType type = HabitProofType.progressFound,
}) => HabitProofMoment(
  id: id,
  memoryId: 'pm1',
  createdAt: DateTime(2026, 6, 4),
  type: type,
  headline: 'Now there is something to compare.',
  body:
      'You can see whether this pattern is repeating, '
      'getting lighter, getting heavier, or changing.',
  proofLine: 'This pattern is still showing up.',
  nextLine: 'What happens right before it shows up?',
  checkInCount: 3,
  shouldShow: true,
);

void main() {
  test('saveLatest and loadLatest round-trip', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    await store.saveLatest(_proof());
    final loaded = await store.loadLatest();
    expect(loaded, isNotNull);
    expect(loaded!.type, HabitProofType.progressFound);
    expect(loaded.nextLine, 'What happens right before it shows up?');
    expect(loaded.checkInCount, 3);
  });

  test('appendHistory does not duplicate the same id', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    await store.appendHistory(_proof());
    await store.appendHistory(_proof());
    final history = await store.loadHistory();
    expect(history, hasLength(1));
  });

  test('history is capped at 20', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    for (var i = 0; i < 25; i++) {
      await store.appendHistory(_proof(id: 'hp_pm1_${i}_progressFound'));
    }
    final history = await store.loadHistory(limit: 100);
    expect(history.length, 20);
  });

  test('clear removes latest and history', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    await store.saveLatest(_proof());
    await store.appendHistory(_proof());
    await store.clear();

    expect(await store.loadLatest(), isNull);
    expect(await store.loadHistory(), isEmpty);
  });
}
