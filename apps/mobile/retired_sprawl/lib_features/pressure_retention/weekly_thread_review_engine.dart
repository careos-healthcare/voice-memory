import 'package:archiveme_mobile/features/memory/memory_authority_framing_engine.dart';
import 'package:archiveme_mobile/features/memory/memory_control_model.dart';
import 'package:archiveme_mobile/features/memory/memory_scope_policy.dart';
import 'package:archiveme_mobile/features/memory/sensitive_surfacing_policy.dart';
import 'package:archiveme_mobile/features/pressure_retention/belief_distance_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:archiveme_mobile/features/pressure_retention/thread_return_evidence_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/thread_return_evidence_model.dart';
import 'package:archiveme_mobile/features/pressure_retention/weekly_thread_review_model.dart';

/// Builds the compact weekly review from local saved records and the existing
/// thread/belief evidence engines. Pure and deterministic — no AI calls.
///
/// Rules:
/// - Eligible with [WeeklyThreadReview.minEntries]+ entries overall, or a
///   connected thread (2+ related entries).
/// - "Returned" counts only thread occurrences inside the 7-day window that
///   came after the thread's first appearance.
/// - "Faded" appears only when the thread engine genuinely detected fading;
///   "changed" only when a belief-like phrase repeated or the thread is
///   genuinely building. Unsupported lines are omitted, never padded.
/// - When nothing moved inside the window, there is no review at all.
class WeeklyThreadReviewEngine {
  const WeeklyThreadReviewEngine();

  static const _threadEngine = ThreadReturnEvidenceEngine();
  static const _beliefEngine = BeliefDistanceEngine();

  /// [now] is injectable for tests; the window is the 7 days before it.
  WeeklyThreadReview build(
    List<PressureCheckInRecord> records, {
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    // Memory scope policy gates which entries the weekly counts may
    // include; the returned/faded/changed claims additionally pass
    // through retrieval scoring and authority framing inside the thread
    // and belief engines, so weak, stale, superseded, or suppressed
    // evidence never produces a thread claim. Counting this week's own
    // entries is not a connection claim, so it stays scope-filtered
    // only. The review's own frame is recorded so the card can explain
    // how memory was used.
    const MemoryAuthorityFramingEngine().frame(
      records,
      now: clock,
      cardType: MemoryCardType.weeklyReview,
    );
    final connectable = SensitiveSurfacingPolicy.proactiveClaimEligible(
      MemoryScopePolicy.connectionEligible(records),
    );
    final evidence = _threadEngine.build(
      connectable,
      now: clock,
      entryCount: connectable.length,
    );

    final eligible =
        connectable.length >= WeeklyThreadReview.minEntries ||
        evidence.hasEvidence;
    if (!eligible) return WeeklyThreadReview.none();

    final weekStart = clock.subtract(
      const Duration(days: WeeklyThreadReview.windowDays),
    );
    final weekRecords = connectable
        .where((r) => r.createdAt.isAfter(weekStart))
        .toList();
    final belief = _beliefEngine.build(
      connectable,
      entryCount: connectable.length,
    );

    final evidenceLine = _evidenceLine(weekRecords.length);
    final returnedLine = _returnedLine(evidence, connectable, weekStart);
    final fadedLine =
        evidence.hasEvidence && evidence.status == ThreadReturnStatus.fading
        ? '${_threadName(evidence)} appeared less often in your recent '
              'recordings.'
        : '';
    final changedLine = _changedLine(evidence, belief.hasBelief);

    // Nothing genuinely moved this week — show nothing instead of filler.
    if (evidenceLine.isEmpty &&
        returnedLine.isEmpty &&
        fadedLine.isEmpty &&
        changedLine.isEmpty) {
      return WeeklyThreadReview.none();
    }

    return WeeklyThreadReview(
      hasReview: true,
      title: WeeklyThreadReview.defaultTitle,
      weekSummaryLine: WeeklyThreadReview.defaultWeekSummaryLine,
      takeawayLine: _takeawayLine(
        returned: returnedLine.isNotEmpty,
        faded: fadedLine.isNotEmpty,
        changed: changedLine.isNotEmpty,
      ),
      returnedLine: returnedLine,
      fadedLine: fadedLine,
      changedLine: changedLine,
      evidenceLine: evidenceLine,
      nextWeekLine: WeeklyThreadReview.defaultNextWeekLine,
      sourceTerms: evidence.hasEvidence
          ? evidence.sourceTerms
          : belief.sourceTerms,
      evidenceSnippets: evidence.hasEvidence
          ? evidence.evidenceSnippets
          : belief.evidenceSnippets,
      entryIds: evidence.hasEvidence
          ? evidence.entryIds
          : weekRecords.map((r) => r.entryId).toList(),
    );
  }

  /// The sharpened one-line takeaway, derived strictly from which supported
  /// lines exist — change is never claimed beyond what the lines already
  /// say. Fixed copy only; no user terms can enter it. A review that exists
  /// always has at least one line, so the evidence-only fallback is the
  /// floor.
  String _takeawayLine({
    required bool returned,
    required bool faded,
    required bool changed,
  }) {
    if (returned) return WeeklyThreadReview.returnedTakeaway;
    if (faded) return WeeklyThreadReview.fadingTakeaway;
    if (changed) return WeeklyThreadReview.changedTakeaway;
    return WeeklyThreadReview.evidenceOnlyTakeaway;
  }

  String _evidenceLine(int added) {
    if (added == 0) return '';
    return 'You added $added ${added == 1 ? 'piece' : 'pieces'} of evidence.';
  }

  /// Thread occurrences inside the window, excluding the thread's very first
  /// appearance — only a real comeback counts as "returned".
  String _returnedLine(
    ThreadReturnEvidence evidence,
    List<PressureCheckInRecord> records,
    DateTime weekStart,
  ) {
    if (!evidence.hasEvidence || evidence.entryIds.length < 2) return '';
    final byId = {for (final r in records) r.entryId: r};
    var returns = 0;
    // entryIds are ordered oldest → newest; skip the first appearance.
    for (final id in evidence.entryIds.skip(1)) {
      final record = byId[id];
      if (record != null && record.createdAt.isAfter(weekStart)) returns++;
    }
    if (returns == 0) return '';
    return '${_threadName(evidence)} returned '
        '$returns ${returns == 1 ? 'time' : 'times'}.';
  }

  /// Change is reported only from real signals: a repeated belief-like
  /// phrase, or a thread the evidence engine already calls "building".
  String _changedLine(ThreadReturnEvidence evidence, bool hasBelief) {
    if (hasBelief) return 'One belief-like phrase showed up again.';
    if (evidence.hasEvidence &&
        evidence.status == ThreadReturnStatus.building) {
      return '${_threadName(evidence)} appeared more often in your recent '
          'recordings.';
    }
    return '';
  }

  /// "The work thread" for single-word terms; a multi-word option theme
  /// ("feeling behind") would read oddly as a noun, so it stays generic.
  String _threadName(ThreadReturnEvidence evidence) {
    final term = evidence.sourceTerms.isEmpty
        ? ''
        : evidence.sourceTerms.first.trim();
    if (term.isEmpty || term.contains(' ')) return 'This thread';
    return 'The $term thread';
  }
}