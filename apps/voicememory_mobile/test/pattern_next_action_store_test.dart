import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_next_action_model.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_next_action_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

Future<PatternNextActionStore> _store(String stamp) async {
  final path = '/tmp/vm_na_store_$stamp.json';
  final file = File(path);
  if (await file.exists()) await file.delete();
  final prefs = await MobilePrefsStore.open(path);
  return PatternNextActionStore(prefs);
}

PatternNextAction _action({
  String id = 'na_pm1_3_repeatCheck',
  PatternNextActionType type = PatternNextActionType.repeatCheck,
}) =>
    PatternNextAction(
      id: id,
      memoryId: 'pm1',
      createdAt: DateTime(2026, 6, 4),
      type: type,
      title: 'Check what happens before it starts',
      body: 'Tomorrow, look at the moment right before it shows up.',
      question: 'What happens right before it shows up?',
      ctaLabel: 'Use this check',
      sourceProgressType: 'stillRepeating',
      sourceStatus: 'active',
    );

void main() {
  test('saveLatest and loadLatest round-trip', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    await store.saveLatest(_action());
    final loaded = await store.loadLatest();
    expect(loaded, isNotNull);
    expect(loaded!.type, PatternNextActionType.repeatCheck);
    expect(loaded.question, 'What happens right before it shows up?');
  });

  test('appendHistory does not duplicate the same id', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    await store.appendHistory(_action());
    await store.appendHistory(_action());
    final history = await store.loadHistory();
    expect(history, hasLength(1));
  });

  test('history is capped at 20', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    for (var i = 0; i < 25; i++) {
      await store.appendHistory(_action(id: 'na_pm1_${i}_repeatCheck'));
    }
    final history = await store.loadHistory(limit: 100);
    expect(history.length, 20);
  });

  test('clear removes latest and history', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    await store.saveLatest(_action());
    await store.appendHistory(_action());
    await store.clear();

    expect(await store.loadLatest(), isNull);
    expect(await store.loadHistory(), isEmpty);
  });
}
