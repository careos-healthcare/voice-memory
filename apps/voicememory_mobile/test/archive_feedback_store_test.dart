import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/feedback/archive_feedback_model.dart';
import 'package:voicememory_mobile/features/feedback/archive_feedback_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

Future<ArchiveFeedbackStore> _store(String stamp) async {
  final path = '/tmp/vm_feedback_store_$stamp.json';
  final file = File(path);
  if (await file.exists()) await file.delete();
  final prefs = await MobilePrefsStore.open(path);
  return ArchiveFeedbackStore(prefs);
}

ArchiveFeedback _feedback(
  String id,
  ArchiveFeedbackType type,
  DateTime createdAt, {
  ArchiveFeedbackTargetType targetType = ArchiveFeedbackTargetType.checkInResult,
  String? targetId,
}) =>
    ArchiveFeedback(
      id: id,
      type: type,
      targetType: targetType,
      createdAt: createdAt,
      targetId: targetId,
    );

void main() {
  test('save then loadAll returns newest first', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    await store.save(_feedback('a', ArchiveFeedbackType.useful, DateTime(2026, 6, 1)));
    await store.save(_feedback('b', ArchiveFeedbackType.notMe, DateTime(2026, 6, 3)));
    await store.save(_feedback('c', ArchiveFeedbackType.tooGeneric, DateTime(2026, 6, 2)));

    final all = await store.loadAll();
    expect(all.map((f) => f.id), ['b', 'c', 'a']);
  });

  test('save de-duplicates by id', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    await store.save(_feedback('a', ArchiveFeedbackType.useful, DateTime(2026, 6, 1)));
    await store.save(_feedback('a', ArchiveFeedbackType.notMe, DateTime(2026, 6, 1)));

    final all = await store.loadAll();
    expect(all, hasLength(1));
    expect(all.first.type, ArchiveFeedbackType.notMe);
  });

  test('loadForTarget filters by target type and id', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    await store.save(_feedback('a', ArchiveFeedbackType.useful, DateTime(2026, 6, 1),
        targetType: ArchiveFeedbackTargetType.firstPattern, targetId: 'p1'));
    await store.save(_feedback('b', ArchiveFeedbackType.notMe, DateTime(2026, 6, 2),
        targetType: ArchiveFeedbackTargetType.firstPattern, targetId: 'p2'));
    await store.save(_feedback('c', ArchiveFeedbackType.useful, DateTime(2026, 6, 3),
        targetType: ArchiveFeedbackTargetType.nextCheck, targetId: 'p1'));

    final byType =
        await store.loadForTarget(ArchiveFeedbackTargetType.firstPattern, null);
    expect(byType.map((f) => f.id).toSet(), {'a', 'b'});

    final byId =
        await store.loadForTarget(ArchiveFeedbackTargetType.firstPattern, 'p1');
    expect(byId.map((f) => f.id), ['a']);
  });

  test('summary counts feedback and finds the dominant issue', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    await store.save(_feedback('a', ArchiveFeedbackType.useful, DateTime(2026, 6, 1)));
    await store.save(_feedback('b', ArchiveFeedbackType.tooGeneric, DateTime(2026, 6, 2)));
    await store.save(_feedback('c', ArchiveFeedbackType.tooGeneric, DateTime(2026, 6, 3)));

    final summary = await store.summary();
    expect(summary.total, 3);
    expect(summary.usefulCount, 1);
    expect(summary.tooGenericCount, 2);
    expect(summary.dominantIssue, ArchiveFeedbackType.tooGeneric);
  });

  test('loadRecent respects the limit', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    for (var i = 0; i < 5; i++) {
      await store.save(
        _feedback('f$i', ArchiveFeedbackType.useful, DateTime(2026, 6, 1 + i)),
      );
    }
    final recent = await store.loadRecent(limit: 3);
    expect(recent, hasLength(3));
    expect(recent.first.id, 'f4');
  });

  test('caps the list at 300 newest rows', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    for (var i = 0; i < 305; i++) {
      await store.save(
        _feedback('f$i', ArchiveFeedbackType.useful,
            DateTime(2026, 1, 1).add(Duration(days: i))),
      );
    }
    final all = await store.loadAll();
    expect(all.length, 300);
    expect(all.any((f) => f.id == 'f304'), isTrue);
    expect(all.any((f) => f.id == 'f0'), isFalse);
  });

  test('clear removes everything', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    await store.save(_feedback('a', ArchiveFeedbackType.useful, DateTime(2026, 6, 1)));
    await store.clear();
    expect(await store.loadAll(), isEmpty);
  });
}
