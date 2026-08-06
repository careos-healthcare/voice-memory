import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/patterns/evidence_first_pattern_copy.dart';
import 'package:voicememory_mobile/features/patterns/pattern_intelligence_pipeline.dart';
import 'package:voicememory_mobile/features/patterns/patterns_human_copy.dart';
import 'package:voicememory_mobile/features/patterns/transcript_evidence_extractor.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

JournalEntry _entry(String id, String transcript) {
  return JournalEntry(
    id: id,
    createdAt: DateTime(2026, 6, 10 + id.hashCode % 4, 10),
    transcript: transcript,
    durationSeconds: 30,
    reflection: Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 2,
      recurringThemes: const ['work'],
      exactLanguagePattern: 'pressure',
      concreteObservation: transcript,
      repeatedSignal: 'pressure',
    ),
  );
}

void main() {
  group('TranscriptEvidenceExtractor', () {
    test('finds repeated pressure and work phrases from transcripts', () {
      final phrases = TranscriptEvidenceExtractor.extractRepeatedPhrases([
        'There is pressure to get the work properly done with the correct standard.',
        'I need this to work and the pressure keeps building again.',
        'The correct standard matters and work properly feels hard today.',
      ]);

      expect(phrases.length, greaterThanOrEqualTo(2));
      expect(phrases.any((p) => p.toLowerCase().contains('pressure')), isTrue);
    });

    test('does not surface malformed n-grams', () {
      final phrases = TranscriptEvidenceExtractor.extractRepeatedPhrases([
        'follow a heavy should test to see if when follow around follow',
        'follow a heavy should test to see if again today',
      ]);

      expect(
        phrases.any((p) => p.toLowerCase().contains('follow a heavy')),
        isFalse,
      );
    });
  });

  group('EvidenceFirstPatternCopyResolver', () {
    test('produces evidence-first copy for pressure/work transcripts', () {
      final copy = EvidenceFirstPatternCopyResolver.resolve(
        EvidenceFirstPatternCopyInput(
          transcripts: [
            'There is pressure to get the work properly done with the correct standard.',
            'I need this to work and the pressure keeps building again.',
            'The correct standard matters and work properly feels hard today.',
          ],
          evidenceCount: 3,
          entryCount: 3,
          confidence: 0.55,
          possibleRepeat: true,
          analysisAvailable: true,
        ),
      );

      expect(copy.source, PatternCopySource.evidenceFirst);
      expect(copy.heroTitle, PatternHumanCopy.evidenceFirstHeroTitle);
      expect(copy.exactEvidencePhrases.length, greaterThanOrEqualTo(2));
      expect(
        copy.interpretation,
        PatternHumanCopy.evidenceFirstInterpretationPressure,
      );
      expect(
        copy.interpretation,
        isNot(contains('pushing past your own stopping point')),
      );
      expect(copy.interpretation, isNot(contains('doing more than you want')));
    });

    test('medium confidence avoids confident psychological interpretation', () {
      final bundle = PatternHumanCopyResolver.resolve(
        PatternHumanCopyInput(
          entryCount: 3,
          evidenceCount: 3,
          possibleRepeat: true,
          confidenceScore: 0.55,
          allTranscriptText: [
            'pressure to get the work properly done today',
            'pressure keeps building and work properly feels hard',
            'correct standard and pressure again this morning',
          ],
        ),
      );

      expect(bundle.exactEvidencePhrases, isNotEmpty);
      expect(bundle.mainObservation, isNot(contains('pushing past')));
      expect(
        bundle.mainObservation,
        isNot(contains('doing more than you want')),
      );
      expect(bundle.mainObservation, contains('may be less about the task'));
    });

    test('weak evidence uses fallback copy', () {
      final copy = EvidenceFirstPatternCopyResolver.resolve(
        const EvidenceFirstPatternCopyInput(
          transcripts: ['One lonely entry about work'],
          evidenceCount: 1,
          entryCount: 1,
          confidence: 0.1,
          analysisAvailable: false,
        ),
      );

      expect(copy.source, PatternCopySource.fallback);
      expect(copy.heroTitle, PatternHumanCopy.fallbackEvidenceFirstHeroTitle);
      expect(copy.exactEvidencePhrases, isEmpty);
      expect(
        copy.whatToNoticeNext,
        PatternHumanCopy.fallbackWhatToNoticeEvidence,
      );
    });

    test('pipeline shows repeated words before interpretation', () {
      final bundle = PatternIntelligencePipeline.build([
        _entry(
          'e1',
          'There is pressure to get the work properly done with the correct standard.',
        ),
        _entry(
          'e2',
          'I need this to work and the pressure keeps building again.',
        ),
        _entry(
          'e3',
          'The correct standard matters and work properly feels hard today.',
        ),
      ]);

      expect(bundle.humanCopy?.exactEvidencePhrases, isNotEmpty);
      expect(bundle.belief.evidenceSnippets, isNotEmpty);
      expect(
        bundle.belief.currentBelief,
        contains('may be less about the task'),
      );
      expect(
        bundle.belief.currentBelief,
        isNot(contains('You may do more when')),
      );
      expect(bundle.belief.currentBelief, isNot(contains('pushing past')));
    });
  });
}
