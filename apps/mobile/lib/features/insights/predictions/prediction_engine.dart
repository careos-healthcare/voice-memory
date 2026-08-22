import 'package:archiveme_mobile/features/archive_evidence/archive_evidence.dart';
import 'package:archiveme_mobile/features/contradiction_detection/statement_analysis.dart';
import 'package:archiveme_mobile/features/insights/insight_quality.dart';
import 'package:archiveme_mobile/features/insights/insight_text_signals.dart';
import 'package:archiveme_mobile/features/insights/predictions/prediction_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Recurring sequences in the journal — min 3 historical pairs.
class PredictionInsightEngine {
  const PredictionInsightEngine({
    this.minOccurrences = InsightQualityRules.minEvidenceCount,
  });

  final int minOccurrences;

  List<PredictionInsight> build(List<JournalEntry> entries) {
    final eligible = archiveEligibleEvidenceEntries(entries)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (eligible.length < minOccurrences + 1) return const [];

    final patterns = [
      const _Pattern(
        id: 'pred-work-selfworth',
        triggerLabel: 'Work stress',
        triggerMarkers: InsightTextSignals.workStressMarkers,
        outcomeLabel: 'language about self-worth',
        outcomeMarkers: InsightTextSignals.selfWorthMarkers,
        windowEntries: 4,
      ),
      const _Pattern(
        id: 'pred-conflict-avoid',
        triggerLabel: 'Conflict',
        triggerMarkers: InsightTextSignals.conflictMarkers,
        outcomeLabel: 'language about avoiding',
        outcomeMarkers: InsightTextSignals.avoidanceMarkers,
        windowEntries: 3,
      ),
      const _Pattern(
        id: 'pred-uncertainty-overthink',
        triggerLabel: 'Uncertainty',
        triggerMarkers: InsightTextSignals.uncertaintyMarkers,
        outcomeLabel: 'language about overthinking',
        outcomeMarkers: InsightTextSignals.overthinkingMarkers,
        windowEntries: 3,
      ),
    ];

    final insights = <PredictionInsight>[];
    for (final p in patterns) {
      final hit = _detectPattern(p, eligible);
      if (hit != null) insights.add(hit);
    }
    return insights;
  }

  PredictionInsight? _detectPattern(
    _Pattern pattern,
    List<JournalEntry> sorted,
  ) {
    final events = <PredictionEvent>[];

    for (var i = 0; i < sorted.length; i++) {
      final trigger = sorted[i];
      final triggerText = _blob(trigger);
      if (!InsightTextSignals.containsAny(
        triggerText,
        pattern.triggerMarkers,
      )) {
        continue;
      }

      final end = (i + pattern.windowEntries).clamp(0, sorted.length);
      for (var j = i + 1; j < end; j++) {
        final outcome = sorted[j];
        final outcomeText = _blob(outcome);
        if (!InsightTextSignals.containsAny(
          outcomeText,
          pattern.outcomeMarkers,
        )) {
          continue;
        }
        events.add(
          PredictionEvent(
            triggerEntryId: trigger.id,
            outcomeEntryId: outcome.id,
            triggerQuote: archiveQuotableStatementText(trigger) ?? '',
            outcomeQuote: archiveQuotableStatementText(outcome) ?? '',
            recordedAt: outcome.createdAt,
          ),
        );
        break;
      }
    }

    if (events.length < minOccurrences) return null;

    final summary =
        'When ${pattern.triggerLabel.toLowerCase()} appears, your archive noticed '
        '${pattern.outcomeLabel} in some of the next few reflections.';

    return PredictionInsight(
      id: pattern.id,
      title: 'What may happen next',
      summary: summary,
      confidence: (60 + events.length * 6).clamp(60, 90),
      evidenceCount: events.length,
      supportingEvents: events.take(6).toList(),
      outcomeDescription: pattern.outcomeLabel,
    );
  }

  String _blob(JournalEntry e) =>
      '${e.transcript} ${e.reflection.concreteObservation}'.toLowerCase();
}

class _Pattern {
  const _Pattern({
    required this.id,
    required this.triggerLabel,
    required this.triggerMarkers,
    required this.outcomeLabel,
    required this.outcomeMarkers,
    required this.windowEntries,
  });

  final String id;
  final String triggerLabel;
  final List<String> triggerMarkers;
  final String outcomeLabel;
  final List<String> outcomeMarkers;
  final int windowEntries;
}