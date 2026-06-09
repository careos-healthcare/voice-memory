import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/moments/key_moment_model.dart';
import 'package:voicememory_mobile/features/moments/key_moment_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

Future<KeyMomentStore> _store(String stamp) async {
  final path = '/tmp/vm_km_store_$stamp.json';
  final file = File(path);
  if (await file.exists()) await file.delete();
  final prefs = await MobilePrefsStore.open(path);
  return KeyMomentStore(prefs);
}

KeyMoment _moment(String id, DateTime date, {String text = 'a moment'}) =>
    KeyMoment(
      id: id,
      date: date,
      title: 'Moment from today',
      originalText: text,
      shortSummary: text,
    );

void main() {
  test('save then loadAll returns newest first', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    await store.save(_moment('a', DateTime(2026, 6, 1)));
    await store.save(_moment('b', DateTime(2026, 6, 3)));
    await store.save(_moment('c', DateTime(2026, 6, 2)));

    final all = await store.loadAll();
    expect(all.map((m) => m.id), ['b', 'c', 'a']);
  });

  test('save de-duplicates by id', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    await store.save(_moment('a', DateTime(2026, 6, 1), text: 'first'));
    await store.save(_moment('a', DateTime(2026, 6, 1), text: 'second'));

    final all = await store.loadAll();
    expect(all, hasLength(1));
    expect(all.first.originalText, 'second');
  });

  test('loadByDate returns only that day', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    await store.save(_moment('a', DateTime(2026, 6, 1, 8)));
    await store.save(_moment('b', DateTime(2026, 6, 1, 20)));
    await store.save(_moment('c', DateTime(2026, 6, 2, 9)));

    final day = await store.loadByDate(DateTime(2026, 6, 1, 12));
    expect(day.map((m) => m.id).toSet(), {'a', 'b'});
  });

  test('search matches original text', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    await store.save(_moment('a', DateTime(2026, 6, 1),
        text: 'The worry came back when things got quiet.'));
    await store.save(_moment('b', DateTime(2026, 6, 2), text: 'A calm day.'));

    final hits = await store.search('worry');
    expect(hits, hasLength(1));
    expect(hits.first.id, 'a');

    expect(await store.search(''), isEmpty);
  });

  test('loadById returns the matching moment or null', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    await store.save(_moment('a', DateTime(2026, 6, 1), text: 'first'));
    await store.save(_moment('b', DateTime(2026, 6, 2), text: 'second'));

    expect((await store.loadById('b'))?.originalText, 'second');
    expect(await store.loadById('missing'), isNull);
  });

  test('loadRecent respects the limit', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    for (var i = 0; i < 5; i++) {
      await store.save(_moment('m$i', DateTime(2026, 6, 1 + i)));
    }
    final recent = await store.loadRecent(limit: 3);
    expect(recent, hasLength(3));
    expect(recent.first.id, 'm4');
  });

  test('caps the list at 500 newest moments', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    for (var i = 0; i < 505; i++) {
      await store.save(
        _moment('m$i', DateTime(2026, 1, 1).add(Duration(days: i))),
      );
    }
    final all = await store.loadAll();
    expect(all.length, 500);
    // Newest survives, oldest evicted.
    expect(all.any((m) => m.id == 'm504'), isTrue);
    expect(all.any((m) => m.id == 'm0'), isFalse);
  });

  test('clear removes everything', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    await store.save(_moment('a', DateTime(2026, 6, 1)));
    await store.clear();
    expect(await store.loadAll(), isEmpty);
  });
}
