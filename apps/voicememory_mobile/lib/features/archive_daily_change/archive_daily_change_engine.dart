import '../../models/journal_entry.dart';
import '../beta_feedback/beta_feedback_engine.dart';
import '../capacity_loop/capacity_boundary_response_copy.dart';
import '../capacity_loop/capacity_boundary_response_models.dart';
import '../capacity_loop/capacity_cost_models.dart';
import '../capacity_loop/capacity_cost_store.dart';
import '../capacity_loop/capacity_decision_outcome_models.dart';
import '../capacity_loop/capacity_loop_engine.dart';
import '../capacity_loop/capacity_pull_reason_copy.dart';
import '../capacity_loop/capacity_pull_reason_models.dart';
import '../capacity_loop/capacity_three_moment_gates.dart';
import '../demo/sample_archive_mode.dart';
import 'archive_daily_change_copy.dart';
import 'archive_daily_change_models.dart';

class _DetectedChange {
  const _DetectedChange({
    required this.at,
    required this.kind,
  });

  final DateTime at;
  final ArchiveDailyChangeKind kind;
}

/// Builds daily archive change lines and alternative next moves from local signals.
class ArchiveDailyChangeEngine {
  const ArchiveDailyChangeEngine({
    this.loopEngine = const CapacityLoopEngine(),
  });

  final CapacityLoopEngine loopEngine;

  ArchiveDailyChangeResult build(ArchiveDailyChangeInput input) {
    if (input.sampleMode || !input.capacityWedgeActive) {
      return ArchiveDailyChangeResult.hidden;
    }

    final realEntries = SampleArchiveMode.excludeSampleEntries(input.entries);
    if (realEntries.isEmpty || input.realSavedMomentCount <= 0) {
      return ArchiveDailyChangeResult.hidden;
    }

    if (input.capacityMomentCount <= 0 && input.capacityEvidenceCount <= 0) {
      return ArchiveDailyChangeResult.hidden;
    }

    final since = input.state.lastSeenAt;
    if (input.state.dismissedAt != null &&
        !_hasChangesSince(input, input.state.dismissedAt)) {
      return ArchiveDailyChangeResult.hidden;
    }

    if (since != null && !_hasChangesSince(input, since)) {
      return ArchiveDailyChangeResult.hidden;
    }

    final change = _latestChange(input, since);
    if (change == null && since != null) {
      return ArchiveDailyChangeResult.hidden;
    }

    final changeLine = change != null
        ? ArchiveDailyChangeCopy.changeLineFor(change.kind)
        : ArchiveDailyChangeCopy.changeNewYesMoment;
    final alternative = _alternativeNextMove(input);
    final repeatedLine = _repeatedLine(input.mostCommonPullReasonId);
    final watchNext = ArchiveDailyChangeCopy.watchNextForPullReason(
      input.mostCommonPullReasonId,
    );

    return ArchiveDailyChangeResult(
      hasFeature: true,
      showOnArchiveHome: true,
      showOnCapacityLoop: input.capacityMomentCount >= 2,
      showOnWeeklyReview:
          input.weeklyReviewAvailable && alternative.isNotEmpty,
      title: ArchiveDailyChangeCopy.title,
      changeLine: changeLine,
      repeatedLine: repeatedLine,
      alternativeNextMove: alternative,
      watchNextLine: watchNext,
      alternativeSectionTitle: ArchiveDailyChangeCopy.alternativeSectionTitle,
      loopSectionTitle: ArchiveDailyChangeCopy.loopSectionTitle,
      weeklySectionTitle: ArchiveDailyChangeCopy.weeklySectionTitle,
    );
  }

  ArchiveDailyChangeResult buildFromJournal({
    required List<JournalEntry> entries,
    required bool capacityLoopActive,
    required bool capacityCohortActive,
    required ArchiveDailyChangeState state,
    required List<CapacityPullReasonRecord> pullReasonRecords,
    required List<CapacityCostRecord> costRecords,
    required List<CapacityDecisionOutcomeRecord> outcomeRecords,
    required CapacityBoundaryResponseSelection? boundarySelection,
    required bool weeklyReviewAvailable,
    bool sampleMode = false,
  }) {
    final realEntries = SampleArchiveMode.excludeSampleEntries(entries);
    final capacityMomentCount =
        loopEngine.eligibleCapacityEntryIds(realEntries).length;
    final capacityEvidenceCount = loopEngine.countCapacityEvidence(realEntries);
    final mostCommonPull =
        _mostCommonReasonId(pullReasonRecords);

    return build(
      ArchiveDailyChangeInput(
        sampleMode: sampleMode,
        capacityWedgeActive: capacityLoopActive || capacityCohortActive,
        realSavedMomentCount: BetaFeedbackEngine.realEntryCountFor(entries),
        capacityMomentCount: capacityMomentCount,
        capacityEvidenceCount: capacityEvidenceCount,
        mostCommonPullReasonId: mostCommonPull,
        state: state,
        entries: entries,
        pullReasonRecords: pullReasonRecords,
        costRecords: costRecords,
        outcomeRecords: outcomeRecords,
        boundarySelection: boundarySelection,
        activationFitRecord: null,
        weeklyReviewAvailable: weeklyReviewAvailable,
      ),
    );
  }

