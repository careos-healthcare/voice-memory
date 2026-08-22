import 'package:archiveme_mobile/features/recording/evidence_indexing/evidence_indexing_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry({
  required String transcript,
  required Reflection reflection,
}) {
  return JournalEntry(
    id: 'entry-1',
    createdAt: DateTime.utc(2026, 8, 10, 10),
    transcript: transcript,
    durationSeconds: 30,
    reflection: reflection,
  );
}

void main() {
  group('EvidenceIndexingEngine', () {
    test('extracts citable chips from reflection and transcript', () {
      final chips = EvidenceIndexingEngine.extract(
        _entry(
          transcript:
              'I keep saying yes at work even when I am already exhausted on Sundays',
          reflection: const Reflection(
            mood: 'tense',
            emotionalIntensity: 3,
            recurringThemes: ['work stress'],
            exactLanguagePattern: 'already exhausted on Sundays',
            concreteObservation: 'Work stress spikes on Sundays',
            repeatedSignal: 'saying yes too often',
            tensionOrContradiction: 'I want rest but keep accepting more',
            patternObservations: ['Sunday dread before the week starts'],
          ),
        ),
      );

      expect(chips, isNotEmpty);
      expect(chips.any((chip) => chip.category == 'Belief Detected'), isTrue);
      expect(
        chips.any((chip) => chip.value.contains('Sundays')),
        isTrue,
      );
    });

    test('returns empty list for blank entries', () {
      final chips = EvidenceIndexingEngine.extract(
        _entry(
          transcript: '   ',
          reflection: const Reflection(
            mood: '',
            emotionalIntensity: 0,
            recurringThemes: [],
            exactLanguagePattern: '',
            concreteObservation: '',
            repeatedSignal: '',
          ),
        ),
      );

      expect(chips, isEmpty);
    });
  });
}