import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_compression/archive_compression_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

Future<ArchiveCompressionStore> _store(String stamp) async {
  final path = '/tmp/vm_compression_store_$stamp.json';
  final file = File(path);
  if (await file.exists()) await file.delete();
  final prefs = await MobilePrefsStore.open(path);
  return ArchiveCompressionStore(prefs);
}

void main() {
  test('persists kept, split, and hidden group ids', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    await store.markKept('g1');
    await store.markSplit('g2');
    await store.markHidden('g3');

    expect(await store.isKept('g1'), isTrue);
    expect(await store.isSplit('g2'), isTrue);
    expect(await store.isHidden('g3'), isTrue);

    final prefs = await store.loadPrefs();
    expect(prefs.keptGroupIds, {'g1'});
    expect(prefs.splitGroupIds, {'g2'});
    expect(prefs.hiddenGroupIds, {'g3'});
  });

  test('clear removes all decisions', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    await store.markHidden('g1');
    await store.clear();

    expect(await store.isHidden('g1'), isFalse);
    expect((await store.loadPrefs()).hiddenGroupIds, isEmpty);
  });

  test('loadPrefs fails softly on bad JSON', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final path = '/tmp/vm_compression_store_$stamp.json';
    final file = File(path);
    if (await file.exists()) await file.delete();
    final prefs = await MobilePrefsStore.open(path);
    await prefs.writeMap('archiveCompressionPrefs', {'keptGroupIds': 'bad'});
    final store = ArchiveCompressionStore(prefs);
    final loaded = await store.loadPrefs();
    expect(loaded.keptGroupIds, isEmpty);
  });
}
