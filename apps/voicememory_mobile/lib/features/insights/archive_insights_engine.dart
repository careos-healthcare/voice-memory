import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence.dart';
import '../discover/discover_local.dart';
import 'archive_insight.dart';
import 'archive_insight_mapper.dart';
import 'belief_evidence/belief_evidence_engine.dart';
import 'belief_evolution/belief_evolution_engine.dart';
import 'blind_spots/blind_spot_engine.dart';
import 'contradictions/contradiction_engine.dart';
import 'insight_quality.dart';
import 'predictions/prediction_engine.dart';

/// Orchestrates all insight engines and applies quality gates.
class ArchiveInsightsEngine {
  const ArchiveInsightsEngine();

  ArchiveInsightsSnapshot build({
    required List<JournalEntry> entries,
    DiscoverLocalFeed? discoverFeed,
    String? currentBelief,
    List<({String statement, int confidence})>? candidateBeliefs,
  }) {
    if (!archiveHasMinimumEvidence(entries)) {
      return ArchiveInsightsSnapshot.empty;
    }

    final beliefsInput =
        candidateBeliefs ?? _defaultCandidates(entries, discoverFeed);
    final beliefBundles = BeliefEvidenceEngine().build(
      entries: entries,
      candidateBeliefs: beliefsInput,
    );
    final beliefInsights = InsightQualityRules.filter(
      beliefBundles.map(ArchiveInsightMapper.fromBeliefBundle),
    )..sort((a, b) => b.confidence.compareTo(a.confidence));

    final contradictions = InsightQualityRules.filter(
      ContradictionInsightEngine()
          .build(entries: entries, currentBelief: currentBelief)
          .map(ArchiveInsightMapper.fromContradiction),
    );

    final evolution = InsightQualityRules.filter(
      BeliefEvolutionInsightEngine()
          .build(entries: entries, discoverFeed: discoverFeed)
          .map(ArchiveInsightMapper.fromEvolution),
    );

    final blindSpots = InsightQualityRules.filter(
      BlindSpotInsightEngine()
          .build(entries)
          .map(ArchiveInsightMapper.fromBlindSpot),
    );

    final predictions = InsightQualityRules.filter(
      PredictionInsightEngine()
          .build(entries)
          .map(ArchiveInsightMapper.fromPrediction),
    );

    final strongest = beliefInsights.isEmpty ? null : beliefInsights.first;
    final all = [
      ?strongest,
      ...contradictions,
      ...evolution,
      ...blindSpots,
      ...predictions,
    ];

    return ArchiveInsightsSnapshot(
      strongestBelief: strongest,
      contradictions: contradictions,
      evolution: evolution,
      blindSpots: blindSpots,
      predictions: predictions,
      allInsights: all,
    );
  }

  List<({String statement, int confidence})> _defaultCandidates(
    List<JournalEntry> entries,
    DiscoverLocalFeed? feed,
  ) {
    final out = <({String statement, int confidence})>[];
    final fromReflection = archiveBeliefFromReflections(entries);
    if (fromReflection != null && fromReflection.length >= 12) {
      out.add((statement: fromReflection, confidence: 68));
    }
    if (feed != null) {
      for (final item in feed.strengthened) {
        out.add((statement: item.title, confidence: 72));
      }
      for (final item in feed.newItems) {
        out.add((statement: item.title, confidence: 64));
      }
    }
    for (final e in archiveEligibleEvidenceEntries(entries).reversed.take(6)) {
      final obs = e.reflection.concreteObservation.trim();
      if (obs.length >= 16) {
        out.add((statement: obs, confidence: 60));
      }
    }
    return out;
  }
}
