import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_memory/archive_memory_summary_model.dart';
import 'package:voicememory_mobile/features/archive_memory/archive_memory_summary_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

Future<ArchiveMemorySummaryStore> _store(String stamp) async {
  final path = '/tmp/vm_archive_memory_store_$stamp.json';
  final file = File(path);
  if (await file.exists()) await file.delete();
  final prefs = await MobilePrefsStore.open(path);
  return ArchiveMemorySummaryStore(prefs);
}

ArchiveMemorySummary _summary({String id = 'm1'}) => ArchiveMemorySummary(
      id: id,
      patternTitle: 'Taking responsibility before asking for help',
      primaryMemoryLine:
          'You often take responsibility before asking for help.',
      startsBeforeLine: 'It often starts before: saying yes.',
      helpedLine: 'It has felt lighter when: pausing before answering.',
      basedOnMomentCount: 8,
      basedOnWeekCount: 3,
      firstSeenDate: DateTime(2026, 5, 4),
      lastSeenDate: DateTime(2026, 5, 25),
      clarityLabel: 'Clear pattern',
      nextCheck: 'Did you ask for help before saying yes?',
    );

void main() {
  test('loadLatest is null before anything is saved', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);
    expect(await store.loadLatest(), isNull);
  });

  test('saveLatest then loadLatest round-trips all fields', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    await store.saveLatest(_summary());
    final loaded = await store.loadLatest();

    expect(loaded, isNotNull);
    expect(loaded!.id, 'm1');
    expect(loaded.primaryMemoryLine,
        'You often take responsibility before asking for help.');
    expect(loaded.startsBeforeLine, 'It often starts before: saying yes.');
    expect(loaded.helpedLine,
        'It has felt lighter when: pausing before answering.');
    expect(loaded.basedOnMomentCount, 8);
    expect(loaded.basedOnWeekCount, 3);
    expect(loaded.clarityLabel, 'Clear pattern');
    expect(loaded.nextCheck, 'Did you ask for help before saying yes?');
  });

  test('saveLatest keeps only the most recent summary', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    await store.saveLatest(_summary(id: 'old'));
    await store.saveLatest(_summary(id: 'new'));

    final loaded = await store.loadLatest();
    expect(loaded!.id, 'new');
  });

  test('clear removes the stored summary', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    await store.saveLatest(_summary());
    await store.clear();

    expect(await store.loadLatest(), isNull);
  });
}
