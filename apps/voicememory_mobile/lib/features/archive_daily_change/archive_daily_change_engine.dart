import '../../models/journal_entry.dart';
import '../beta_feedback/beta_feedback_engine.dart';
import '../capacity_loop/capacity_activation_fit_models.dart';
import '../capacity_loop/capacity_boundary_response_copy.dart';
import '../capacity_loop/capacity_boundary_response_models.dart';
import '../capacity_loop/capacity_cost_models.dart';
import '../capacity_loop/capacity_decision_outcome_models.dart';
import '../capacity_loop/capacity_loop_engine.dart';
import '../capacity_loop/capacity_pull_reason_copy.dart';
import '../capacity_loop/capacity_pull_reason_models.dart';
import '../capacity_loop/capacity_three_moment_gates.dart';
import '../capacity_loop/quick_capture_friction_store.dart';
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

class _SharpenedResponse {
  const _SharpenedResponse({
    required this.type,
    required this.changeLine,
    required this.alternativeLabel,
    required this.alternativeBody,
    required this.watchNextLine,
    required this.repeatedLine,
  });

  final ArchiveDailyChangeResponseType type;
  final String changeLine;
  final String alternativeLabel;
  final String alternativeBody;
  final String watchNextLine;
  final String repeatedLine;
}

class _ResolvedAlternative {
  const _ResolvedAlternative({
    required this.label,
    required this.body,
  });

  final String label;
  final String body;
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

    if (since != null && _latestChange(input, since) == null) {
      return ArchiveDailyChangeResult.hidden;
    }

    final sharpened = _sharpenedResponse(input, since);