  bool _hasChangesSince(ArchiveDailyChangeInput input, DateTime? since) =>
      _detectChanges(input, since).isNotEmpty;

  List<_DetectedChange> _detectChanges(
    ArchiveDailyChangeInput input,
    DateTime? since,
  ) {
    final changes = <_DetectedChange>[];
    final realEntries = SampleArchiveMode.excludeSampleEntries(input.entries);
    final eligibleIds = loopEngine.eligibleCapacityEntryIds(realEntries).toSet();

    for (final entry in realEntries) {
      if (!eligibleIds.contains(entry.id)) continue;
      if (_isAfter(entry.createdAt, since)) {
        changes.add(
          _DetectedChange(
            at: entry.createdAt,
            kind: ArchiveDailyChangeKind.newYesMoment,
          ),
        );
      }
    }

    for (final record in input.pullReasonRecords) {
      if (!record.hasReasons || !_isAfter(record.updatedAt, since)) continue;
      final kind = record.reasonIds.contains(CapacityPullReasonIds.soundedUrgent)
          ? ArchiveDailyChangeKind.urgencyPull
          : ArchiveDailyChangeKind.newYesMoment;
      changes.add(_DetectedChange(at: record.updatedAt, kind: kind));
    }

    for (final record in input.costRecords) {
      if (!record.hasLaterCost || !_isAfter(record.updatedAt, since)) {
        continue;
      }
      changes.add(
        _DetectedChange(
          at: record.updatedAt,
          kind: ArchiveDailyChangeKind.laterCost,
        ),
      );
    }

    final selection = input.boundarySelection;
    if (selection != null &&
        selection.hasSelection &&
        _isAfter(selection.selectedAt, since)) {
      changes.add(
        _DetectedChange(
          at: selection.selectedAt,
          kind: ArchiveDailyChangeKind.boundarySelected,
        ),
      );
    }

    if (input.capacityMomentCount >=
            CapacityThreeMomentGates.activationTarget &&
        _crossedYesLoopThreshold(input, since)) {
      changes.add(
        _DetectedChange(
          at: DateTime.now().toUtc(),
          kind: ArchiveDailyChangeKind.yesLoopReady,
        ),
      );
    }

    changes.sort((a, b) => b.at.compareTo(a.at));
    return changes;
  }

  _DetectedChange? _latestChange(
    ArchiveDailyChangeInput input,
    DateTime? since,
  ) {
    final changes = _detectChanges(input, since);
    if (changes.isEmpty) return null;
    return changes.first;
  }

  bool _crossedYesLoopThreshold(
    ArchiveDailyChangeInput input,
    DateTime? since,
  ) {
    if (since == null) {
      return input.capacityMomentCount >=
          CapacityThreeMomentGates.activationTarget;
    }

    final realEntries = SampleArchiveMode.excludeSampleEntries(input.entries);
    final eligibleIds = loopEngine.eligibleCapacityEntryIds(realEntries);
    final countBefore = eligibleIds
        .map(
          (id) => realEntries.firstWhere((entry) => entry.id == id).createdAt,
        )
        .where((createdAt) => !createdAt.isAfter(since))
        .length;
    final countNow = eligibleIds.length;
    return countBefore < CapacityThreeMomentGates.activationTarget &&
        countNow >= CapacityThreeMomentGates.activationTarget;
  }

  String _alternativeNextMove(ArchiveDailyChangeInput input) {
    final selection = input.boundarySelection;
    if (selection != null && selection.hasSelection) {
      final selected = CapacityBoundaryResponseCopy.textForId(
        selection.responseId,
      );
      if (selected != null && selected.isNotEmpty) return selected;
    }

    final pullId = input.mostCommonPullReasonId;
    if (pullId == null || pullId.isEmpty) {
      return ArchiveDailyChangeCopy.alternativeNoPullReason;
    }
    return ArchiveDailyChangeCopy.alternativeForPullReason(pullId);
  }

  String _repeatedLine(String? mostCommonPullReasonId) {
    if (mostCommonPullReasonId == null || mostCommonPullReasonId.isEmpty) {
      return '';
    }
    final label = CapacityPullReasonCopy.shortLabelForReason(
      mostCommonPullReasonId,
    );
    return 'What repeated: $label.';
  }

  String? _mostCommonReasonId(List<CapacityPullReasonRecord> records) {
    final counts = <String, int>{};
    for (final record in records) {
      if (!record.hasReasons) continue;
      for (final id in record.reasonIds) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return null;
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  bool _isAfter(DateTime value, DateTime? since) =>
      since == null || value.isAfter(since);
}
