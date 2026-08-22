import 'package:archiveme_mobile/design/user_facing_date.dart';
import 'package:archiveme_mobile/features/archive_analyst/archive_analyst_belief_catalog.dart';
import 'package:archiveme_mobile/features/archive_analyst/archive_analyst_confidence_engine.dart';
import 'package:archiveme_mobile/features/archive_analyst/archive_analyst_gate.dart';
import 'package:archiveme_mobile/features/archive_analyst/archive_analyst_models.dart';
import 'package:archiveme_mobile/features/archive_analyst/archive_belief_visibility.dart';
import 'package:archiveme_mobile/features/archive_analyst/topical_counter_evidence.dart';
import 'package:archiveme_mobile/features/archive_deep_dive/archive_deep_dive_engine.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence.dart';
import 'package:archiveme_mobile/features/archive_explanations/belief_timeline_engine.dart';
import 'package:archiveme_mobile/features/archive_state_object/archive_state_object.dart';
import 'package:archiveme_mobile/features/archive_v1/archive_v1_builder.dart';
import 'package:archiveme_mobile/features/archive_v1/archive_v1_models.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_evolution_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Periodic archive synthesis from V1, deep dive, and local engines.
class ArchiveAnalystEngine {
  const ArchiveAnalystEngine({
    this.catalog = const ArchiveAnalystBeliefCatalog(),
    this.confidenceEngine = const ArchiveAnalystConfidenceEngine(),
    this.v1Builder = const ArchiveV1Builder(),
    this.deepDiveEngine = const ArchiveDeepDiveEngine(),
    this.timelineEngine = const BeliefTimelineEngine(),
    this.topicalCounter = const TopicalCounterEvidence(),
  });

  final ArchiveAnalystBeliefCatalog catalog;
  final ArchiveAnalystConfidenceEngine confidenceEngine;
  final TopicalCounterEvidence topicalCounter;
  final ArchiveV1Builder v1Builder;
  final ArchiveDeepDiveEngine deepDiveEngine;
  final BeliefTimelineEngine timelineEngine;

  Future<ArchiveAnalystReport> build({
    required List<JournalEntry> entries,
    required BeliefEvolutionService evolutionService, ArchiveStateObjectV3? state,
  }) async {
    final eligible = archiveEligibleEvidenceEntries(entries);
    final count = eligible.length;
    final level = ArchiveAnalystGate.levelFor(count);

    if (level == ArchiveAnalystLevel.insufficient) {
      return ArchiveAnalystReport(
        level: level,
        eligibleReflectionCount: count,
        evidenceSummary: ArchiveAnalystEvidenceSummary(
          eligibleReflectionCount: count,
          dateSpanLabel: _dateSpan(eligible),
          uniqueBeliefCandidates: 0,
          contradictionCount: 0,
          blindSpotCount: 0,
        ),
        currentBeliefs: const [],
        emergingBeliefs: const [],
        fadingBeliefs: const [],
        contradictions: const [],
        blindSpots: const [],
        competingBeliefs: const [],
        debates: const [],
      );
    }

    final evo = await evolutionService.refreshFromEntries(entries: entries);
    final v1 = await v1Builder.build(
      entries: entries,
      state: state,
      evolutionService: evolutionService,
    );

    final candidates = catalog.collect(
      entries: entries,
      state: state,
      evolution: evo,
    );

    final contradictions = v1.contradictions;
    final blindSpots = v1.blindSpots;
    final maxCtr = contradictions.isEmpty
        ? 0
        : contradictions
              .map((c) => c.confidenceScore)
              .reduce((a, b) => a > b ? a : b);

    final contradictionEntryIds = contradictions
        .expand((c) => c.entryIds)
        .toSet();

    final scored = <_ScoredBelief>[];
    for (final c in candidates) {
      final split = confidenceEngine.splitEntries(
        beliefText: c.statement,
        eligible: eligible,
        contradictionEntryIds: contradictionEntryIds,
      );
      final conf = confidenceEngine.score(
        supportingCount: split.supporting.length,
        counterCount: split.counter.length,
        recencyRatio: split.recencyRatio,
        consistencyRatio: split.consistencyRatio,
        maxContradictionScore: maxCtr,
        stale: split.stale,
      );
      scored.add(_ScoredBelief(candidate: c, confidence: conf, split: split));
    }

    final unifiedPrimary = v1.theoryRanking?.primaryTheory;
    final unifiedNorm = unifiedPrimary != null
        ? _normalize(unifiedPrimary.statement)
        : null;

    if (unifiedNorm != null) {
      scored.sort((a, b) {
        final aUnified = _normalize(a.candidate.statement) == unifiedNorm
            ? 1
            : 0;
        final bUnified = _normalize(b.candidate.statement) == unifiedNorm
            ? 1
            : 0;
        if (aUnified != bUnified) return bUnified.compareTo(aUnified);
        return b.confidence.compareTo(a.confidence);
      });
    } else {
      scored.sort((a, b) => b.confidence.compareTo(a.confidence));
    }

    final primaryId =
        unifiedPrimary?.candidateId ?? _firstVisibleCandidateId(scored);

    final visible = _visibleScored(scored);

    final current = visible
        .take(level.maxCurrentBeliefs)
        .map(
          (s) => ArchiveAnalystBeliefRow(
            id: s.candidate.id,
            statement: s.candidate.statement,
            confidencePercent: s.confidence,
            evidenceCount: s.split.supporting.length,
            counterEvidenceCount: s.split.counter.length,
            lastUpdated: s.split.supporting.isNotEmpty
                ? s.split.supporting.last.createdAt
                : s.candidate.lastUpdated,
            isPrimary: s.candidate.id == primaryId,
          ),
        )
        .toList();

    final emerging = _trendBeliefs(
      scored: visible,
      eligible: eligible,
      rising: true,
      limit: level.maxEmergingOrFading,
    );
    final fading = _trendBeliefs(
      scored: visible,
      eligible: eligible,
      rising: false,
      limit: level.maxEmergingOrFading,
    );

    final competing = <ArchiveAnalystCompetingBelief>[];
    for (final s in visible) {
      if (competing.length >= level.maxCompeting) break;
      competing.add(
        ArchiveAnalystCompetingBelief(
          statement: s.candidate.statement,
          confidencePercent: s.confidence,
          isPrimary: s.candidate.id == primaryId,
        ),
      );
    }

    final debates = <ArchiveAnalystDebate>[];
    for (final s in visible.take(level.maxDebates)) {
      debates.add(_buildDebate(s, eligible, v1));
    }

    return ArchiveAnalystReport(
      level: level,
      eligibleReflectionCount: count,
      evidenceSummary: ArchiveAnalystEvidenceSummary(
        eligibleReflectionCount: count,
        dateSpanLabel: _dateSpan(eligible),
        uniqueBeliefCandidates: candidates.length,
        contradictionCount: contradictions.length,
        blindSpotCount: blindSpots.length,
      ),
      currentBeliefs: current,
      emergingBeliefs: emerging,
      fadingBeliefs: fading,
      contradictions: contradictions,
      blindSpots: blindSpots,
      competingBeliefs: competing,
      debates: debates,
      primaryBeliefId: primaryId,
    );
  }

