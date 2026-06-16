import 'archive_insight.dart';
import 'belief_evidence/belief_evidence_bundle.dart';
import 'belief_evolution/belief_evolution_models.dart';
import 'blind_spots/blind_spot_models.dart';
import 'contradictions/contradiction_models.dart';
import 'insight_evidence.dart';
import 'predictions/prediction_models.dart';

/// Maps engine outputs into unified [ArchiveInsight] cards.
abstract class ArchiveInsightMapper {
  ArchiveInsightMapper._();

  static ArchiveInsight fromBeliefBundle(BeliefEvidenceBundle bundle) {
    return ArchiveInsight(
      id: bundle.beliefId,
      type: ArchiveInsightType.belief,
      title: bundle.statement,
      summary: bundle.whyArchiveBelievesThis,
      confidence: bundle.confidence,
      evidenceCount: bundle.supportingReflectionIds.length,
      supportingEvidence: bundle.supportingEvidence,
      createdAt: bundle.supportingEvidence.last.recordedAt,
      whyItMatters: bundle.archiveConclusion,
      archiveConclusion: bundle.archiveConclusion,
    );
  }

  static ArchiveInsight fromContradiction(ContradictionInsight c) {
    final lines = <InsightEvidenceLine>[];
    for (final block in c.evidence) {
      lines.addAll(block.lines);
    }
    final title = c.statedDesire != null && c.statedAction != null
        ? 'Desire vs action'
        : 'When patterns pull differently';

    return ArchiveInsight(
      id: c.id,
      type: ArchiveInsightType.contradiction,
      title: title,
      summary: c.summary,
      confidence: c.confidence,
      evidenceCount: c.evidenceCount,
      supportingEvidence: lines,
      createdAt: c.lastSeen,
      archiveConclusion: c.recurringPattern,
    );
  }

  static ArchiveInsight fromEvolution(BeliefEvolutionInsight e) {
    return ArchiveInsight(
      id: e.id,
      type: ArchiveInsightType.evolution,
      title: e.statement,
      summary: e.summary,
      confidence: e.confidence,
      evidenceCount: e.evidenceCount,
      supportingEvidence: e.supportingEvidence,
      createdAt: e.record.lastSeen,
      whyItMatters: e.record.confidenceHistory.isNotEmpty
          ? 'Mentions in your reflections grew from '
                '${e.record.confidenceHistory.first.evidenceCount} '
                'to ${e.record.confidenceHistory.last.evidenceCount}.'
          : null,
    );
  }

  static ArchiveInsight fromBlindSpot(BlindSpotInsight b) {
    return ArchiveInsight(
      id: b.id,
      type: ArchiveInsightType.blindSpot,
      title: b.title,
      summary: b.summary,
      confidence: b.confidence,
      evidenceCount: b.evidenceCount,
      supportingEvidence: b.supportingEvidence,
      createdAt: b.supportingEvidence.last.recordedAt,
      archiveConclusion: '${b.metricLabel}: ${b.metricValue}',
    );
  }

  static ArchiveInsight fromPrediction(PredictionInsight p) {
    final lines = p.supportingEvents
        .map(
          (e) => InsightEvidenceLine(
            entryId: e.outcomeEntryId,
            quote: '${e.triggerQuote} → ${e.outcomeQuote}',
            recordedAt: e.recordedAt,
            label: 'Moment',
          ),
        )
        .toList();

    return ArchiveInsight(
      id: p.id,
      type: ArchiveInsightType.prediction,
      title: p.title,
      summary: p.summary,
      confidence: p.confidence,
      evidenceCount: p.evidenceCount,
      supportingEvidence: lines,
      createdAt: lines.last.recordedAt,
      archiveConclusion: 'Often followed by ${p.outcomeDescription}.',
    );
  }
}
