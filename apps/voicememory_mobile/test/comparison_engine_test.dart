import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/comparison_engine/comparison_engine.dart';
import 'package:voicememory_mobile/features/comparison_engine/comparison_engine_model.dart';
import 'package:voicememory_mobile/features/comparison_engine/comparison_engine_prompt.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? DateTime(2026, 6, 12, 12),
  transcript: transcript,
  durationSeconds: 30,
  localAudioPath: '/tmp/$id.m4a',
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: '',
    concreteObservation: 'Work pressure showed up in this moment.',
    repeatedSignal: '',
  ),
);

void main() {
  group('ComparisonEnginePrompt', () {
    test('system prompt lists banned phrases and allowed labels', () {
      expect(ComparisonEnginePrompt.systemPrompt, contains('You always'));
      expect(ComparisonEnginePrompt.systemPrompt, contains('Early signal'));
      expect(
        ComparisonEnginePrompt.systemPrompt,
        contains('Not enough evidence'),
      );
      expect(
        ComparisonEnginePrompt.systemPrompt,
        contains('What appears to have repeated'),
      );
      expect(ComparisonEnginePrompt.allowedConfidenceLabels.length, 9);
    });

    test('violates banned comparison phrases', () {
      expect(
        ComparisonEnginePrompt.violatesBannedPhrase('You always say yes.'),
        isTrue,
      );
      expect(
        ComparisonEnginePrompt.violatesBannedPhrase(
          'This means you are afraid.',
        ),
        isTrue,
      );
      expect(
        ComparisonEnginePrompt.violatesBannedPhrase(
          'Your pattern is avoidance.',
        ),
        isTrue,
      );
      expect(
        ComparisonEnginePrompt.violatesBannedPhrase(
          'You have a deep fear of failure.',
        ),
        isTrue,
      );
      expect(
        ComparisonEnginePrompt.violatesBannedPhrase(
          'Both moments may touch on saying yes.',
        ),
        isFalse,
      );
    });

    test('sanitizeLine replaces banned phrasing with fallback', () {
      expect(
        ComparisonEnginePrompt.sanitizeLine(
          'Your pattern is saying yes too fast.',
          fallback: 'Something similar may be showing up.',
        ),
        'Something similar may be showing up.',
      );
    });
  });

  group('ComparisonEngineOutput', () {
    test('formatStructuredSummary includes required elements', () {
      const output = ComparisonEngineOutput(
        confidenceLabel: ComparisonConfidenceLabel.possibleRepeat,
        whatAppearsRepeated: 'Saying yes before checking capacity.',
        connectedMomentDayTime: '10 June 2026 · 9:15 AM',
        connectedEntryId: 'a',
        whatChanged: 'It showed up around work again.',
        thinEvidencePhrase: ComparisonEnginePrompt.thinEvidenceDefault,
      );

      final summary = output.formatStructuredSummary();
      expect(summary, contains('Confidence: Possible repeat'));
      expect(summary, contains('What appears to have repeated:'));
      expect(summary, contains('Connects to: 10 June 2026 · 9:15 AM'));
      expect(
        summary,
        contains('What changed: It showed up around work again.'),
      );
      expect(summary, contains(ComparisonEnginePrompt.thinEvidenceDefault));
    });

    test('confidence labels match allowed list exactly', () {
      for (final label in ComparisonConfidenceLabel.values) {
        expect(
          ComparisonEnginePrompt.allowedConfidenceLabels,
          contains(label.label),
        );
      }
    });
  });

  group('ComparisonEngine', () {
    const engine = ComparisonEngine();

    test('grounded repeat produces structured related output', () {
      final result = engine.build([
        _entry(
          id: 'a',
          transcript:
              'I had no capacity but I said yes again to the extra meeting today.',
          createdAt: DateTime(2026, 6, 10, 9, 15),
        ),
        _entry(
          id: 'b',
          transcript:
              'Same thing — said yes when I had no capacity for one more thing.',
          createdAt: DateTime(2026, 6, 11, 18, 30),
        ),
      ]);

      expect(result.hasComparison, isTrue);
      expect(result.isRelated, isTrue);
      final output = result.output!;
      expect(output.whatAppearsRepeated, isNotEmpty);
      expect(output.connectedMomentDayTime, contains('10 June 2026'));
      expect(output.connectedMomentDayTime, contains('9:15 AM'));
      expect(output.connectedEntryId, 'a');
      expect(output.whatChanged, isNotNull);
      expect(
        ComparisonEnginePrompt.violatesBannedPhrase(output.whatAppearsRepeated),
        isFalse,
      );
      expect(
        ComparisonEnginePrompt.allowedConfidenceLabels,
        contains(output.confidenceLabel.label),
      );
    });

    test('unrelated entries stay unrelated without fake pattern', () {
      final result = engine.build([
        _entry(
          id: 'a',
          transcript:
              'A calm afternoon walk helped me slow down before dinner.',
        ),
        _entry(
          id: 'b',
          transcript: 'I reorganized my bookshelf and found an old notebook.',
        ),
      ]);

      expect(result.isRelated, isFalse);
      expect(result.output, isNull);
    });

    test('banned phrasing never survives in whatAppearsRepeated', () {
      final result = engine.build([
        _entry(
          id: 'a',
          transcript:
              'Your pattern is saying yes. I said yes again without capacity today.',
        ),
        _entry(
          id: 'b',
          transcript:
              'Your pattern is saying yes. Same yes again without capacity today.',
        ),
      ]);

      final repeated = result.output?.whatAppearsRepeated ?? '';
      expect(repeated.toLowerCase(), isNot(startsWith('your pattern is')));
    });
  });
}
