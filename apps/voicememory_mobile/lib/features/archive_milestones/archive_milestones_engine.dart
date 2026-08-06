import '../../models/journal_entry.dart';
import '../activation/weekly_archive_review.dart';
import '../pressure_retention/shareable_archive_proof_engine.dart';
import 'archive_milestones_copy.dart';
import 'archive_milestones_gates.dart';
import 'archive_milestones_models.dart';

/// Builds archive milestones from local archive signals — no persistence.
class ArchiveMilestonesEngine {
  const ArchiveMilestonesEngine();

  static const _milestoneOrder = ArchiveMilestoneId.values;

  ArchiveMilestonesResult build({
    required List<JournalEntry> entries,
    required int watchlistCount,
    required bool hasReturnRitual,
  }) {
    final saved = _realEntries(entries);
    final savedCount = saved.length;
    final shareProof = const ShareableArchiveProofEngine().buildFromJournal(
      entries: saved,
    );
    final weeklyReview = WeeklyArchiveReviewEngine.build(entries: saved);

    final completion = {
      ArchiveMilestoneId.firstMomentSaved: savedCount >= 1,
      ArchiveMilestoneId.firstComparisonPossible: savedCount >= 2,
      ArchiveMilestoneId.firstCautiousBelief: savedCount >= 3,
      ArchiveMilestoneId.firstWeeklyReviewReady:
          savedCount >= 5 && weeklyReview.hasEnoughEvidence,
      ArchiveMilestoneId.firstWatchlistTheme: watchlistCount >= 1,
      ArchiveMilestoneId.firstReturnRitual: hasReturnRitual,
      ArchiveMilestoneId.firstShareSafeProof: shareProof.hasProof,
      ArchiveMilestoneId.longTermArchiveBuilding: savedCount >= 10,
    };

    final rows = _displayRows(completion);

    return ArchiveMilestonesResult(
      title: ArchiveMilestonesCopy.cardTitle,
      body: ArchiveMilestonesCopy.cardBody,
      rows: rows,
      showProLine: ArchiveMilestonesGates.showProLine(savedCount: savedCount),
      primaryActionLabel: ArchiveMilestonesCopy.addMomentAction,
      primaryActionRoute: ArchiveMilestonesCopy.addMomentRoute,
    );
  }

  static List<ArchiveMilestoneRow> _displayRows(
    Map<ArchiveMilestoneId, bool> completion,
  ) {
    final firstIncomplete = _milestoneOrder.indexWhere(
      (id) => completion[id] != true,
    );

    if (firstIncomplete == -1) {
      final last = _milestoneOrder.last;
      return [
        ArchiveMilestoneRow(
          id: last,
          label: ArchiveMilestonesCopy.labelFor(last),
          state: ArchiveMilestoneRowState.done,
          isComplete: true,
        ),
      ];
    }

    final rows = <ArchiveMilestoneRow>[];

    if (firstIncomplete > 0) {
      final recentDone = _milestoneOrder[firstIncomplete - 1];
      rows.add(
        ArchiveMilestoneRow(
          id: recentDone,
          label: ArchiveMilestonesCopy.labelFor(recentDone),
          state: ArchiveMilestoneRowState.done,
          isComplete: true,
        ),
      );
    }

    final current = _milestoneOrder[firstIncomplete];
    rows.add(
      ArchiveMilestoneRow(
        id: current,
        label: ArchiveMilestonesCopy.labelFor(current),
        state: ArchiveMilestoneRowState.now,
        isComplete: false,
      ),
    );

    for (
      var i = firstIncomplete + 1;
      i < _milestoneOrder.length && rows.length < 5;
      i++
    ) {
      final upcoming = _milestoneOrder[i];
      rows.add(
        ArchiveMilestoneRow(
          id: upcoming,
          label: ArchiveMilestonesCopy.labelFor(upcoming),
          state: ArchiveMilestoneRowState.next,
          isComplete: false,
        ),
      );
    }

    return rows;
  }

  static List<JournalEntry> _realEntries(List<JournalEntry> entries) => entries
      .where(
        (e) =>
            e.transcript.trim().isNotEmpty &&
            !e.transcript.startsWith('[draft]'),
      )
      .toList();

  /// Exposed for tests — whether a milestone is complete for given signals.
  static bool isComplete({
    required ArchiveMilestoneId id,
    required int savedCount,
    required int eligibleCount,
    required int watchlistCount,
    required bool hasReturnRitual,
    required bool shareProofReady,
    required bool weeklyReviewReady,
  }) => switch (id) {
    ArchiveMilestoneId.firstMomentSaved => savedCount >= 1,
    ArchiveMilestoneId.firstComparisonPossible => savedCount >= 2,
    ArchiveMilestoneId.firstCautiousBelief => savedCount >= 3,
    ArchiveMilestoneId.firstWeeklyReviewReady => weeklyReviewReady,
    ArchiveMilestoneId.firstWatchlistTheme => watchlistCount >= 1,
    ArchiveMilestoneId.firstReturnRitual => hasReturnRitual,
    ArchiveMilestoneId.firstShareSafeProof => shareProofReady,
    ArchiveMilestoneId.longTermArchiveBuilding => savedCount >= 10,
  };
}
