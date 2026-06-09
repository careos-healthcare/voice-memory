import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/retention/second_session_signal_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';

JournalEntry _entry(String id, String transcript) {
  return JournalEntry(
    id: id,
    createdAt: DateTime(2026, 6, int.parse(id)),
    transcript: transcript,
    durationSeconds: 30,
    reflection: Reflection(
      mood: 'neutral',
      emotionalIntensity: 2,
      recurringThemes: const [],
      exactLanguagePattern: '',
      concreteObservation: 'You mentioned pressure in this moment.',
      repeatedSignal: '',
    ),
    syncStatus: SyncStatus.localOnly,
  );
}

void main() {
  const engine = SecondSessionSignalEngine();

  test('no comparison below 2 moments', () {
    final result = engine.build([
      _entry(
        '1',
        'I said yes again even though I was already tired from work today.',
      ),
    ]);
    expect(result.hasEnoughData, isFalse);
  });

  test('comparison appears at 2 moments', () {
    final entries = [
      _entry(
        '1',
        'I said yes again even though I was already tired from work today.',
      ),
      _entry(
        '2',
        'I took responsibility again before asking anyone for help today.',
      ),
    ];
    final result = engine.build(entries);
    expect(result.hasEnoughData, isTrue);
    expect(result.title, ConsumerUiCopy.secondSessionPossibleRepeatTitle);
    expect(result.body, isNotEmpty);
  });

  test('repeated signal detected conservatively for same category', () {
    final result = engine.build([
      _entry(
        '1',
        'I said yes again even though I was already tired from work today.',
      ),
      _entry(
        '2',
        'I took responsibility again before asking anyone for help today.',
      ),
    ]);
    expect(result.possibleRepeat, isTrue);
    expect(result.whatRepeated, isNotNull);
  });

  test('changed signal text appears when latest differs', () {
    final result = engine.build([
      _entry(
        '1',
        'I said yes again even though I was already tired from work today.',
      ),
      _entry(
        '2',
        'Something felt lighter today after I finally rested without guilt.',
      ),
    ]);
    expect(result.hasEnoughData, isTrue);
    expect(result.latestSignalLabel, isNotNull);
    expect(result.previousSignalLabel, isNotNull);
  });
}
