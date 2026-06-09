import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/insights/archive_insight.dart';
import 'package:voicememory_mobile/features/insights/archive_insights_engine.dart';
import 'package:voicememory_mobile/features/insights/insight_evidence.dart';
import 'package:voicememory_mobile/features/insights/insight_quality.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';

JournalEntry _mockEntry(
  String id,
  String transcript, {
  List<String> themes = const [],
  String observation = '',
}) {
  return JournalEntry(
    id: id,
    createdAt: DateTime(2025, 5, int.parse(id) + 1),
    transcript: transcript,
    durationSeconds: 45,
    reflection: Reflection(
      mood: 'neutral',
      emotionalIntensity: 2,
      recurringThemes: themes,
      exactLanguagePattern: 'pattern',
      concreteObservation: observation,
      repeatedSignal: 'signal',
    ),
    syncStatus: SyncStatus.localOnly,
  );
}

/// Rich mock corpus for evidence-backed engines (transcripts ≥ 24 chars).
List<JournalEntry> mockInsightCorpus() {
  return [
    _mockEntry(
      '1',
      'I want more freedom in my schedule but I keep taking on responsibility for the team.',
      themes: ['work'],
    ),
    _mockEntry(
      '2',
      'Again I want freedom yet I volunteered to lead the project and handle it alone.',
      themes: ['work'],
    ),
    _mockEntry(
      '3',
      'I need space and less pressure, then I took on another responsibility at work.',
      themes: ['work'],
    ),
    _mockEntry(
      '4',
      'Work stress is crushing me this week with deadlines everywhere.',
      themes: ['work', 'stress'],
    ),
    _mockEntry(
      '5',
      'I feel I have to prove myself and I am not good enough after that deadline.',
      themes: ['self-worth'],
    ),
    _mockEntry(
      '6',
      'Had a hard conversation and conflict with my manager about priorities.',
      themes: ['work'],
    ),
    _mockEntry(
      '7',
      'I avoided replying and put off the follow-up email after the disagreement.',
      themes: ['avoidance'],
    ),
    _mockEntry(
      '8',
      'I am not sure what to do and feel uncertain about the next step.',
      themes: ['uncertainty'],
    ),
    _mockEntry(
      '9',
      'I keep overthinking and going in circles with what if scenarios.',
      themes: ['overthinking'],
    ),
    _mockEntry(
      '10',
      'Work dominates my reflections — achievement and proving myself again.',
      themes: ['work', 'achievement'],
      observation: 'Work and achievement language without satisfaction.',
    ),
    _mockEntry(
      '11',
      'More work stress and deadline pressure before the review cycle.',
      themes: ['work'],
    ),
    _mockEntry(
      '12',
      'Another wave of prove myself and not ready for the promotion conversation.',
      themes: ['self-worth'],
    ),
    _mockEntry(
      '13',
      'Conflict at home turned into tension with my partner.',
      themes: ['relationship'],
    ),
    _mockEntry(
      '14',
      'I stayed quiet and did not reply to avoid another argument.',
      themes: ['avoidance'],
    ),
    _mockEntry(
      '15',
      'Uncertain again about money and might be wrong about the plan.',
      themes: ['money'],
    ),
    _mockEntry(
      '16',
      'Spinning on what if and can\'t decide about the job offer.',
      themes: ['overthinking'],
    ),
    _mockEntry(
      '17',
      'More work stress before the deadline and overwhelmed at work again.',
      themes: ['work'],
    ),
    _mockEntry(
      '18',
      'I have to prove myself again and worry I am not good enough.',
      themes: ['self-worth'],
    ),
    _mockEntry(
      '19',
      'Another conflict at work after the hard conversation with leadership.',
      themes: ['work'],
    ),
    _mockEntry(
      '20',
      'I put off replying and avoided the follow-up after the disagreement.',
      themes: ['avoidance'],
    ),
    _mockEntry(
      '21',
      'I am uncertain about the offer and not sure what to choose.',
      themes: ['uncertainty'],
    ),
    _mockEntry(
      '22',
      'Keeps replaying what if scenarios and I overthink every option.',
      themes: ['overthinking'],
    ),
  ];
}

void main() {
  group('ArchiveInsightsEngine', () {
    test('returns empty snapshot without minimum evidence', () {
      final snap = const ArchiveInsightsEngine().build(entries: const []);
      expect(snap.allInsights, isEmpty);
    });

    test('mock corpus produces evidence-backed insights', () {
      final entries = mockInsightCorpus();
      final snap = const ArchiveInsightsEngine().build(
        entries: entries,
        candidateBeliefs: [
          (statement: 'I need to prove myself at work', confidence: 74),
        ],
      );

      expect(entries.length, greaterThanOrEqualTo(InsightQualityRules.minEvidenceCount));

      for (final insight in snap.allInsights) {
        expect(
          InsightQualityRules.passes(insight),
          isTrue,
          reason: 'Failed quality: ${insight.type} ${insight.title}',
        );
        expect(insight.supportingEvidence, isNotEmpty);
        expect(
          insight.supportingEvidence.any((e) => e.quote.trim().length >= 12),
          isTrue,
        );
      }

      // Sample outputs (printed for deliverable review).
      void logSection(String name, List<ArchiveInsight> items) {
        if (items.isEmpty) return;
        // ignore: avoid_print
        print('\n=== $name ===');
        for (final i in items.take(2)) {
          // ignore: avoid_print
          print('What: ${i.title}');
          // ignore: avoid_print
          print('Why: ${i.summary}');
          // ignore: avoid_print
          print(
            'Evidence: ${i.evidenceCount} refs, ${i.confidence}% — '
            '“${i.supportingEvidence.first.quote}”',
          );
        }
      }

      logSection('Strongest belief', [
        if (snap.strongestBelief != null) snap.strongestBelief!,
      ]);
      logSection('Contradictions', snap.contradictions);
      logSection('Evolution', snap.evolution);
      logSection('Blind spots', snap.blindSpots);
      logSection('Predictions', snap.predictions);

      expect(
        snap.contradictions.any(
          (c) => c.summary.toLowerCase().contains('freedom'),
        ),
        isTrue,
      );
      expect(snap.predictions, isNotEmpty);
    });

    test('rejects generic fluff phrases', () {
      final generic = ArchiveInsight(
        id: 'bad',
        type: ArchiveInsightType.belief,
        title: 'You value growth',
        summary: 'You care about relationships.',
        confidence: 80,
        evidenceCount: 5,
        supportingEvidence: [
          InsightEvidenceLine(
            entryId: '1',
            quote: 'You value growth in every way possible here.',
            recordedAt: DateTime.now(),
          ),
        ],
        createdAt: DateTime.now(),
      );
      expect(InsightQualityRules.passes(generic), isFalse);
    });
  });
}
