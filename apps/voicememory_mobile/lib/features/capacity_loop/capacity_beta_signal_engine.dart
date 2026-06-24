import '../../models/journal_entry.dart';
import '../demo/sample_archive_mode.dart';
import '../pro_interest/pro_interest_models.dart';
import '../paid_intent/paid_intent_confirmation_copy.dart';
import '../paid_intent/paid_intent_confirmation_models.dart';
import 'capacity_activation_fit_copy.dart';
import 'capacity_activation_fit_models.dart';
import 'capacity_boundary_response_models.dart';
import 'capacity_cost_models.dart';
import 'capacity_decision_outcome_models.dart';
import 'capacity_pull_reason_models.dart';
import 'capacity_beta_signal_copy.dart';
import '../paid_intent/paid_intent_confirmation_models.dart';
import 'capacity_beta_signal_models.dart';
import 'capacity_cost_store.dart';
import 'capacity_decision_outcome_store.dart';
import 'capacity_loop_engine.dart';
import 'capacity_pull_reason_store.dart';
import 'capacity_three_moment_gates.dart';
import 'capacity_weekly_review_engine.dart';

/// Aggregates local capacity beta signals — read-only, no journal text.
class CapacityBetaSignalEngine {
  const CapacityBetaSignalEngine({
    this.loopEngine = const CapacityLoopEngine(),
    this.weeklyReviewEngine = const CapacityWeeklyReviewEngine(),
  });

  final CapacityLoopEngine loopEngine;
  final CapacityWeeklyReviewEngine weeklyReviewEngine;

  CapacityBetaSignalSnapshot build(CapacityBetaSignalInput input) {
    final target = input.activationTarget;
    final momentCount = input.capacityMomentCount.clamp(0, 999);
    final activationReached = momentCount >= target;
    final hasCapacityEvidence = _hasCapacityEvidence(input);

    final verdict = _computeVerdict(
      momentCount: momentCount,
      activationTarget: target,
      fitIsPositive: input.fitIsPositive,
      fitIsUnclear: input.fitIsUnclear,
      outcomeRecordCount: input.outcomeRecordCount,
      laterCostRecordCount: input.laterCostRecordCount,
      boundaryResponseSelected: input.boundaryResponseSelected,
    );

    final paymentSignalLabel = _paymentSignalLabel(
      trackPaymentSignal: input.trackPaymentSignal,
      paidIntent: input.paidIntentRecord,
      proInterestCaptured: input.proInterestCaptured,
    );

    return CapacityBetaSignalSnapshot(
      hasCapacityEvidence: hasCapacityEvidence,
      capacityMomentCount: momentCount,
      activationTarget: target,
      activationReached: activationReached,
      fitResponseLabel: input.fitResponseLabel,
      pullReasonRecordCount: input.pullReasonRecordCount,
      outcomeRecordCount: input.outcomeRecordCount,
      laterCostRecordCount: input.laterCostRecordCount,
      weeklyReviewAvailable: input.weeklyReviewAvailable,
      boundaryResponseSelected: input.boundaryResponseSelected,
      boundaryResponseCopied: input.boundaryResponseCopied,
      proInterestCaptured: input.proInterestCaptured,
      paidIntentAnswered: input.paidIntentRecord?.isAnswered ?? false,
      paidIntentStrongWtp: input.paidIntentRecord?.isStrongWtp ?? false,
      paidIntentSoftWtp: input.paidIntentRecord?.isSoftWtp ?? false,
      paymentSignalLabel: paymentSignalLabel,
      verdict: verdict,
      verdictLabel: CapacityBetaSignalCopy.verdictLabelFor(verdict),
      exportSummary: _buildExportSummary(
        momentCount: momentCount,
        fitResponseLabel: input.fitResponseLabel,
        outcomeRecordCount: input.outcomeRecordCount,
        laterCostRecordCount: input.laterCostRecordCount,
        boundaryResponseSelected: input.boundaryResponseSelected,
      ),
    );
  }

  CapacityBetaSignalSnapshot buildFromJournal({
    required List<JournalEntry> entries,
    required bool capacityLoopActive,
    required bool capacityCohortActive,
    CapacityActivationFitRecord? fitRecord,
    List<CapacityPullReasonRecord>? pullReasonRecords,
    List<CapacityDecisionOutcomeRecord>? outcomeRecords,
    List<CapacityCostRecord>? costRecords,
    CapacityBoundaryResponseSelection? boundarySelection,
    ProInterestState proInterestState = ProInterestState.empty,
    PaidIntentConfirmationRecord? paidIntentRecord,
    bool dailyChangeAvailable = false,
    bool trackPaymentSignal = true,
    bool sampleMode = false,
  }) {
    if (sampleMode) return CapacityBetaSignalSnapshot.empty;

    final realEntries = SampleArchiveMode.excludeSampleEntries(entries);
    if (entries.isNotEmpty && realEntries.isEmpty) {
      return CapacityBetaSignalSnapshot.empty;
    }

    final momentCount = loopEngine.eligibleCapacityEntryIds(realEntries).length;
    final evidenceCount = loopEngine.countCapacityEvidence(realEntries);
    final pullRecords = pullReasonRecords ?? CapacityPullReasonStore.cached;
    final outcomeRecordsResolved =
        outcomeRecords ?? CapacityDecisionOutcomeStore.cached;
    final costRecordsResolved = costRecords ?? CapacityCostStore.cached;

    final weeklyReview = weeklyReviewEngine.buildFromJournal(
      entries: entries,
      capacityLoopActive: capacityLoopActive,
      capacityCohortActive: capacityCohortActive,
      costRecords: costRecordsResolved,
      outcomeRecords: outcomeRecordsResolved,
      pullReasonRecords: pullRecords,
    );

    final fitMeta = _fitMetadata(fitRecord);

    return build(
      CapacityBetaSignalInput(
        capacityMomentCount: momentCount,
        capacityEvidenceCount: evidenceCount,
        capacityWedgeActive: capacityLoopActive || capacityCohortActive,
        activationTarget: CapacityThreeMomentGates.activationTarget,
        fitResponseLabel: fitMeta.label,
        fitIsPositive: fitMeta.isPositive,
        fitIsUnclear: fitMeta.isUnclear,
        pullReasonRecordCount:
            CapacityPullReasonStore.countWithReason(pullRecords),
        outcomeRecordCount:
            CapacityDecisionOutcomeStore.countWithOutcome(outcomeRecordsResolved),
        laterCostRecordCount:
            CapacityCostStore.countWithLaterCost(costRecordsResolved),
        weeklyReviewAvailable: weeklyReview.hasReview,
        boundaryResponseSelected: boundarySelection?.hasSelection ?? false,
        boundaryResponseCopied: boundarySelection?.lastCopiedAt != null,
        proInterestCaptured: proInterestState.hasCapture,
        paidIntentRecord: paidIntentRecord,
        dailyChangeAvailable: dailyChangeAvailable,
        trackPaymentSignal: trackPaymentSignal,
      ),
    );
  }

