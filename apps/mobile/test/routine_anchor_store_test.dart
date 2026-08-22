import 'dart:io';

import 'package:archiveme_mobile/features/routine/routine_anchor_model.dart';
import 'package:archiveme_mobile/features/routine/routine_anchor_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

Future<RoutineAnchorStore> _store(String stamp) async {
  final path = '/tmp/vm_routine_anchor_$stamp.json';
  final file = File(path);
  if (await file.exists()) await file.delete();
  final prefs = await MobilePrefsStore.open(path);
  return RoutineAnchorStore(prefs);
}

void main() {
  test('save then load round-trips an anchor by date', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    await store.saveForDate(
      '2026-06-07',
      const RoutineAnchor(type: RoutineAnchorType.evening),
    );
    final loaded = await store.loadForDate('2026-06-07');

    expect(loaded, isNotNull);
    expect(loaded!.type, RoutineAnchorType.evening);
    expect(loaded.displayLabel, 'Evening');
  });

  test('custom label round-trips', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    await store.saveForDate(
      '2026-06-08',
      const RoutineAnchor(
        type: RoutineAnchorType.custom,
        customLabel: 'On the train',
      ),
    );
    final loaded = await store.loadForDate('2026-06-08');

    expect(loaded!.type, RoutineAnchorType.custom);
    expect(loaded.displayLabel, 'On the train');
  });

  test('loadForDate is null for an unknown date', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);
    expect(await store.loadForDate('2026-06-09'), isNull);
  });

  test('loadLatest returns the most recently saved anchor', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    await store.saveForDate(
      '2026-06-07',
      const RoutineAnchor(type: RoutineAnchorType.morning),
    );
    await store.saveForDate(
      '2026-06-08',
      const RoutineAnchor(type: RoutineAnchorType.beforeSleep),
    );

    final latest = await store.loadLatest();
    expect(latest!.type, RoutineAnchorType.beforeSleep);
  });

  test('clear removes saved anchors', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    await store.saveForDate(
      '2026-06-07',
      const RoutineAnchor(type: RoutineAnchorType.afterWork),
    );
    await store.clear();

    expect(await store.loadForDate('2026-06-07'), isNull);
    expect(await store.loadLatest(), isNull);
  });
}