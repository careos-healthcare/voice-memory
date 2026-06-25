import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_review/archive_range_review_model.dart';
import 'package:voicememory_mobile/features/archive_review/archive_range_review_store.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

ArchiveRangeReview _review(String id) => ArchiveRangeReview(
  id: id,
  preset: ArchiveReviewRangePreset.thisWeek,
  startDate: DateTime(2026, 6, 1),
  endDate: DateTime(2026, 6, 6),
  title: 'This week',
  type: ArchiveRangeReviewType.repeated,
  momentCount: 4,
  patternCount: 1,
  repeatedLine: 'This pattern showed up 3 times.',
  nextCheck: 'What happens right before it shows up?',
  keyMomentIds: const ['m1', 'm2'],
);

Future<void> _deleteJournalArtifacts(String journalPath) async {
  for (final path in [
    journalPath,
    JournalStore.encryptedPathFor(journalPath),
  ]) {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}

Future<ArchiveRangeReviewStore> _store(String stamp) async {
  final dir = Directory.systemTemp.createTempSync('vm_arr_$stamp');
  final journalPath = '${dir.path}/journal.json';
  final prefsPath = '${dir.path}/prefs.json';
  await _deleteJournalArtifacts(journalPath);
  await AppServices.resetForTest(
    journalPath: journalPath,
    prefsPath: prefsPath,
    skipRevenueCat: true,
  );
  return ArchiveRangeReviewStore(AppServices.instance.prefs);
}

void main() {
  test('saveLatest and loadLatest round-trip', () async {
    final store = await _store('latest');
    final review = _review('r1');
    await store.saveLatest(review);
    final loaded = await store.loadLatest();
    expect(loaded?.id, 'r1');
    expect(loaded?.repeatedLine, review.repeatedLine);
  });

  test('appendHistory keeps newest first and caps entries', () async {
    final store = await _store('history');
    for (var i = 0; i < 25; i++) {
      await store.appendHistory(_review('r$i'));
    }
    final history = await store.loadHistory(limit: 20);
    expect(history.length, 20);
    expect(history.first.id, 'r24');
  });

  test('clear removes latest and history', () async {
    final store = await _store('clear');
    await store.saveLatest(_review('r1'));
    await store.appendHistory(_review('r1'));
    await store.clear();
    expect(await store.loadLatest(), isNull);
    expect(await store.loadHistory(), isEmpty);
  });

  test('toJson and fromJson round-trip', () {
    final review = _review('json');
    final restored = ArchiveRangeReview.fromJson(review.toJson());
    expect(restored?.id, review.id);
    expect(restored?.keyMomentIds, review.keyMomentIds);
  });
}
