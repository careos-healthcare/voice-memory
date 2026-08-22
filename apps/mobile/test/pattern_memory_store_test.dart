import 'dart:io';

import 'package:archiveme_mobile/features/pattern_memory/pattern_memory_model.dart';
import 'package:archiveme_mobile/features/pattern_memory/pattern_memory_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

const _title = 'Taking responsibility before asking for help';

Future<PatternMemoryStore> _store(String stamp) async {
  final path = '/tmp/vm_pm_store_$stamp.json';
  final file = File(path);
  if (await file.exists()) await file.delete();
  final prefs = await MobilePrefsStore.open(path);
  return PatternMemoryStore(prefs);
}

PatternMemoryUpdate _update(String hint, {String text = '', int day = 1}) =>
    PatternMemoryUpdate(
      checkInId: 'tci_$day',
      resultHint: hint,
      reflectionText: text,
      createdAt: DateTime(2026, 6, day),
    );

void main() {
  test('applyUpdate creates and persists active memory', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    final memory = await store.applyUpdate(
      _update(PatternMemoryResultHint.same),
      patternTitle: _title,
    );
    expect(memory.checkInCount, 1);

    final loaded = await store.loadActive();
    expect(loaded, isNotNull);
    expect(loaded!.patternTitle, _title);
    expect(loaded.checkInCount, 1);
  });

  test('applyUpdate folds repeated answers into one thread', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    await store.applyUpdate(
      _update(PatternMemoryResultHint.same),
      patternTitle: _title,
    );
    final memory = await store.applyUpdate(
      _update(PatternMemoryResultHint.same, day: 2),
      patternTitle: _title,
    );

    expect(memory.checkInCount, 2);
    expect(memory.showedAgainCount, 2);
    expect(memory.status, PatternMemoryStatus.active);
  });

  test('different pattern starts a new thread and archives the old', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    await store.applyUpdate(
      _update(PatternMemoryResultHint.same),
      patternTitle: _title,
    );
    final next = await store.applyUpdate(
      _update(PatternMemoryResultHint.lighter, day: 2),
      patternTitle: 'A different pattern',
    );

    expect(next.patternTitle, 'A different pattern');
    expect(next.checkInCount, 1);
    final history = await store.loadHistory();
    expect(history, hasLength(1));
    expect(history.first.patternTitle, _title);
  });

  test('history is capped at 20', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    for (var i = 0; i < 25; i++) {
      await store.appendToHistory(
        PatternMemory(
          id: 'pm_$i',
          patternTitle: 'Pattern $i',
          createdAt: DateTime(2026, 6),
          updatedAt: DateTime(2026, 6),
        ),
      );
    }
    final history = await store.loadHistory(limit: 100);
    expect(history.length, 20);
  });

  test('three repeated check-ins reach the progress threshold', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    await store.applyUpdate(
      _update(PatternMemoryResultHint.same),
      patternTitle: _title,
    );
    await store.applyUpdate(
      _update(PatternMemoryResultHint.same, day: 2),
      patternTitle: _title,
    );
    final memory = await store.applyUpdate(
      _update(PatternMemoryResultHint.same, day: 3),
      patternTitle: _title,
    );

    expect(memory.checkInCount, 3);
    expect(memory.showedAgainCount, 3);
  });

  test('clear removes active and history', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    await store.applyUpdate(
      _update(PatternMemoryResultHint.same),
      patternTitle: _title,
    );
    await store.clear();

    expect(await store.loadActive(), isNull);
    expect(await store.loadHistory(), isEmpty);
  });
}