    return ArchiveDailyChangeResult(
      hasFeature: true,
      showOnArchiveHome: true,
      showOnCapacityLoop: input.capacityMomentCount >= 2,
      showOnWeeklyReview:
          input.weeklyReviewAvailable && sharpened.alternativeBody.isNotEmpty,
      responseType: sharpened.type,
      title: ArchiveDailyChangeCopy.title,
      changeLine: sharpened.changeLine,
      repeatedLine: sharpened.repeatedLine,
      alternativeLabel: sharpened.alternativeLabel,
      alternativeNextMove: sharpened.alternativeBody,
      watchNextLine: sharpened.watchNextLine,
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
    CapacityActivationFitRecord? activationFitRecord,
    required bool weeklyReviewAvailable,
    bool sampleMode = false,
  }) {
    final realEntries = SampleArchiveMode.excludeSampleEntries(entries);
    final capacityMomentCount =
        loopEngine.eligibleCapacityEntryIds(realEntries).length;
    final capacityEvidenceCount = loopEngine.countCapacityEvidence(realEntries);
    final mostCommonPull = _mostCommonReasonId(pullReasonRecords);
    final pullReasonCount = pullReasonRecords.where((r) => r.hasReasons).length;

    return build(
      ArchiveDailyChangeInput(
        sampleMode: sampleMode,
        capacityWedgeActive: capacityLoopActive || capacityCohortActive,
        realSavedMomentCount: BetaFeedbackEngine.realEntryCountFor(entries),
        capacityMomentCount: capacityMomentCount,
        capacityEvidenceCount: capacityEvidenceCount,
        mostCommonPullReasonId: mostCommonPull,
        pullReasonRecordCount: pullReasonCount,
        state: state,
        entries: entries,
        pullReasonRecords: pullReasonRecords,
        costRecords: costRecords,
        outcomeRecords: outcomeRecords,
        boundarySelection: boundarySelection,
        activationFitRecord: activationFitRecord,
        weeklyReviewAvailable: weeklyReviewAvailable,
        quickCaptureFrictionRecord: QuickCaptureFrictionStore.cached,
      ),
    );
  }

  _SharpenedResponse _sharpenedResponse(
    ArchiveDailyChangeInput input,
    DateTime? since,
  ) {
    final pullId = input.mostCommonPullReasonId;
    final pullShort = ArchiveDailyChangeCopy.pullShortLabel(pullId);
    final pullCount = _pullOccurrenceCount(pullId, input.pullReasonRecords);
    final hasLaterCost = input.costRecords.any((record) => record.hasLaterCost);
    final hasSaidYes = input.outcomeRecords.any(
      (record) =>
          record.hasOutcome &&
          record.outcomeId == CapacityDecisionOutcomeIds.saidYes,
    );
    final hasDelayed = input.outcomeRecords.any(
      (record) =>
          record.hasOutcome &&
          record.outcomeId == CapacityDecisionOutcomeIds.delayed,
    );
    final hasPatternChange = input.outcomeRecords.any(
      (record) => record.showsPatternChange,
    );
    final fitRecord = input.activationFitRecord;
    final fitPartly = fitRecord != null &&
        fitRecord.isAnswered &&
        fitRecord.responseId == CapacityActivationFitResponseIds.partly;
    final fitConfirmed = fitRecord != null &&
        fitRecord.isAnswered &&
        fitRecord.responseId == CapacityActivationFitResponseIds.fits;
    final noPullReason = input.pullReasonRecordCount == 0;
    final stillForming = input.capacityMomentCount <
        CapacityThreeMomentGates.activationTarget;
    final friction = input.quickCaptureFrictionRecord;
    final hasNewMoment = _hasNewMomentSince(input, since);

    if (friction?.isStillWork == true && _isAfter(friction!.updatedAt, since)) {
      return _SharpenedResponse(
        type: ArchiveDailyChangeResponseType.quickCaptureStillWork,
        changeLine: ArchiveDailyChangeCopy.quickCaptureStillWorkLine,
        alternativeLabel: ArchiveDailyChangeCopy.labelSaveMomentOnly,
        alternativeBody: ArchiveDailyChangeCopy.altQuickCaptureStillWork,
        watchNextLine: ArchiveDailyChangeCopy.watchHardToDelay,
        repeatedLine: '',
      );
    }

    if (fitPartly && hasNewMoment) {
      final alternative = _resolveAlternative(input, pullId);
      return _SharpenedResponse(
        type: ArchiveDailyChangeResponseType.fitPartlyNewMoment,
        changeLine: ArchiveDailyChangeCopy.fitPartlyNewMomentLine,
        alternativeLabel: alternative.label,
        alternativeBody: alternative.body,
        watchNextLine: ArchiveDailyChangeCopy.watchNextForPullReason(pullId),
        repeatedLine: _repeatedLine(pullId),
      );
    }

    if (pullId == CapacityPullReasonIds.feltResponsible &&
        pullCount >= 2 &&
        hasDelayed) {
      final alternative = _resolveAlternative(input, pullId);
      return _SharpenedResponse(
        type: ArchiveDailyChangeResponseType.patternInterrupted,
        changeLine: ArchiveDailyChangeCopy.responsibilityRepeatedDelayedLine,
        alternativeLabel: alternative.label,
        alternativeBody: alternative.body,
        watchNextLine: ArchiveDailyChangeCopy.watchAnswerBeforeCapacity,
        repeatedLine: _repeatedLine(pullId),
      );
    }

    if (pullId != null &&
        pullCount >= 2 &&
        hasLaterCost &&
        pullId == CapacityPullReasonIds.soundedUrgent) {
      final alternative = _resolveAlternative(
        input,
        CapacityPullReasonIds.soundedUrgent,
      );
      return _SharpenedResponse(
        type: ArchiveDailyChangeResponseType.repeatedPullWithLaterCost,
        changeLine: ArchiveDailyChangeCopy.urgencyWithLaterCostLine,
        alternativeLabel: alternative.label,
        alternativeBody: alternative.body,
        watchNextLine: ArchiveDailyChangeCopy.watchUrgentResponsible,
        repeatedLine: _repeatedLine(pullId),
      );
    }

    if (pullId != null && pullCount >= 2 && hasLaterCost) {
      final alternative = _resolveAlternative(input, pullId);
      return _SharpenedResponse(
        type: ArchiveDailyChangeResponseType.repeatedPullWithLaterCost,
        changeLine: ArchiveDailyChangeCopy.repeatedPullWithLaterCostLine(
          pullShort,
        ),
        alternativeLabel: alternative.label,
        alternativeBody: alternative.body,
        watchNextLine: ArchiveDailyChangeCopy.watchNextForPullReason(pullId),
        repeatedLine: _repeatedLine(pullId),
      );
    }

    if (pullId != null && pullCount >= 2 && hasSaidYes) {
      final alternative = _resolveAlternative(input, pullId);
      return _SharpenedResponse(
        type: ArchiveDailyChangeResponseType.repeatedPullWithSaidYes,
        changeLine: ArchiveDailyChangeCopy.repeatedPullWithSaidYesLine(pullShort),
        alternativeLabel: alternative.label,
        alternativeBody: alternative.body,
        watchNextLine: ArchiveDailyChangeCopy.watchSamePullMayRepeat,
        repeatedLine: _repeatedLine(pullId),
      );
    }

    if (hasPatternChange) {
      final alternative = _resolveAlternative(input, pullId);
      return _SharpenedResponse(
        type: ArchiveDailyChangeResponseType.patternInterrupted,
        changeLine: ArchiveDailyChangeCopy.patternInterruptedLine,
        alternativeLabel: alternative.label,
        alternativeBody: alternative.body,
        watchNextLine: ArchiveDailyChangeCopy.watchAnswerBeforeCapacity,
        repeatedLine: _repeatedLine(pullId),
      );
    }

    if (fitConfirmed) {
      final alternative = _resolveAlternative(input, pullId);
      return _SharpenedResponse(
        type: ArchiveDailyChangeResponseType.fitConfirmed,
        changeLine: ArchiveDailyChangeCopy.fitConfirmedLine,
        alternativeLabel: ArchiveDailyChangeCopy.labelWatchPull,
        alternativeBody: ArchiveDailyChangeCopy.bodyWatchSamePull,
        watchNextLine: ArchiveDailyChangeCopy.watchNextForPullReason(pullId),
        repeatedLine: _repeatedLine(pullId),
      );
    }

    if (stillForming && hasNewMoment) {
      final alternative = _resolveAlternative(input, pullId);
      return _SharpenedResponse(
        type: ArchiveDailyChangeResponseType.waitingForNextMoment,
        changeLine: ArchiveDailyChangeCopy.waitingForNextMomentLine,
        alternativeLabel: alternative.label,
        alternativeBody: alternative.body,
        watchNextLine: ArchiveDailyChangeCopy.watchHardToDelay,
        repeatedLine: '',
      );
    }

    if (stillForming) {
      return _SharpenedResponse(
        type: ArchiveDailyChangeResponseType.stillForming,
        changeLine: ArchiveDailyChangeCopy.stillFormingLine,
        alternativeLabel: ArchiveDailyChangeCopy.labelSaveMomentOnly,
        alternativeBody: ArchiveDailyChangeCopy.bodyOneMoreMoment,
        watchNextLine: ArchiveDailyChangeCopy.watchHardToDelay,
        repeatedLine: '',
      );
    }

    if (noPullReason && input.capacityMomentCount >= 1) {
      return _SharpenedResponse(
        type: ArchiveDailyChangeResponseType.noPullReasonYet,
        changeLine: ArchiveDailyChangeCopy.noPullReasonLine,
        alternativeLabel: ArchiveDailyChangeCopy.labelMarkPullFirst,
        alternativeBody: ArchiveDailyChangeCopy.bodyMarkPull,
        watchNextLine: ArchiveDailyChangeCopy.watchHardToDelay,
        repeatedLine: '',
      );
    }

    return _recentChangeResponse(input, since, pullId, pullShort);
  }

  _SharpenedResponse _recentChangeResponse(
    ArchiveDailyChangeInput input,
    DateTime? since,
    String? pullId,
    String pullShort,
  ) {
    final change = _latestChange(input, since);
    final changeLine = switch (change?.kind) {
      ArchiveDailyChangeKind.laterCost => ArchiveDailyChangeCopy.changeLaterCost,
      ArchiveDailyChangeKind.boundarySelected =>
        ArchiveDailyChangeCopy.changeBoundarySelected,
      ArchiveDailyChangeKind.yesLoopReady =>
        ArchiveDailyChangeCopy.changeYesLoopReady,
      ArchiveDailyChangeKind.urgencyPull =>
        ArchiveDailyChangeCopy.urgencyWithLaterCostLine,
      _ => ArchiveDailyChangeCopy.changeNewYesMoment,
    };

    final alternative = _resolveAlternative(input, pullId);
    return _SharpenedResponse(
      type: ArchiveDailyChangeResponseType.recentChange,
      changeLine: changeLine,
      alternativeLabel: alternative.label,
      alternativeBody: alternative.body,
      watchNextLine: ArchiveDailyChangeCopy.watchNextForPullReason(pullId),
      repeatedLine: _repeatedLine(pullId),
    );
  }

  _ResolvedAlternative _resolveAlternative(
    ArchiveDailyChangeInput input,
    String? pullId,
  ) {
    final boundaryBody = _selectedBoundaryBody(input.boundarySelection);
    if (boundaryBody != null) {
      return _ResolvedAlternative(
        label: ArchiveDailyChangeCopy.labelUseDefaultPause,
        body: boundaryBody,
      );
    }

    return _ResolvedAlternative(
      label: ArchiveDailyChangeCopy.alternativeLabelForPull(pullId),
      body: ArchiveDailyChangeCopy.alternativeBodyForPull(pullId),
    );
  }

  String? _selectedBoundaryBody(CapacityBoundaryResponseSelection? selection) {
    if (selection == null || !selection.hasSelection) return null;
    return CapacityBoundaryResponseCopy.textForId(selection.responseId);
  }

  bool _hasNewMomentSince(ArchiveDailyChangeInput input, DateTime? since) {
    final change = _latestChange(input, since);
    if (change == null) return false;
    return change.kind == ArchiveDailyChangeKind.newYesMoment ||
        change.kind == ArchiveDailyChangeKind.urgencyPull;
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

    for (final record in input.outcomeRecords) {
      if (!record.hasOutcome || !_isAfter(record.updatedAt, since)) continue;
      changes.add(
        _DetectedChange(
          at: record.updatedAt,
          kind: ArchiveDailyChangeKind.newYesMoment,
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

    final fit = input.activationFitRecord;
    if (fit != null &&
        fit.isAnswered &&
        _isAfter(fit.updatedAt, since)) {
      changes.add(
        _DetectedChange(
          at: fit.updatedAt,
          kind: ArchiveDailyChangeKind.fitAnswered,
        ),
      );
    }

    final friction = input.quickCaptureFrictionRecord;
    if (friction != null &&
        friction.isAnswered &&
        _isAfter(friction.updatedAt, since)) {
      changes.add(
        _DetectedChange(
          at: friction.updatedAt,
          kind: ArchiveDailyChangeKind.newYesMoment,
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

  String _repeatedLine(String? mostCommonPullReasonId) {
    if (mostCommonPullReasonId == null || mostCommonPullReasonId.isEmpty) {
      return '';
    }
    final label = CapacityPullReasonCopy.shortLabelForReason(
      mostCommonPullReasonId,
    );
    return 'What repeated: $label.';
  }

  int _pullOccurrenceCount(
    String? pullId,
    List<CapacityPullReasonRecord> records,
  ) {
    if (pullId == null || pullId.isEmpty) return 0;
    var count = 0;
    for (final record in records) {
      if (!record.hasReasons) continue;
      for (final id in record.reasonIds) {
        if (id == pullId) count++;
      }
    }
    return count;
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
