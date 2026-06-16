import '../../../models/journal_entry.dart';
import '../../archive_evidence/archive_evidence.dart';
import '../../contradiction_detection/statement_analysis.dart';
import '../insight_quality.dart';
import '../insight_text_signals.dart';
import 'prediction_models.dart';

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
      _Pattern(
        id: 'pred-work-selfworth',
        triggerLabel: 'Work stress',
        triggerMarkers: InsightTextSignals.workStressMarkers,
        outcomeLabel: 'self-worth reflections',
        outcomeMarkers: InsightTextSignals.selfWorthMarkers,
        windowEntries: 4,
      ),
      _Pattern(
        id: 'pred-conflict-avoid',
        triggerLabel: 'Conflict',
        triggerMarkers: InsightTextSignals.conflictMarkers,
        outcomeLabel: 'avoidance language',
        outcomeMarkers: InsightTextSignals.avoidanceMarkers,
        windowEntries: 3,
      ),
      _Pattern(
        id: 'pred-uncertainty-overthink',
        triggerLabel: 'Uncertainty',
        triggerMarkers: InsightTextSignals.uncertaintyMarkers,
        outcomeLabel: 'overthinking language',
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
            triggerQuote:
                archiveStatementTexts(trigger).firstOrNull ??
                trigger.transcript,
            outcomeQuote:
                archiveStatementTexts(outcome).firstOrNull ??
                outcome.transcript,
            recordedAt: outcome.createdAt,
          ),
        );
        break;
      }
    }

    if (events.length < minOccurrences) return null;

    final summary =
        'When ${pattern.triggerLabel.toLowerCase()} appears, you often mention '
        '${pattern.outcomeLabel} in the next few reflections.';

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

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
