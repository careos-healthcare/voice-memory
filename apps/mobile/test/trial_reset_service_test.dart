import 'package:archiveme_mobile/features/activation/activation_events_store.dart';
import 'package:archiveme_mobile/features/first_session/pattern_correction_learning_model.dart';
import 'package:archiveme_mobile/features/first_session/pattern_correction_learning_store.dart';
import 'package:archiveme_mobile/features/tomorrow_return/watch_for_model.dart';
import 'package:archiveme_mobile/features/tomorrow_return/watch_for_store.dart';
import 'package:archiveme_mobile/features/trial/trial_reset_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_trial_reset_journal_$stamp.json',
    prefsPath: '/tmp/vm_trial_reset_prefs_$stamp.json',
  );
}

void main() {
  test('reset clears journal watch-for and activation events', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);

    await AppServices.instance.journalStore.save(
      JournalEntry(
        id: 'e1',
        createdAt: DateTime(2026, 5, 25),
        transcript: 'test reflection content here',
        durationSeconds: 10,
        reflection: const Reflection(
          mood: '',
          emotionalIntensity: 1,
          recurringThemes: [],
          exactLanguagePattern: '',
          concreteObservation: '',
          repeatedSignal: '',
        ),
      ),
    );

    final prefs = AppServices.instance.prefs;
    await WatchForStore(prefs).writePending(
      WatchForItem(
        id: 'wf1',
        createdAt: DateTime(2026, 5, 25),
        targetDate: DateTime(2026, 5, 26),
        text: 'whether something shows up',
        chips: const [],
        status: WatchForStatus.pending,
        result: WatchForResult.none,
      ),
    );
    await ActivationEventsStore(prefs).increment('firstReflectionSaved');
    await PatternCorrectionLearningStore(prefs).saveLearning(
      PatternCorrectionLearning(
        id: 'learn1',
        createdAt: DateTime(2026, 5, 25),
        originalTitle: 'A',
        correctedTitle: 'B',
        originalCategoryId: 'worry',
        correctedCategoryId: 'responsibility',
        reflectionSnippet: 'text',
        matchedPhrases: const [],
        correctedWatchForText: 'B',
        source: PatternCorrectionLearningSource.firstSession,
      ),
    );

    await const TrialResetService().resetForNewParticipant();

    expect(await AppServices.instance.journalStore.loadAll(), isEmpty);
    expect(await WatchForStore(prefs).readPending(), isNull);
    final events = await ActivationEventsStore(prefs).read();
    expect(events.firstReflectionSaved, 0);
    expect(await PatternCorrectionLearningStore(prefs).readAll(), isEmpty);
  });
}