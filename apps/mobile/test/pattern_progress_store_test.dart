import 'dart:io';

import 'package:archiveme_mobile/features/pattern_memory/pattern_progress_model.dart';
import 'package:archiveme_mobile/features/pattern_memory/pattern_progress_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

Future<PatternProgressStore> _store(String stamp) async {
  final path = '/tmp/vm_pp_store_$stamp.json';
  final file = File(path);
  if (await file.exists()) await file.delete();
  final prefs = await MobilePrefsStore.open(path);
  return PatternProgressStore(prefs);
}

PatternProgressMoment _moment({
  String id = 'pp_pm1_3',
  String memoryId = 'pm1',
  int checkInCount = 3,
}) => PatternProgressMoment(
  id: id,
  memoryId: memoryId,
  createdAt: DateTime(2026, 6, 4),
  type: PatternProgressType.stillRepeating,
  headline: 'This pattern is still showing up.',
  body: 'You have caught it $checkInCount times.',
  beforeLine: 'It often starts around: before saying yes',
  nextLine: 'Next, watch what happens right before it starts.',
  checkInCount: checkInCount,
  shouldShow: true,
);

void main() {
  test('saveLatest and loadLatest round-trip', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    await store.saveLatest(_moment());
    final loaded = await store.loadLatest();
    expect(loaded, isNotNull);
    expect(loaded!.type, PatternProgressType.stillRepeating);
    expect(loaded.checkInCount, 3);
  });

  test('appendHistory does not duplicate the same id', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    await store.appendHistory(_moment());
    await store.appendHistory(_moment());
    final history = await store.loadHistory();
    expect(history, hasLength(1));
  });

  test('history is capped at 20', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    for (var i = 0; i < 25; i++) {
      await store.appendHistory(_moment(id: 'pp_pm1_$i', checkInCount: i));
    }
    final history = await store.loadHistory(limit: 100);
    expect(history.length, 20);
  });

  test('clear removes latest and history', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    await store.saveLatest(_moment());
    await store.appendHistory(_moment());
    await store.clear();

    expect(await store.loadLatest(), isNull);
    expect(await store.loadHistory(), isEmpty);
  });
}