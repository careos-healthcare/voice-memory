import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/pattern_memory/weekly_pattern_recap_model.dart';
import 'package:voicememory_mobile/features/pattern_memory/weekly_pattern_recap_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

Future<WeeklyPatternRecapStore> _store(String stamp) async {
  final path = '/tmp/vm_wr_store_$stamp.json';
  final file = File(path);
  if (await file.exists()) await file.delete();
  final prefs = await MobilePrefsStore.open(path);
  return WeeklyPatternRecapStore(prefs);
}

WeeklyPatternRecap _recap({
  String id = 'wr_pm1_20260601_repeated',
  WeeklyPatternRecapType type = WeeklyPatternRecapType.repeated,
}) =>
    WeeklyPatternRecap(
      id: id,
      memoryId: 'pm1',
      createdAt: DateTime(2026, 6, 4),
      weekStart: DateTime(2026, 6, 1),
      weekEnd: DateTime(2026, 6, 7),
      type: type,
      patternTitle: 'saying yes when you mean no',
      headline: 'This pattern kept showing up this week.',
      body: 'You checked it 4 times and caught it more than once.',
      usefulLine: 'It often starts around: before saying yes',
      nextQuestion: 'What happens right before it starts?',
      checkInCount: 4,
      shouldShow: true,
    );

void main() {
  test('saveLatest and loadLatest round-trip', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    await store.saveLatest(_recap());
    final loaded = await store.loadLatest();
    expect(loaded, isNotNull);
    expect(loaded!.type, WeeklyPatternRecapType.repeated);
    expect(loaded.nextQuestion, 'What happens right before it starts?');
    expect(loaded.weekStart.isAtSameMomentAs(DateTime(2026, 6, 1)), isTrue);
  });

  test('duplicate recap not repeated for same week/type', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    await store.appendHistory(_recap());
    await store.appendHistory(_recap());
    final history = await store.loadHistory();
    expect(history, hasLength(1));
  });

  test('history is capped at 20', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    for (var i = 0; i < 25; i++) {
      await store.appendHistory(_recap(id: 'wr_pm1_2026060${i}_repeated'));
    }
    final history = await store.loadHistory(limit: 100);
    expect(history.length, 20);
  });

  test('clear removes latest and history', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    await store.saveLatest(_recap());
    await store.appendHistory(_recap());
    await store.clear();

    expect(await store.loadLatest(), isNull);
    expect(await store.loadHistory(), isEmpty);
  });
}
