import '../../models/journal_entry.dart';
import 'topical_counter_evidence.dart';

/// Evidence-backed confidence (0–100) — no AI.
///
/// ## Algorithm
///
/// 1. **Volume** — up to 40 points from supporting mention count (`min(40, count * 2)`).
/// 2. **Consistency** — up to 25 points: `support / (support + counter)` ratio.
/// 3. **Recency** — up to 20 points: share of supporting mentions in the latest 25% of the timeline.
/// 4. **Contradiction penalty** — up to 25 points subtracted from strongest linked contradiction score.
/// 5. **Counter penalty** — up to 20 points from counter-evidence count (`min(20, counter * 2)`).
///
/// Modifiers:
/// - Fewer than 3 supporting mentions → multiply by 0.6.
/// - No supporting mention in the latest 25% of eligible entries → multiply by 0.75 (stale).
///
/// Result is clamped to 0–100.
class ArchiveAnalystConfidenceEngine {
  const ArchiveAnalystConfidenceEngine({
    this.topicalCounter = const TopicalCounterEvidence(),
  });

  final TopicalCounterEvidence topicalCounter;

  int score({
    required int supportingCount,
    required int counterCount,
    required double recencyRatio,
    required double consistencyRatio,
    required int maxContradictionScore,
    required bool stale,
  }) {
    final volume = (supportingCount * 2).clamp(0, 40);
    final consistency = (consistencyRatio * 25).round().clamp(0, 25);
    final recency = (recencyRatio * 20).round().clamp(0, 20);
    final contradictionPenalty =
        (maxContradictionScore ~/ 4).clamp(0, 25);
    final counterPenalty = (counterCount * 2).clamp(0, 20);

    var raw = volume + consistency + recency - contradictionPenalty - counterPenalty;
    if (supportingCount < 3) {
      raw = (raw * 0.6).round();
    }
    if (stale) {
      raw = (raw * 0.75).round();
    }
    return raw.clamp(0, 100);
  }

  /// Classify entries into supporting vs topical counter for [beliefText].
  BeliefEvidenceSplit splitEntries({
    required String beliefText,
    required List<JournalEntry> eligible,
    Set<String> contradictionEntryIds = const {},
  }) {
    final keywords = _keywordsFrom(beliefText);
    if (keywords.isEmpty || eligible.isEmpty) {
      return const BeliefEvidenceSplit(
        supportingIds: [],
        counterIds: [],
        supporting: [],
        counter: [],
      );
    }

    final sorted = [...eligible]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final cutoffIndex = (sorted.length * 0.75).floor();
    final recentCutoff = sorted.length <= 1
        ? sorted.last.createdAt
        : sorted[cutoffIndex.clamp(0, sorted.length - 1)].createdAt;

    final supporting = <JournalEntry>[];
    var recentHits = 0;

    for (final e in sorted) {
      final hits = _overlapScore(e.transcript, keywords);
      if (hits >= 2) {
        supporting.add(e);
        if (!e.createdAt.isBefore(recentCutoff)) recentHits++;
      }
    }

    final rawCounters = topicalCounter
        .pickRaw(
          beliefText: beliefText,
          eligible: sorted,
          supporting: supporting,
          contradictionEntryIds: contradictionEntryIds,
        )
        .where(
          (e) => topicalCounter.isRelevantCounterQuote(
            beliefText: beliefText,
            counterQuote: e.transcript,
          ),
        )
        .toList();
    final cap = topicalCounter.cap(
      rawCounters: rawCounters,
      supportingCount: supporting.length,
    );
    final counter = cap.capped;

    final recencyRatio =
        supporting.isEmpty ? 0.0 : recentHits / supporting.length;
    final total = supporting.length + counter.length;
    final consistencyRatio =
        total == 0 ? 0.0 : supporting.length / total;

    return BeliefEvidenceSplit(
      supportingIds: supporting.map((e) => e.id).toList(),
      counterIds: counter.map((e) => e.id).toList(),
      supporting: supporting,
      counter: counter,
      recencyRatio: recencyRatio,
      consistencyRatio: consistencyRatio,
      stale: supporting.isNotEmpty && recentHits == 0,
      rawCounterCount: cap.rawCount,
      counterExceedsSupportTwice: cap.exceedsSupportTwice,
    );
  }

  int _overlapScore(String transcript, Set<String> keywords) {
    final lower = transcript.toLowerCase();
    return keywords.where(lower.contains).length;
  }

  Set<String> _keywordsFrom(String belief) {
    return belief
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 4)
        .toSet();
  }
}

class BeliefEvidenceSplit {
  const BeliefEvidenceSplit({
    required this.supportingIds,
    required this.counterIds,
    required this.supporting,
    required this.counter,
    this.recencyRatio = 0,
    this.consistencyRatio = 0,
    this.stale = false,
    this.rawCounterCount = 0,
    this.counterExceedsSupportTwice = false,
  });

  final List<String> supportingIds;
  final List<String> counterIds;
  final List<JournalEntry> supporting;
  final List<JournalEntry> counter;
  final double recencyRatio;
  final double consistencyRatio;
  final bool stale;

  /// Topical counters before support-ratio cap.
  final int rawCounterCount;

  /// True when [rawCounterCount] > 2× supporting count (explicit copy warning).
  final bool counterExceedsSupportTwice;
}
