import 'package:archiveme_mobile/features/archive_analyst/archive_analyst_belief_catalog.dart';
import 'package:archiveme_mobile/features/archive_analyst/archive_analyst_confidence_engine.dart';
import 'package:archiveme_mobile/features/archive_analyst/archive_belief_visibility.dart';
import 'package:archiveme_mobile/features/archive_analyst/topical_counter_evidence.dart';
import 'package:archiveme_mobile/features/archive_state_object/archive_state_object.dart';
import 'package:archiveme_mobile/features/archive_surprises/archive_surprises_models.dart';
import 'package:archiveme_mobile/features/archive_theory/theory_ranking_models.dart';
import 'package:archiveme_mobile/features/archive_theory/theory_tracker_models.dart';
import 'package:archiveme_mobile/features/archive_theory/transcript_citation_resolver.dart';
import 'package:archiveme_mobile/features/archive_v1/archive_v1_models.dart';
import 'package:archiveme_mobile/features/belief_evolution/belief_evolution_models.dart';
import 'package:archiveme_mobile/features/insights/theory_xray_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Selects one primary theory for all archive surfaces from shared evidence rules.
class TheoryRankingEngine {
  const TheoryRankingEngine({
    this.catalog = const ArchiveAnalystBeliefCatalog(),
    this.confidenceEngine = const ArchiveAnalystConfidenceEngine(),
    this.topicalCounter = const TopicalCounterEvidence(),
    this.citationResolver = const TranscriptCitationResolver(),
    this.minConfidencePercent = ArchiveBeliefVisibility.minConfidencePercent,
    this.minEvidenceCount = ArchiveBeliefVisibility.minEvidenceCount,
    this.maxSecondary = 5,
  });

  final ArchiveAnalystBeliefCatalog catalog;
  final ArchiveAnalystConfidenceEngine confidenceEngine;
  final TopicalCounterEvidence topicalCounter;
  final TranscriptCitationResolver citationResolver;
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
    final contradictionEntryIds = contradictions
        .expand((c) => c.entryIds)
        .toSet();
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

      final confidenceBreakdown = confidenceEngine.breakdown(
        supportingCount: support,
        counterCount: counter,
        recencyRatio: split.recencyRatio,
        consistencyRatio: split.consistencyRatio,
        maxContradictionScore: maxCtr,
        stale: split.stale,
      );
      final confidence = confidenceBreakdown.finalPercent;

      if (confidence < minConfidencePercent || support < minEvidenceCount) {
        rejected++;
        continue;
      }

      final rankBreakdown = _rankBreakdown(
        statement: statement,
        support: support,
        counter: counter,
        rawCounter: split.rawCounterCount,
        consistencyRatio: split.consistencyRatio,
        recencyRatio: split.recencyRatio,
        contradictions: contradictions,
        surprises: surprises,
      );
      final rankScore = rankBreakdown.finalScore;

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
          supportingEvidence: _supportingEvidence(
            statement: statement,
            entries: split.supporting,
          ),
          lastUpdated: split.supporting.isNotEmpty
              ? split.supporting.last.createdAt
              : c.lastUpdated,
          inspection: _buildInspection(
            statement: statement,
            split: split,
            confidenceBreakdown: confidenceBreakdown,
            rankBreakdown: rankBreakdown,
            confidencePercent: confidence,
            rankScore: rankScore,
          ),
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

  TheoryRankBreakdown _rankBreakdown({
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
    final contradiction = _contradictionRelevanceScore(
      statement,
      contradictions,
    );
    final surprise = _surpriseScore(statement, surprises);
    final counterQuality = _counterQualityScore(
      support: support,
      counter: counter,
      rawCounter: rawCounter,
    );

    final total = (volume +
            consistency +
            recency +
            contradiction +
            surprise +
            counterQuality)
        .clamp(0, 100);

    return TheoryRankBreakdown(
      volumePoints: volume,
      consistencyPoints: consistency,
      recencyPoints: recency,
      contradictionPoints: contradiction,
      surprisePoints: surprise,
      counterQualityPoints: counterQuality,
      finalScore: total,
    );
  }

  TheoryRankingInspection _buildInspection({
    required String statement,
    required BeliefEvidenceSplit split,
    required ConfidenceScoreBreakdown confidenceBreakdown,
    required TheoryRankBreakdown rankBreakdown,
    required int confidencePercent,
    required int rankScore,
  }) {
    final keywords = _keywordsFrom(statement);
    final chunks = <TheoryRetrievalChunk>[
      for (final entry in split.supporting)
        TheoryRetrievalChunk(
          entryId: entry.id,
          excerpt: _trimExcerpt(entry.transcript),
          role: TheoryRetrievalRole.supporting,
          recordedAt: entry.createdAt,
          keywordOverlap: _overlapScore(entry.transcript, keywords),
        ),
      for (final entry in split.counter)
        TheoryRetrievalChunk(
          entryId: entry.id,
          excerpt: _trimExcerpt(entry.transcript),
          role: TheoryRetrievalRole.counter,
          recordedAt: entry.createdAt,
          keywordOverlap: _overlapScore(entry.transcript, keywords),
        ),
    ];

    return TheoryRankingInspection(
      confidenceBreakdown: TheoryConfidenceBreakdown(
        volumePoints: confidenceBreakdown.volumePoints,
        consistencyPoints: confidenceBreakdown.consistencyPoints,
        recencyPoints: confidenceBreakdown.recencyPoints,
        contradictionPenalty: confidenceBreakdown.contradictionPenalty,
        counterPenalty: confidenceBreakdown.counterPenalty,
        lowEvidenceMultiplierApplied:
            confidenceBreakdown.lowEvidenceMultiplierApplied,
        staleMultiplierApplied: confidenceBreakdown.staleMultiplierApplied,
        rawTotalBeforeModifiers: confidenceBreakdown.rawTotalBeforeModifiers,
        finalPercent: confidenceBreakdown.finalPercent,
      ),
      rankBreakdown: rankBreakdown,
      retrievedChunks: chunks,
      finalConfidencePercent: confidencePercent,
      finalRankScore: rankScore,
    );
  }

  int _overlapScore(String transcript, Set<String> keywords) {
    if (keywords.isEmpty) return 0;
    final lower = transcript.toLowerCase();
    return keywords.where(lower.contains).length;
  }

  String _trimExcerpt(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 160) return normalized;
    return '${normalized.substring(0, 157)}…';
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

  List<TheoryEvidenceQuote> _supportingEvidence({
    required String statement,
    required List<JournalEntry> entries,
  }) {
    return entries
        .take(4)
        .map((entry) {
          final quote = citationResolver.quoteForBelief(entry, statement);
          final citation = citationResolver.resolve(entry: entry, quote: quote);
          return TheoryEvidenceQuote(
            entryId: entry.id,
            dateLabel: _formatEvidenceDate(entry.createdAt),
            quote: quote,
            audioId: citation.audioId,
            startTimestampMs: citation.startTimestampMs,
            endTimestampMs: citation.endTimestampMs,
            chunkId: citation.chunkId,
          );
        })
        .toList(growable: false);
  }

  String _formatEvidenceDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}';
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