  List<_ScoredBelief> _visibleScored(List<_ScoredBelief> scored) {
    return scored
        .where(
          (s) => ArchiveBeliefVisibility.isVisibleBelief(
            statement: s.candidate.statement,
            confidencePercent: s.confidence,
            evidenceCount: s.split.supporting.length,
          ),
        )
        .toList();
  }

  String? _firstVisibleCandidateId(List<_ScoredBelief> scored) {
    for (final s in scored) {
      if (ArchiveBeliefVisibility.isVisibleBelief(
        statement: s.candidate.statement,
        confidencePercent: s.confidence,
        evidenceCount: s.split.supporting.length,
      )) {
        return s.candidate.id;
      }
    }
    return null;
  }

  List<ArchiveAnalystTrendBelief> _trendBeliefs({
    required List<_ScoredBelief> scored,
    required List<JournalEntry> eligible,
    required bool rising,
    required int limit,
  }) {
    final out = <ArchiveAnalystTrendBelief>[];
    for (final s in scored) {
      if (out.length >= limit) break;
      final series = _monthlyMentions(s.candidate.statement, eligible);
      if (series.length < 2) continue;
      final early = series.take(2).fold<int>(0, (a, b) => a + b);
      final late = series.skip(series.length - 2).fold<int>(0, (a, b) => a + b);
      if (early == 0 && late == 0) continue;
      final isRising = late > early;
      if (rising != isRising) continue;
      final label = rising
          ? 'Evidence trend: ${_seriesLabel(series)}'
          : _fadingLabel(series);
      out.add(
        ArchiveAnalystTrendBelief(
          id: s.candidate.id,
          statement: s.candidate.statement,
          confidencePercent: s.confidence,
          trendLabel: label,
          mentionSeries: series,
        ),
      );
    }
    return out;
  }

  String _seriesLabel(List<int> series) => series.join(' → ');

  String _fadingLabel(List<int> series) {
    if (series.isEmpty) return 'Mentions sparse';
    final first = series.first;
    final last = series.last;
    if (first >= 4 && last <= 1) return 'Previously strong → now rare';
    if (last == 0) return 'No recent mentions';
    return 'Mentions declining: ${series.join(' → ')}';
  }

