import '../data/models/curiosity_reaction_record.dart';
import '../data/repositories/curiosity_reaction_repository.dart';
import '../yesterdays_snapshot_reaction.dart';

/// Aggregated weekly reaction analytics for curiosity loop check-ins.
class WeeklyProductivityReport {
  const WeeklyProductivityReport({
    required this.totalReactions,
    required this.reactionBreakdown,
    required this.stuckAnchors,
    required this.momentumAnchors,
  });

  final int totalReactions;
  final Map<String, double> reactionBreakdown;
  final List<String> stuckAnchors;
  final List<String> momentumAnchors;
}

/// Rolls up reaction history into a seven-day productivity snapshot.
class ProductivityReportEngine {
  ProductivityReportEngine(this._repository);

  static const reportWindow = Duration(days: 7);
  static const anchorHighlightLimit = 3;

  final CuriosityReactionRepository _repository;

  Future<WeeklyProductivityReport> generateWeeklyReport({
    DateTime? relativeTo,
  }) async {
    final windowEnd = (relativeTo ?? DateTime.now()).toUtc();
    final windowStart = windowEnd.subtract(reportWindow);
    final reactions = await _repository.getReactionsInWindow(
      start: windowStart,
      end: windowEnd,
    );
    return _aggregate(reactions);
  }

  WeeklyProductivityReport _aggregate(List<CuriosityReactionRecord> reactions) {
    if (reactions.isEmpty) {
      return const WeeklyProductivityReport(
        totalReactions: 0,
        reactionBreakdown: {},
        stuckAnchors: [],
        momentumAnchors: [],
      );
    }

    final reactionCounts = <YesterdaysSnapshotReaction, int>{};
    final stuckAnchorCounts = <String, int>{};
    final momentumAnchorCounts = <String, int>{};

    for (final reaction in reactions) {
      reactionCounts.update(
        reaction.reactionType,
        (count) => count + 1,
        ifAbsent: () => 1,
      );

      switch (reaction.reactionType) {
        case YesterdaysSnapshotReaction.stuck:
          stuckAnchorCounts.update(
            reaction.primaryAnchor,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        case YesterdaysSnapshotReaction.progressed:
          momentumAnchorCounts.update(
            reaction.primaryAnchor,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        case YesterdaysSnapshotReaction.pivot:
          break;
      }
    }

    final total = reactions.length;
    final breakdown = {
      for (final type in YesterdaysSnapshotReaction.values)
        type.name: (reactionCounts[type] ?? 0) / total,
    };

    return WeeklyProductivityReport(
      totalReactions: total,
      reactionBreakdown: breakdown,
      stuckAnchors: _topAnchors(stuckAnchorCounts),
      momentumAnchors: _topAnchors(momentumAnchorCounts),
    );
  }

  List<String> _topAnchors(Map<String, int> counts) {
    if (counts.isEmpty) return const [];

    final sorted = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });

    return sorted
        .take(anchorHighlightLimit)
        .map((entry) => entry.key)
        .toList(growable: false);
  }
}
