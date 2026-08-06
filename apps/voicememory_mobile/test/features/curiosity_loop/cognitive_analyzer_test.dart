import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/curiosity_loop/domain/models/cognitive_biomarkers.dart';
import 'package:voicememory_mobile/features/curiosity_loop/domain/services/cognitive_analyzer.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

void main() {
  group('CognitiveAnalyzer', () {
    const analyzer = CognitiveAnalyzer();

    test('empty string returns baseline biomarkers', () {
      final result = analyzer.analyzeTranscript('');

      expect(
        result,
        const CognitiveBiomarkers(
          lexicalDiversity: 1.0,
          cohesionDrift: 0.0,
          emotionalVolatility: 0.0,
        ),
      );
    });

    group('lexical diversity', () {
      test('returns 1.0 for three or fewer words', () {
        expect(analyzer.analyzeTranscript('hello').lexicalDiversity, 1.0);
        expect(analyzer.analyzeTranscript('hello world').lexicalDiversity, 1.0);
        expect(
          analyzer.analyzeTranscript('one two three').lexicalDiversity,
          1.0,
        );
      });

      test('computes unique words divided by total words', () {
        expect(
          analyzer.analyzeTranscript('the the the cat').lexicalDiversity,
          0.5,
        );
        expect(
          analyzer.analyzeTranscript('the cat sat on the mat').lexicalDiversity,
          closeTo(5 / 6, 0.0001),
        );
        expect(
          analyzer
              .analyzeTranscript('repeat repeat repeat word word unique extra')
              .lexicalDiversity,
          closeTo(4 / 7, 0.0001),
        );
      });

      test('ignores punctuation and casing when tokenizing', () {
        expect(
          analyzer.analyzeTranscript('The, the. THE! cat?').lexicalDiversity,
          0.5,
        );
      });
    });

    group('cohesion drift', () {
      test('returns 0.0 for a single sentence', () {
        expect(
          analyzer
              .analyzeTranscript('Only one sentence without ending punctuation')
              .cohesionDrift,
          0.0,
        );
      });

      test('scores higher on disjointed sentence patterns', () {
        const stable = 'One two three. Four five six. Seven eight nine.';
        const disjointed =
            'One. One two three four five six seven eight nine ten eleven.';

        final stableScore = analyzer.analyzeTranscript(stable).cohesionDrift;
        final disjointedScore = analyzer
            .analyzeTranscript(disjointed)
            .cohesionDrift;

        expect(stableScore, 0.0);
        expect(disjointedScore, greaterThan(stableScore));
        expect(disjointedScore, greaterThan(0.5));
      });
    });

    group('emotional volatility', () {
      test('returns higher scores for emphatic transcripts', () {
        const calm = 'I felt calm and steady today.';
        const emphatic = 'I am SO angry!!! This is TERRIBLE!!!';

        final calmScore = analyzer.analyzeTranscript(calm).emotionalVolatility;
        final emphaticScore = analyzer
            .analyzeTranscript(emphatic)
            .emotionalVolatility;

        expect(emphaticScore, greaterThan(calmScore));
      });

      test('scores stay bounded between 0.0 and 1.0', () {
        final result = analyzer.analyzeTranscript(
          'WOW!!! NO WAY!!! STOP!!! THIS IS INSANE!!!',
        );

        expect(result.emotionalVolatility, inInclusiveRange(0.0, 1.0));
      });

      test('enrichEntry attaches biomarkers to journal entries', () {
        final enriched = analyzer.enrichEntry(
          JournalEntry(
            id: 'entry_1',
            createdAt: DateTime.utc(2026, 6, 12, 12),
            transcript: 'the the the cat',
            durationSeconds: 10,
            reflection: const Reflection(
              mood: 'neutral',
              emotionalIntensity: 1,
              recurringThemes: [],
              exactLanguagePattern: '',
              concreteObservation: 'Sample observation.',
              repeatedSignal: '',
            ),
          ),
        );

        expect(
          enriched.biomarkers,
          analyzer.analyzeTranscript('the the the cat'),
        );
      });
    });
  });
}
