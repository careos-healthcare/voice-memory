import 'package:archiveme_mobile/features/first_session/pattern_correction_learning_model.dart';
import 'package:archiveme_mobile/features/first_session/pattern_correction_learning_store.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_pcl_journal_$stamp.json',
    prefsPath: '/tmp/vm_pcl_prefs_$stamp.json',
  );
}

PatternCorrectionLearning _sample(String id, {String category = 'worry'}) {
  return PatternCorrectionLearning(
    id: id,
    createdAt: DateTime(2026, 5, 25),
    originalTitle: 'Taking responsibility before asking for help',
    correctedTitle: 'The same worry returning',
    originalCategoryId: 'responsibility',
    correctedCategoryId: category,
    reflectionSnippet: 'I keep worrying about the same thing',
    matchedPhrases: const ['pressure'],
    correctedWatchForText: 'whether the same worry shows up again',
    source: PatternCorrectionLearningSource.firstSession,
  );
}

void main() {
  test('saving correction stores original and corrected', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final store = PatternCorrectionLearningStore(AppServices.instance.prefs);

    await store.saveLearning(_sample('pcl-1'));

    final items = await store.readAll();
    expect(items, hasLength(1));
    expect(items.first.originalTitle, contains('responsibility'));
    expect(items.first.correctedTitle, contains('worry'));
    expect(items.first.correctedCategoryId, 'worry');
  });

  test('caps stored corrections at 100', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final store = PatternCorrectionLearningStore(AppServices.instance.prefs);

    for (var i = 0; i < 105; i++) {
      await store.saveLearning(_sample('pcl-$i'));
    }

    expect(
      (await store.readAll()).length,
      PatternCorrectionLearningStore.maxItems,
    );
  });

  test('loadByCorrectedCategory filters by category', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final store = PatternCorrectionLearningStore(AppServices.instance.prefs);

    await store.saveLearning(_sample('a'));
    await store.saveLearning(_sample('b', category: 'burnout'));

    final worry = await store.loadByCorrectedCategory('worry');
    expect(worry, hasLength(1));
    expect(worry.first.correctedCategoryId, 'worry');
  });

  test('markUsedForNextPrompt updates flag', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final store = PatternCorrectionLearningStore(AppServices.instance.prefs);

    await store.saveLearning(_sample('pcl-used'));
    await store.markUsedForNextPrompt('pcl-used');

    final item = (await store.readAll()).first;
    expect(item.usedForNextPrompt, isTrue);
  });

  test('clear removes all items', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final store = PatternCorrectionLearningStore(AppServices.instance.prefs);

    await store.saveLearning(_sample('pcl-clear'));
    await store.clear();

    expect(await store.readAll(), isEmpty);
  });
}