  List<int> _monthlyMentions(String belief, List<JournalEntry> eligible) {
    final keywords = belief
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 4)
        .toSet();
    if (keywords.isEmpty) return const [];

    final buckets = <String, int>{};
    for (final e in eligible) {
      final local = e.createdAt.toLocal();
      final key = '${local.year}-${local.month}';
      final lower = e.transcript.toLowerCase();
      if (keywords.any(lower.contains)) {
        buckets[key] = (buckets[key] ?? 0) + 1;
      }
    }
    final keys = buckets.keys.toList()..sort();
    return keys.map((k) => buckets[k]!).toList();
  }

  ArchiveAnalystDebate _buildDebate(
    _ScoredBelief scored,
    List<JournalEntry> eligible,
    ArchiveV1View v1,
  ) {
    final notes = <String>[];
    final timeline = timelineEngine.build(
      entries: eligible,
      beliefText: scored.candidate.statement,
    );
    if (timeline.firstSeen != null) {
      notes.add('First mention: ${formatUserFacingDate(timeline.firstSeen!)}');
    }
    if (timeline.peakLabel.isNotEmpty && timeline.peakLabel != '—') {
      notes.add(
        'Strongest month: ${timeline.peakLabel} (${timeline.peakPercent}% overlap)',
      );
    }

    final supporting = scored.split.supporting;
    final counter = scored.split.counter;

    final v1Statement = v1.belief?.statement.trim() ?? '';
    if (v1Statement.isNotEmpty &&
        _normalize(v1Statement) == _normalize(scored.candidate.statement)) {
      final dive = deepDiveEngine.build(v1: v1);
      if (dive != null) {
        final diveAgainst = dive.counterEvidence.againstExcerpts;
        final belief = scored.candidate.statement;
        final counterExcerpts = _topicalCounterExcerpts(
          belief: belief,
          excerpts: diveAgainst.isNotEmpty
              ? diveAgainst
                    .map(
                      (e) => ArchiveAnalystExcerpt(
                        entryId: e.entryId,
                        dateLabel: e.dateLabel,
                        quote: e.quote,
                      ),
                    )
                    .toList()
              : counter.take(8).map(_excerpt).toList(),
        );
        return ArchiveAnalystDebate(
          beliefStatement: belief,
          confidencePercent: scored.confidence,
          evidenceForCount: supporting.length,
          evidenceAgainstCount:
              counterExcerpts.length +
              dive.counterEvidence.againstSummaries.length,
          supportingExcerpts: dive.counterEvidence.forExcerpts
              .map(
                (e) => ArchiveAnalystExcerpt(
                  entryId: e.entryId,
                  dateLabel: e.dateLabel,
                  quote: e.quote,
                ),
              )
              .toList(),
          counterExcerpts: counterExcerpts,
          timelineNotes: notes,
        );
      }
    }

    final belief = scored.candidate.statement;
    return ArchiveAnalystDebate(
      beliefStatement: belief,
      confidencePercent: scored.confidence,
      evidenceForCount: supporting.length,
      evidenceAgainstCount: counter.length,
      supportingExcerpts: supporting.take(4).map(_excerpt).toList(),
      counterExcerpts: _topicalCounterExcerpts(
        belief: belief,
        excerpts: counter.take(8).map(_excerpt).toList(),
      ),
      timelineNotes: notes,
    );
  }

  List<ArchiveAnalystExcerpt> _topicalCounterExcerpts({
    required String belief,
    required List<ArchiveAnalystExcerpt> excerpts,
  }) {
    return excerpts
        .where(
          (e) => topicalCounter.isRelevantCounterQuote(
            beliefText: belief,
            counterQuote: e.quote,
          ),
        )
        .take(4)
        .toList();
  }

  ArchiveAnalystExcerpt _excerpt(JournalEntry e) {
    final t = e.transcript.trim();
    final quote = t.length <= 160 ? t : '${t.substring(0, 160).trim()}…';
    return ArchiveAnalystExcerpt(
      entryId: e.id,
      dateLabel: formatUserFacingDate(e.createdAt),
      quote: quote,
    );
  }

  String _normalize(String text) =>
      text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  String _dateSpan(List<JournalEntry> eligible) {
    if (eligible.isEmpty) return '—';
    final first = eligible.first.createdAt;
    final last = eligible.last.createdAt;
    return '${formatUserFacingDate(first)} – ${formatUserFacingDate(last)}';
  }
}

class _ScoredBelief {
  const _ScoredBelief({
    required this.candidate,
    required this.confidence,
    required this.split,
  });

  final ArchiveAnalystBeliefCandidate candidate;
  final int confidence;
  final BeliefEvidenceSplit split;
}