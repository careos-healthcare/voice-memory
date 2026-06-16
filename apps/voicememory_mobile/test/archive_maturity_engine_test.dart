import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_maturity/archive_maturity_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

JournalEntry _entry(String id) => JournalEntry(
  id: id,
  createdAt: DateTime.parse('2026-01-0${id.length}T12:00:00Z'),
  transcript: 'Reflection $id',
  durationSeconds: 10,
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 2,
    recurringThemes: [],
    exactLanguagePattern: 'pattern',
    concreteObservation: 'observation',
    repeatedSignal: 'signal',
  ),
);

void main() {
  test('maturity score is 0-100', () {
    final input = ArchiveMaturityEngine.inputFromEntries([
      _entry('1'),
      _entry('2'),
      _entry('3'),
    ]);
    final score = ArchiveMaturityEngine.compute(input);
    expect(score, inInclusiveRange(0, 100));
  });

  test('progress view includes harder-to-fool headline', () {
    final view = ArchiveMaturityEngine.buildView(
      ArchiveMaturityEngine.inputFromEntries([_entry('1')]),
    );
    expect(view.headline, contains('harder to fool'));
    expect(view.nextMilestoneLabel, isNotEmpty);
  });
}
