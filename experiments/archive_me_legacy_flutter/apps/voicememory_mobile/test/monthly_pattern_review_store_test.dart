import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/monthly_review/monthly_pattern_review_model.dart';
import 'package:voicememory_mobile/features/monthly_review/monthly_pattern_review_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

Future<MonthlyPatternReviewStore> _store(String stamp) async {
  final path = '/tmp/vm_monthly_review_$stamp.json';
  final file = File(path);
  if (await file.exists()) await file.delete();
  final prefs = await MobilePrefsStore.open(path);
  return MonthlyPatternReviewStore(prefs);
}

MonthlyPatternReview _review() => const MonthlyPatternReview(
  monthLabel: 'June',
  momentCount: 9,
  checkInCount: 4,
  keptRepeating: 'Taking on too much',
  gotLighter: 'It felt lighter after I paused',
  gotHeavier: 'It felt heavier when I carried it',
  helped: 'I asked for help',
  nextCheck: 'What happens right before it shows up?',
  confidenceLabel: 'Based on 9 moments this month',
);

void main() {
  test('save then load round-trips the review', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    await store.save(_review());
    final loaded = await store.load();

    expect(loaded, isNotNull);
    expect(loaded!.monthLabel, 'June');
    expect(loaded.momentCount, 9);
    expect(loaded.checkInCount, 4);
    expect(loaded.keptRepeating, 'Taking on too much');
    expect(loaded.gotLighter, contains('lighter'));
    expect(loaded.helped, 'I asked for help');
    expect(loaded.nextCheck, 'What happens right before it shows up?');
  });

  test('load is null before anything is saved', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);
    expect(await store.load(), isNull);
  });

  test('clear removes the saved review', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    await store.save(_review());
    await store.clear();
    expect(await store.load(), isNull);
  });
}
