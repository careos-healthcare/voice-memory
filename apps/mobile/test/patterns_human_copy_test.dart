import 'package:archiveme_mobile/features/patterns/pattern_copy_quality_gate.dart';
import 'package:archiveme_mobile/features/patterns/pattern_display_cache_cleanup.dart';
import 'package:archiveme_mobile/features/patterns/pattern_display_copy_gate.dart';
import 'package:archiveme_mobile/features/patterns/pattern_intelligence_pipeline.dart';
import 'package:archiveme_mobile/features/patterns/patterns_human_copy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _pressureEntry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt ?? DateTime(2026, 6, 12, 10),
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
  group('PatternHumanCopyResolver', () {
    test('pressure-related entries return evidence-first copy', () {
      final entries = [
        _pressureEntry(
          id: 'e1',
          transcript:
              'There is pressure to get the work properly done with the correct standard.',
          createdAt: DateTime(2026, 6, 10),
        ),
        _pressureEntry(
          id: 'e2',
          transcript:
              'I need this to work and the pressure keeps building again.',
          createdAt: DateTime(2026, 6, 11),
        ),
        _pressureEntry(
          id: 'e3',
          transcript:
              'The correct standard matters and work properly feels hard today.',
          createdAt: DateTime(2026, 6, 12),
        ),
      ];

      final input = PatternHumanCopyInput.fromEntries(entries);
      final copy = PatternHumanCopyResolver.resolve(input);

      expect(
        copy.kind == PatternHumanCopyKind.evidenceFirst ||
            copy.kind == PatternHumanCopyKind.highConfidencePressure,
        isTrue,
      );
      expect(copy.heroTitle, PatternHumanCopy.evidenceFirstHeroTitle);
      expect(copy.exactEvidencePhrases, isNotEmpty);
      expect(copy.mainObservation, isNot(contains('pushing past')));
    });

    test('weak entries return conservative fallback', () {
      final copy = PatternHumanCopyResolver.resolve(
        const PatternHumanCopyInput(
          entryCount: 1,
          evidenceCount: 1,
          confidenceScore: 0.1,
          analysisAvailable: false,
        ),
      );

      expect(copy.kind, PatternHumanCopyKind.fallback);
      expect(copy.heroTitle, PatternHumanCopy.fallbackEvidenceFirstHeroTitle);
      expect(
        copy.mainObservation,
        PatternHumanCopy.fallbackMainObservationEvidence,
      );
    });

    test('allows natural short evidence words in isolation', () {
      for (final phrase in ['pressure', 'work', 'standard']) {
        expect(
          PatternCopyQualityGate.gate(phrase).usedFallback,
          isFalse,
          reason: phrase,
        );
      }
    });

    test('rejects legacy template sentences', () {
      for (final bad in [
        'You may do more when follow a heavy should.',
        'The pressure seems to return around is test to see.',
        'You may do more when pressure from what you feel you should do.',
      ]) {
        expect(PatternDisplayCopyGate.containsBlockedCopy(bad), isTrue);
      }
    });

    test('pipeline replaces blocked candidate copy with safe bundle', () {
      final bundle = PatternIntelligencePipeline.build([
        _pressureEntry(
          id: 'e1',
          transcript: 'pressure to get the work properly done today',
          createdAt: DateTime(2026, 6, 10),
        ),
        _pressureEntry(
          id: 'e2',
          transcript: 'pressure keeps building and work properly feels hard',
          createdAt: DateTime(2026, 6, 11),
        ),
        _pressureEntry(
          id: 'e3',
          transcript: 'correct standard and pressure again this morning',
          createdAt: DateTime(2026, 6, 12),
        ),
      ]);

      expect(
        bundle.belief.currentBelief,
        isNot(contains('follow a heavy should')),
      );
      expect(
        bundle.belief.currentBelief,
        isNot(contains('You may do more when')),
      );
      expect(bundle.humanCopy?.exactEvidencePhrases, isNotEmpty);
    });
  });

  group('PatternDisplayCacheCleanup v4', () {
    test('threadJsonHasBadCopy detects legacy template strings', () {
      expect(
        PatternDisplayCacheCleanup.threadJsonHasBadCopy({
          'id': 'bad',
          'title': 'You may do more when follow a heavy should.',
          'createdAt': DateTime(2026, 6).toIso8601String(),
          'updatedAt': DateTime(2026, 6, 2).toIso8601String(),
          'watchForText': 'whether follow a heavy should shows up again',
          'chips': <String>[],
          'status': 'active',
          'daysActive': 2,
          'lastResult': 'unclear',
          'nextPrompt':
              'Record another ordinary moment and notice whether follow a heavy should shows up again.',
        }),
        isTrue,
      );
    });
  });
}