import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/archive_theory/theory_ranking_engine.dart';
import 'package:archiveme_mobile/features/archive_theory/theory_ranking_models.dart';
import 'package:archiveme_mobile/features/archive_theory/theory_tracker_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Persists prior confidence for theory delta tracking.
class TheorySnapshotStore {
  TheorySnapshotStore(this._prefs);

  static const _key = 'theory_tracker_snapshots_v1';

  final MobilePrefsStore _prefs;

  MobilePrefsStore get prefs => _prefs;
  final Map<String, int> _cache = {};

  Future<void> ensureLoaded() async {
    if (_cache.isNotEmpty) return;
    final raw = await _prefs.readJsonMap(_key);
    final rows = raw?['byId'];
    if (rows is Map) {
      for (final entry in rows.entries) {
        final value = entry.value;
        if (value is int) _cache[entry.key] = value;
      }
    }
  }

  int? previousConfidenceFor(String theoryId) => _cache[theoryId];

  Future<void> upsert(String theoryId, int confidence) async {
    _cache[theoryId] = confidence;
    await _prefs.writeJsonMap(_key, {
      'byId': Map<String, int>.from(_cache),
    });
  }
}

/// Builds a multi-theory tracker report from journal entries (web parity).
class TheoryTrackerEngine {
  const TheoryTrackerEngine({
    this.rankingEngine = const TheoryRankingEngine(),
  });

  final TheoryRankingEngine rankingEngine;

  Future<TheoryTrackerReport> build({
    required List<JournalEntry> entries,
    required TheorySnapshotStore snapshots,
    bool persistSnapshots = true,
  }) async {
    await snapshots.ensureLoaded();
    final eligible = ArchiveEvidenceGuard.eligibleEntries(
      entries,
      analyticsSource: 'theory_tracker',
    );

    final ranking = rankingEngine.rank(entries: entries, eligible: eligible);
    final theories = <TrackedTheory>[
      if (ranking.primaryTheory != null)
        _fromRanked(ranking.primaryTheory!, snapshots),
      ...ranking.secondaryTheories.map((t) => _fromRanked(t, snapshots)),
    ];

    for (final theory in theories) {
      if (persistSnapshots) {
        await snapshots.upsert(theory.id, theory.confidence);
      }
    }

    final active = <TrackedTheory>[];
    final strengthening = <TrackedTheory>[];
    final weakening = <TrackedTheory>[];
    final resolved = <TrackedTheory>[];
    final retired = <TrackedTheory>[];

    for (final theory in theories) {
      switch (theory.status) {
        case TheoryStatus.strengthening:
          strengthening.add(theory);
        case TheoryStatus.weakening:
          weakening.add(theory);
        case TheoryStatus.resolved:
          resolved.add(theory);
        case TheoryStatus.retired:
          retired.add(theory);
        case TheoryStatus.active:
          active.add(theory);
      }
    }

    return TheoryTrackerReport(
      generatedAt: DateTime.now().toUtc(),
      active: active,
      strengthening: strengthening,
      weakening: weakening,
      resolved: resolved,
      retired: retired,
      all: theories,
    );
  }

  EvolvingViewSnapshot evolvingSnapshot(TheoryTrackerReport report) {
    final underReview = report.all
        .where((t) => t.status == TheoryStatus.active)
        .length;
    final strengthening = report.strengthening.length;
    final weakeningOrResolved =
        report.weakening.length + report.resolved.length + report.retired.length;
    DateTime? lastUpdated;
    for (final t in report.all) {
      if (lastUpdated == null || t.updatedAt.isAfter(lastUpdated)) {
        lastUpdated = t.updatedAt;
      }
    }
    return EvolvingViewSnapshot(
      totalTheories: report.all.length,
      underReviewCount: underReview,
      strengtheningCount: strengthening,
      weakeningOrResolvedCount: weakeningOrResolved,
      lastUpdated: lastUpdated,
    );
  }

  TrackedTheory _fromRanked(RankedTheory ranked, TheorySnapshotStore snapshots) {
    final previous = snapshots.previousConfidenceFor(ranked.candidateId);
    final delta = previous == null
        ? 0
        : ranked.confidencePercent - previous;
    final status = _resolveStatus(
      confidence: ranked.confidencePercent,
      delta: delta,
      support: ranked.evidenceCount,
      counter: ranked.counterEvidenceCount,
    );

    final quotes = ranked.supportingEvidence.isNotEmpty
        ? ranked.supportingEvidence
        : ranked.supportingEntries
            .take(4)
            .map(
              (entry) => TheoryEvidenceQuote(
                entryId: entry.id,
                dateLabel: _formatDate(entry.createdAt),
                quote: _trimQuote(entry.transcript),
              ),
            )
            .toList(growable: false);

    final whatChanged = <String>[];
    if (previous != null && delta.abs() >= 1) {
      whatChanged.add('Confidence moved from $previous% to ${ranked.confidencePercent}%.');
    }
    if (ranked.counterEvidenceCount > 0) {
      whatChanged.add(
        '${ranked.counterEvidenceCount} reflection${ranked.counterEvidenceCount == 1 ? '' : 's'} pull against this view.',
      );
    }

    return TrackedTheory(
      id: ranked.candidateId,
      statement: ranked.statement,
      confidence: ranked.confidencePercent,
      previousConfidence: previous,
      confidenceDelta: delta,
      supportingEvidenceCount: ranked.evidenceCount,
      contradictingEvidenceCount: ranked.counterEvidenceCount,
      createdAt: ranked.supportingEntries.isNotEmpty
          ? ranked.supportingEntries.first.createdAt
          : DateTime.now().toUtc(),
      updatedAt: ranked.lastUpdated ?? DateTime.now().toUtc(),
      status: status,
      supportingEvidence: quotes,
      contradictingEvidence: const [],
      whatChanged: whatChanged,
      source: ranked.source,
      inspection: ranked.inspection,
    );
  }

  TheoryStatus _resolveStatus({
    required int confidence,
    required int delta,
    required int support,
    required int counter,
  }) {
    if (confidence < 25 && counter >= support) return TheoryStatus.retired;
    if (confidence >= 70 && delta >= 5 && counter == 0) {
      return TheoryStatus.strengthening;
    }
    if (delta <= -5 || counter > support) return TheoryStatus.weakening;
    if (confidence >= 80 && support >= 5) return TheoryStatus.resolved;
    return TheoryStatus.active;
  }

  String _formatDate(DateTime dt) {
    final m = dt.month;
    final d = dt.day;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[m - 1]} $d';
  }

  String _trimQuote(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 200) return normalized;
    return '${normalized.substring(0, 197)}…';
  }
}