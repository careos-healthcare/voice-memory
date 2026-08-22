import 'dart:io';

import 'package:archiveme_mobile/features/archive_memory/archive_evolution_model.dart';
import 'package:archiveme_mobile/features/archive_memory/archive_evolution_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ArchiveEvolutionStore> _store(String stamp) async {
  final path = '/tmp/vm_evolution_store_$stamp.json';
  final file = File(path);
  if (await file.exists()) await file.delete();
  final prefs = await MobilePrefsStore.open(path);
  return ArchiveEvolutionStore(prefs);
}

ArchiveEvolutionTimeline _timeline() => ArchiveEvolutionTimeline(
  patternTitle: 'Taking responsibility before asking for help',
  firstSeenDate: DateTime(2026, 5, 4),
  lastSeenDate: DateTime(2026, 5, 25),
  eventCount: 2,
  nextCheck: 'Did you ask for help?',
  events: [
    ArchiveEvolutionEvent(
      id: 'e1',
      date: DateTime(2026, 5, 4),
      type: ArchiveEvolutionEventType.firstSeen,
      title: 'First noticed',
      body: 'First moment',
    ),
    ArchiveEvolutionEvent(
      id: 'e2',
      date: DateTime(2026, 5, 10),
      type: ArchiveEvolutionEventType.showedAgain,
      title: 'Showed up again',
      body: 'Again',
    ),
  ],
);

void main() {
  test('loadLatest is null before anything is saved', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);
    expect(await store.loadLatest(), isNull);
  });

  test('saveLatest then loadLatest round-trips', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);
    await store.saveLatest(_timeline());
    final loaded = await store.loadLatest();
    expect(
      loaded!.patternTitle,
      'Taking responsibility before asking for help',
    );
    expect(loaded.eventCount, 2);
    expect(loaded.events.length, 2);
    expect(loaded.nextCheck, 'Did you ask for help?');
  });

  test('clear removes the stored timeline', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);
    await store.saveLatest(_timeline());
    await store.clear();
    expect(await store.loadLatest(), isNull);
  });
}