  static bool _hasCapacityEvidence(CapacityBetaSignalInput input) {
    if (input.capacityMomentCount > 0) return true;
    if (input.capacityEvidenceCount >= 2) return true;
    if (input.capacityWedgeActive &&
        (input.pullReasonRecordCount > 0 ||
            input.outcomeRecordCount > 0 ||
            input.laterCostRecordCount > 0)) {
      return true;
    }
    return input.fitResponseLabel != CapacityBetaSignalCopy.notAnsweredLabel;
  }

  static CapacityBetaSignalVerdict _computeVerdict({
    required int momentCount,
    required int activationTarget,
    required bool fitIsPositive,
    required bool fitIsUnclear,
    required int outcomeRecordCount,
    required int laterCostRecordCount,
    required bool boundaryResponseSelected,
  }) {
    if (momentCount < activationTarget) {
      return CapacityBetaSignalVerdict.weak;
    }
    if (fitIsPositive) {
      final strong = outcomeRecordCount >= 1 &&
          laterCostRecordCount >= 1 &&
          boundaryResponseSelected;
      return strong
          ? CapacityBetaSignalVerdict.strong
          : CapacityBetaSignalVerdict.promising;
    }
    if (fitIsUnclear || !fitIsPositive) {
      return CapacityBetaSignalVerdict.unclear;
    }
    return CapacityBetaSignalVerdict.unclear;
  }

  static _FitMetadata _fitMetadata(CapacityActivationFitRecord? record) {
    if (record == null) {
      return const _FitMetadata(
        label: CapacityBetaSignalCopy.notAnsweredLabel,
        isPositive: false,
        isUnclear: true,
      );
    }
    if (record.isSkipped) {
      return const _FitMetadata(
        label: CapacityBetaSignalCopy.skippedLabel,
        isPositive: false,
        isUnclear: true,
      );
    }
    if (!record.isAnswered) {
      return const _FitMetadata(
        label: CapacityBetaSignalCopy.notAnsweredLabel,
        isPositive: false,
        isUnclear: true,
      );
    }
    final shortLabel =
        CapacityActivationFitCopy.shortLabelForResponse(record.responseId);
    final label =
        shortLabel.isEmpty ? CapacityBetaSignalCopy.notAnsweredLabel : shortLabel;
    final isPositive = record.responseId ==
            CapacityActivationFitResponseIds.fits ||
        record.responseId == CapacityActivationFitResponseIds.partly;
    final isUnclear = record.responseId ==
            CapacityActivationFitResponseIds.notYet ||
        record.responseId == CapacityActivationFitResponseIds.tooEarly;
    return _FitMetadata(
      label: label,
      isPositive: isPositive,
      isUnclear: isUnclear || !isPositive,
    );
  }

  static String _paymentSignalLabel({
    required bool trackPaymentSignal,
    required PaidIntentConfirmationRecord? paidIntent,
    required bool proInterestCaptured,
  }) {
    if (!trackPaymentSignal) {
      return CapacityBetaSignalCopy.paymentNotTrackedLabel;
    }
    if (paidIntent != null && paidIntent.isComplete) {
      return PaidIntentConfirmationCopy.paymentSignalLabelForRecord(paidIntent);
    }
    if (proInterestCaptured) {
      return CapacityBetaSignalCopy.proInterestFallbackLabel;
    }
    return CapacityBetaSignalCopy.noLabel;
  }

  static String _buildExportSummary({
    required int momentCount,
    required String fitResponseLabel,
    required int outcomeRecordCount,
    required int laterCostRecordCount,
    required bool boundaryResponseSelected,
  }) {
    final parts = <String>[
      'ArchiveMe capacity beta signal: $momentCount yes moments',
      'fit response $fitResponseLabel',
      '$outcomeRecordCount outcomes',
      '$laterCostRecordCount later costs',
      if (boundaryResponseSelected) 'boundary response selected',
    ];
    return '${parts.join(', ')}.';
  }
}

class _FitMetadata {
  const _FitMetadata({
    required this.label,
    required this.isPositive,
    required this.isUnclear,
  });

  final String label;
  final bool isPositive;
  final bool isUnclear;
}
