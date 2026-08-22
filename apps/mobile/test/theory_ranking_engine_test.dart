import 'package:archiveme_mobile/features/archive_theory/theory_ranking_engine.dart';
import 'package:archiveme_mobile/features/archive_theory/transcript_citation_resolver.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/archive_quality_personas.dart';

void main() {
  const engine = TheoryRankingEngine();

  test('relationship persona picks partner belief not work delivery', () {
    final entries = buildPersonaArchive(
      ArchiveQualityPersona.relationshipFocused,
      count: 100,
    );
    final eligible =
        entries.where((e) => e.transcript.trim().length >= 24).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final result = engine.rank(entries: entries, eligible: eligible);
    final primary = result.primaryTheory;
    expect(primary, isNotNull);
    final lower = primary!.statement.toLowerCase();
    expect(lower, contains('partner'));
    expect(lower, isNot(contains('work delivery pressure dominates')));
    expect(primary.evidenceCount, greaterThanOrEqualTo(3));
    expect(primary.confidencePercent, greaterThanOrEqualTo(15));
  });

  test('rejects trait templates and low-evidence statements', () {
    final entries = [
      JournalEntry(
        id: '1',
        createdAt: DateTime.utc(2026),
        transcript:
            'Work delivery pressure dominates my week and the roadmap never ends.',
        durationSeconds: 30,
        reflection: const Reflection(
          mood: 'thoughtful',
          emotionalIntensity: 2,
          recurringThemes: ['career'],
          exactLanguagePattern: '',
          concreteObservation: 'Work delivery pressure dominates my week.',
          repeatedSignal: '',
        ),
      ),
    ];
    final result = engine.rank(entries: entries, eligible: entries);
    expect(result.primaryTheory, isNull);
    expect(result.rejectedCandidates, greaterThan(0));
  });

  test('attaches citation metadata to supporting evidence quotes', () {
    final entries = buildPersonaArchive(
      ArchiveQualityPersona.relationshipFocused,
      count: 100,
    );
    final eligible =
        entries.where((e) => e.transcript.trim().length >= 24).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final result = engine.rank(entries: entries, eligible: eligible);
    final primary = result.primaryTheory;
    expect(primary, isNotNull);
    expect(primary!.supportingEvidence, isNotEmpty);

    for (final quote in primary.supportingEvidence) {
      expect(quote.audioId, isNotEmpty);
      expect(quote.chunkId, isNotEmpty);
      expect(quote.startTimestampMs, isNotNull);
      expect(quote.endTimestampMs, isNotNull);
      expect(quote.endTimestampMs!, greaterThan(quote.startTimestampMs!));
      expect(quote.hasCitationPlayback, isTrue);
    }
  });

  group('TranscriptCitationResolver', () {
    const resolver = TranscriptCitationResolver();

    test('estimates playback timestamps from quote span', () {
      const transcript =
          'My partner and I keep arguing about chores and I feel unseen at home.';
      final entry = JournalEntry(
        id: 'entry-1',
        createdAt: DateTime.utc(2026),
        transcript: transcript,
        durationSeconds: 60,
        reflection: const Reflection(
          mood: 'thoughtful',
          emotionalIntensity: 2,
          recurringThemes: ['relationship'],
          exactLanguagePattern: '',
          concreteObservation: 'Partner arguments.',
          repeatedSignal: 'partner',
        ),
      );

      final quote = resolver.quoteForBelief(entry, 'partner conflict at home');
      final citation = resolver.resolve(entry: entry, quote: quote);

      expect(citation.audioId, 'entry-1');
      expect(citation.chunkId, 'entry-1:${citation.startTimestampMs}');
      expect(citation.startTimestampMs, greaterThanOrEqualTo(0));
      expect(citation.endTimestampMs, lessThanOrEqualTo(60000));
      expect(citation.endTimestampMs, greaterThan(citation.startTimestampMs));
    });
  });
}
