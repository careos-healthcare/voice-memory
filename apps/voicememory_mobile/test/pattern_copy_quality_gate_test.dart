import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_belief_thread_engine.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_evidence_heuristics.dart';
import 'package:voicememory_mobile/features/patterns/pattern_copy_quality_gate.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

JournalEntry _entry(String id, String transcript) {
  return JournalEntry(
    id: id,
    createdAt: DateTime(2026, 6, 10 + id.hashCode % 3, 10),
    transcript: transcript,
    durationSeconds: 30,
    reflection: const Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 2,
      recurringThemes: ['work'],
      exactLanguagePattern: 'pattern',
      concreteObservation: 'Work pressure showed up again today.',
      repeatedSignal: 'signal',
    ),
  );
}

void main() {
  group('PatternCopyQualityGate', () {
    test('rejects follow a heavy should', () {
      final result = PatternCopyQualityGate.gate('follow a heavy should');
      expect(result.usedFallback, isTrue);
      expect(result.copy, PatternCopyQualityGate.possibleThread);
    });

    test('rejects is test to see', () {
      final result = PatternCopyQualityGate.gate('is test to see');
      expect(result.usedFallback, isTrue);
    });

    test('rejects test to see if', () {
      final result = PatternCopyQualityGate.gate('test to see if');
      expect(result.usedFallback, isTrue);
    });

    test('rejects dangling should phrases', () {
      final result = PatternCopyQualityGate.gate('keep going when tired should');
      expect(result.usedFallback, isTrue);
      expect(result.reason, 'dangling_should');
    });

    test('shows generic fallback when phrase is rejected', () {
      final result = PatternCopyQualityGate.gate(
        'follow a heavy should',
        role: PatternCopyRole.phrase,
      );
      expect(result.copy, PatternCopyQualityGate.possibleThread);
    });

    test('allows pressure to make this work', () {
      final result = PatternCopyQualityGate.gate('pressure to make this work');
      expect(result.usedFallback, isFalse);
      expect(result.copy, 'pressure to make this work');
    });

    test('allows feeling behind', () {
      final result = PatternCopyQualityGate.gate('feeling behind');
      expect(result.usedFallback, isFalse);
      expect(result.copy, 'feeling behind');
    });

    test('rejects broken current belief sentences', () {
      final result = PatternCopyQualityGate.gate(
        'You may do more when follow a heavy should.',
        role: PatternCopyRole.belief,
      );
      expect(result.usedFallback, isTrue);
      expect(result.copy, PatternCopyQualityGate.currentBeliefFallback);
    });

    test('rejects iPad bad examples from malformed n-grams', () {
      expect(
        PatternCopyQualityGate.gateBelief(
          'You may do more when follow a heavy should.',
        ),
        PatternCopyQualityGate.currentBeliefFallback,
      );
      expect(
        PatternCopyQualityGate.gateSentence(
          'The pressure seems to return around follow a heavy should.',
        ),
        isNot(contains('follow a heavy should')),
      );
      expect(
        PatternCopyQualityGate.gateSentence(
          'Record another ordinary moment and notice whether follow a heavy should shows up again.',
        ),
        isNot(contains('follow a heavy should')),
      );
    });

    test('rejects legacy template belief sentences', () {
      final result = PatternCopyQualityGate.gate(
        'You may do more when pressure to make this work shows up again.',
        role: PatternCopyRole.belief,
      );
      expect(result.usedFallback, isTrue);
      expect(result.reason, 'legacy_template');
    });

    test('rejects what you feel you should do templates', () {
      expect(
        PatternCopyQualityGate.gateBelief(
          'You may do more when pressure from what you feel you should do.',
        ),
        PatternCopyQualityGate.currentBeliefFallback,
      );
    });
  });

  group('ArchiveEvidenceHeuristics quality gate integration', () {
    const heuristics = ArchiveEvidenceHeuristics();

    test('does not surface follow a heavy should in belief copy', () {
      final entries = [
        _entry(
          '1',
          'I test to see if I should keep going even when I feel exhausted today.',
        ),
        _entry(
          '2',
          'Another moment where I should keep pushing before I rest tonight.',
        ),
        _entry(
          '3',
          'I should follow through on work even when I want to stop today.',
        ),
      ];

      final analysis = heuristics.analyze(entries);
      expect(analysis.beliefLine, isEmpty);
      expect(analysis.whatToTestLine, isNull);
      expect(analysis.ohWowBody, isNull);
      expect(analysis.beliefLine.toLowerCase(), isNot(contains('follow a heavy should')));
      expect(analysis.beliefLine.toLowerCase(), isNot(contains('test to see')));
    });

    test('ArchiveBeliefThreadEngine never surfaces blocked test fragments', () {
      final entries = [
        _entry('1', 'I test to see if I should keep going even when I feel exhausted today.'),
        _entry('2', 'Another test to see if I should keep pushing before I rest tonight.'),
        _entry('3', 'I should follow through on work even when I want to stop today.'),
      ];

      final thread = const ArchiveBeliefThreadEngine().build(entries);
      expect(thread.currentBelief.toLowerCase(), isNot(contains('test to see')));
      expect(thread.currentBelief.toLowerCase(), isNot(contains('follow a heavy should')));
      expect(thread.whatToTest.toLowerCase(), isNot(contains('test to see')));
    });
  });
}
