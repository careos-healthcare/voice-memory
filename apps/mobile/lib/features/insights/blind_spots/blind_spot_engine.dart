import 'package:archiveme_mobile/features/archive_evidence/archive_evidence.dart';
import 'package:archiveme_mobile/features/contradiction_detection/statement_analysis.dart';
import 'package:archiveme_mobile/features/fact_ledger/fact_ledger_citation_service.dart';
import 'package:archiveme_mobile/features/insights/blind_spots/blind_spot_models.dart';
import 'package:archiveme_mobile/features/insights/insight_evidence.dart';
import 'package:archiveme_mobile/features/insights/insight_quality.dart';
import 'package:archiveme_mobile/features/insights/insight_text_signals.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Measurable gaps: frequent topic vs rare positive mention — no speculation.
class BlindSpotInsightEngine {
  const BlindSpotInsightEngine({
    this.minSupportingReferences = InsightQualityRules.minEvidenceCount,
  });

  final int minSupportingReferences;

  List<BlindSpotInsight> build(List<JournalEntry> entries) {
    final eligible = archiveEligibleEvidenceEntries(entries);
    if (eligible.length < minSupportingReferences) return const [];

    final total = eligible.length;
    final insights = <BlindSpotInsight>[];

    for (final topic in _trackedTopics) {
      final spot = _topicBlindSpot(topic, eligible, total);
      if (spot != null) insights.add(spot);
    }

    insights.addAll(_avoidanceSpots(eligible, total));

    insights.sort((a, b) => b.confidence.compareTo(a.confidence));
    return insights.take(5).toList();
  }

  BlindSpotInsight? _topicBlindSpot(
    String topic,
    List<JournalEntry> entries,
    int total,
  ) {
    final mentions = <JournalEntry>[];
    var positiveMentions = 0;

    for (final e in entries) {
      final blob = '${e.transcript} ${e.reflection.concreteObservation}'
          .toLowerCase();
      if (!blob.contains(topic)) continue;
      mentions.add(e);
      if (InsightTextSignals.containsAny(
        blob,
        InsightTextSignals.positiveMarkers,
      )) {
        positiveMentions++;
      }
    }

    if (mentions.length < minSupportingReferences) return null;

    final pct = ((mentions.length / total) * 100).round();
    if (pct < 25) return null;
    if (positiveMentions >= mentions.length ~/ 3) return null;

    final evidence = mentions
        .take(5)
        .map(
          (e) {
            final rawQuote =
                archiveStatementTexts(e).firstOrNull ?? e.transcript;
            return InsightEvidenceLine(
              entryId: e.id,
              quote: FactLedgerCitationService.resolve(
                entryId: e.id,
                fallback: rawQuote,
              ),
              recordedAt: e.createdAt,
            );
          },
        )
        .toList();

    final title = _topicLabel(topic);
    final summary =
        'Based on these entries, $title appears in $pct% of reflections, but '
        'satisfaction language shows up in only $positiveMentions of '
        '${mentions.length} mentions.';

    return BlindSpotInsight(
      id: 'blind-$topic-frequency',
      title: title,
      summary: summary,
      confidence: (58 + pct ~/ 4).clamp(55, 88),
      evidenceCount: mentions.length,
      supportingEvidence: evidence,
      metricLabel: 'Topic share',
      metricValue: '$pct% of reflections',
    );
  }

  List<BlindSpotInsight> _avoidanceSpots(
    List<JournalEntry> entries,
    int total,
  ) {
    final achievementHits = <JournalEntry>[];
    final satisfactionHits = <JournalEntry>[];

    for (final e in entries) {
      final lower = '${e.transcript} ${e.reflection.concreteObservation}'
          .toLowerCase();
      if (lower.contains('achiev') ||
          lower.contains('prove') ||
          lower.contains('succeed')) {
        achievementHits.add(e);
      }
      if (InsightTextSignals.containsAny(
            lower,
            InsightTextSignals.positiveMarkers,
          ) &&
          (lower.contains('satisf') ||
              lower.contains('enough') ||
              lower.contains('content'))) {
        satisfactionHits.add(e);
      }
    }

    if (achievementHits.length < minSupportingReferences ||
        satisfactionHits.length >= achievementHits.length ~/ 2) {
      return const [];
    }

    final evidence = achievementHits
        .take(4)
        .map(
          (e) {
            final rawQuote =
                archiveStatementTexts(e).firstOrNull ?? e.transcript;
            return InsightEvidenceLine(
              entryId: e.id,
              quote: FactLedgerCitationService.resolve(
                entryId: e.id,
                fallback: rawQuote,
              ),
              recordedAt: e.createdAt,
            );
          },
        )
        .toList();

    return [
      BlindSpotInsight(
        id: 'blind-achievement-satisfaction',
        title: 'Achievement mentions without satisfaction language',
        summary:
            'Your archive noticed achievement language in ${achievementHits.length} of '
            '$total reflections, with satisfaction language in only '
            '${satisfactionHits.length} mentions.',
        confidence: 64,
        evidenceCount: achievementHits.length,
        supportingEvidence: evidence,
        metricLabel: 'Achievement mentions',
        metricValue: '${achievementHits.length} reflections',
      ),
    ];
  }

  static const _trackedTopics = [
    'work',
    'relationship',
    'family',
    'money',
    'health',
  ];

  String _topicLabel(String topic) => switch (topic) {
    'work' => 'Work',
    'relationship' => 'Relationships',
    'family' => 'Family',
    'money' => 'Money',
    'health' => 'Health',
    _ => topic,
  };
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}