import '../../models/journal_entry.dart';
import '../archive_analyst/archive_analyst_belief_catalog.dart';
import '../archive_analyst/archive_belief_visibility.dart';
import '../archive_analyst/archive_analyst_confidence_engine.dart';
import '../archive_analyst/topical_counter_evidence.dart';
import '../archive_surprises/archive_surprises_models.dart';
import '../archive_v1/archive_v1_models.dart';
import '../belief_evolution/belief_evolution_models.dart';
import '../archive_state_object/archive_state_object.dart';
import 'theory_ranking_models.dart';

/// Selects one primary theory for all archive surfaces from shared evidence rules.
class TheoryRankingEngine {
  const TheoryRankingEngine({
    this.catalog = const ArchiveAnalystBeliefCatalog(),
    this.confidenceEngine = const ArchiveAnalystConfidenceEngine(),
    this.topicalCounter = const TopicalCounterEvidence(),
    this.minConfidencePercent = ArchiveBeliefVisibility.minConfidencePercent,
    this.minEvidenceCount = ArchiveBeliefVisibility.minEvidenceCount,
    this.maxSecondary = 5,
  });

  final ArchiveAnalystBeliefCatalog catalog;
  final ArchiveAnalystConfidenceEngine confidenceEngine;
  final TopicalCounterEvidence topicalCounter;
  final int minConfidencePercent;
  final int minEvidenceCount;
  final int maxSecondary;

  TheoryRankingResult rank({
    required List<JournalEntry> entries,
    required List<JournalEntry> eligible,
    ArchiveStateObjectV3? state,
    BeliefEvolutionState? evolution,
    List<ArchiveV1Contradiction> contradictions = const [],
    List<ArchiveSurpriseObservation> surprises = const [],
  }) {
    final contradictionEntryIds =
        contradictions.expand((c) => c.entryIds).toSet();
    final maxCtr = contradictions.isEmpty
        ? 0
        : contradictions
            .map((c) => c.confidenceScore)
            .reduce((a, b) => a > b ? a : b);

    final candidates = catalog.collect(
      entries: entries,
      state: state,
      evolution: evolution,
    );

    final eligibleRanked = <RankedTheory>[];
    var rejected = 0;

    for (final c in candidates) {
      final statement = c.statement.trim();
      if (ArchiveBeliefVisibility.isTraitOrPlaceholder(statement)) {
        rejected++;
        continue;
      }

      final split = confidenceEngine.splitEntries(
        beliefText: statement,
        eligible: eligible,
        contradictionEntryIds: contradictionEntryIds,
      );
      final support = split.supporting.length;
      final counter = split.counter.length;

      final confidence = confidenceEngine.score(
        supportingCount: support,
        counterCount: counter,
        recencyRatio: split.recencyRatio,
        consistencyRatio: split.consistencyRatio,
        maxContradictionScore: maxCtr,
        stale: split.stale,
      );

      if (confidence < minConfidencePercent || support < minEvidenceCount) {
        rejected++;
        continue;
      }

      final rankScore = _rankScore(
        statement: statement,
        support: support,
        counter: counter,
        rawCounter: split.rawCounterCount,
        consistencyRatio: split.consistencyRatio,
        recencyRatio: split.recencyRatio,
        contradictions: contradictions,
        surprises: surprises,
      );

      eligibleRanked.add(
        RankedTheory(
          candidateId: c.id,
          statement: statement,
          source: c.source,
          confidencePercent: confidence,
          evidenceCount: support,
          counterEvidenceCount: counter,
          rankScore: rankScore,
          supportingEntries: split.supporting,
          lastUpdated: split.supporting.isNotEmpty
              ? split.supporting.last.createdAt
              : c.lastUpdated,
        ),
      );
    }

    eligibleRanked.sort((a, b) {
      final byRank = b.rankScore.compareTo(a.rankScore);
      if (byRank != 0) return byRank;
      final byEv = b.evidenceCount.compareTo(a.evidenceCount);
      if (byEv != 0) return byEv;
      return b.confidencePercent.compareTo(a.confidencePercent);
    });

    return TheoryRankingResult(
      primaryTheory: eligibleRanked.isEmpty ? null : eligibleRanked.first,
      secondaryTheories: eligibleRanked.length <= 1
          ? const []
          : eligibleRanked.skip(1).take(maxSecondary).toList(),
      rejectedCandidates: rejected,
      eligibleCandidateCount: eligibleRanked.length,
    );
  }

  int _rankScore({
    required String statement,
    required int support,
    required int counter,
    required int rawCounter,
    required double consistencyRatio,
    required double recencyRatio,
    required List<ArchiveV1Contradiction> contradictions,
    required List<ArchiveSurpriseObservation> surprises,
  }) {
    final volume = (support * 3).clamp(0, 35);
    final consistency = (consistencyRatio * 20).round().clamp(0, 20);
    final recency = (recencyRatio * 15).round().clamp(0, 15);
    final contradiction = _contradictionRelevanceScore(statement, contradictions);
    final surprise = _surpriseScore(statement, surprises);
    final counterQuality = _counterQualityScore(
      support: support,
      counter: counter,
      rawCounter: rawCounter,
    );

    return (volume + consistency + recency + contradiction + surprise + counterQuality)
        .clamp(0, 100);
  }

  int _contradictionRelevanceScore(
    String statement,
    List<ArchiveV1Contradiction> contradictions,
  ) {
    if (contradictions.isEmpty) return 0;
    final keys = _keywordsFrom(statement);
    if (keys.isEmpty) return 0;

    var best = 0;
    for (final c in contradictions) {
      final blob = '${c.youSay} ${c.but}'.toLowerCase();
      final hits = keys.where(blob.contains).length;
      if (hits >= 2) {
        best = 10;
        break;
      }
      if (hits == 1 && best < 6) best = 6;
    }
    return best;
  }

  int _surpriseScore(
    String statement,
    List<ArchiveSurpriseObservation> surprises,
  ) {
    if (surprises.isEmpty) return 0;
    final norm = _normalize(statement);
    final keys = _keywordsFrom(statement);
    for (final s in surprises) {
      final obs = _normalize(s.observation);
      if (obs.contains(norm) || norm.contains(obs)) return 10;
      final blob = s.observation.toLowerCase();
      if (keys.where(blob.contains).length >= 2) return 8;
    }
    return 0;
  }

  int _counterQualityScore({
    required int support,
    required int counter,
    required int rawCounter,
  }) {
    if (support == 0) return 0;
    if (counter == 0) return 6;
    if (rawCounter > support * 2) return 2;
    final ratio = counter / support;
    if (ratio <= 1) return 10;
    if (ratio <= 2) return 6;
    return 3;
  }

  Set<String> _keywordsFrom(String belief) {
    return belief
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 4)
        .toSet();
  }

  String _normalize(String text) =>
      text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
