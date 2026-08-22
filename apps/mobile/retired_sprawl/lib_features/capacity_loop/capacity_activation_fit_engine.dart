import 'package:archiveme_mobile/features/capacity_loop/capacity_activation_fit_copy.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_activation_fit_models.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_activation_fit_store.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_loop_engine.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_three_moment_gates.dart';
import 'package:archiveme_mobile/features/demo/sample_archive_mode.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Builds capacity activation fit visibility — local metadata only.
class CapacityActivationFitEngine {
  const CapacityActivationFitEngine({
    this.loopEngine = const CapacityLoopEngine(),
  });

  final CapacityLoopEngine loopEngine;

  CapacityActivationFitResult build(CapacityActivationFitInput input) {
    if (input.sampleMode) return CapacityActivationFitResult.hidden;

    if (!_isEligible(
      capacityWedgeActive: input.capacityWedgeActive,
      capacityEvidenceCount: input.capacityEvidenceCount,
    )) {
      return CapacityActivationFitResult.hidden;
    }

    if (input.capacityMomentCount < CapacityThreeMomentGates.activationTarget) {
      return CapacityActivationFitResult.hidden;
    }

    final record = input.record;
    if (record?.isComplete == true) {
      if (record!.isAnswered) {
        return CapacityActivationFitResult(
          hasCard: false,
          showOnArchiveHome: false,
          showOnCapacityLoop: false,
          showAnsweredLineOnCapacityLoop: true,
          title: CapacityActivationFitCopy.cardTitle,
          body: CapacityActivationFitCopy.cardBody,
          primaryCtaLabel: CapacityActivationFitCopy.saveFeedbackCta,
          secondaryCtaLabel: CapacityActivationFitCopy.skipCta,
          answeredSummaryLine: CapacityActivationFitCopy.loopMarkedLine(
            record.responseId,
          ),
          activationEntryCount: input.capacityMomentCount,
        );
      }
      return CapacityActivationFitResult.hidden;
    }

    final showOnArchiveHome = _showOnArchiveHome(input);
    return CapacityActivationFitResult(
      hasCard: true,
      showOnArchiveHome: showOnArchiveHome,
      showOnCapacityLoop: true,
      showAnsweredLineOnCapacityLoop: false,
      title: CapacityActivationFitCopy.cardTitle,
      body: CapacityActivationFitCopy.cardBody,
      primaryCtaLabel: CapacityActivationFitCopy.saveFeedbackCta,
      secondaryCtaLabel: CapacityActivationFitCopy.skipCta,
      answeredSummaryLine: '',
      activationEntryCount: input.capacityMomentCount,
    );
  }

  CapacityActivationFitResult buildFromJournal({
    required List<JournalEntry> entries,
    required bool capacityLoopActive,
    required bool capacityCohortActive,
    required bool pendingPullReasonOnHome,
    required bool pendingDecisionOutcomeOnHome,
    required bool pendingCostCheckinOnHome,
    required bool threeMomentActivationOnHome,
    bool sampleMode = false,
    CapacityActivationFitRecord? record,
  }) {
    final realEntries = SampleArchiveMode.excludeSampleEntries(entries);
    if (sampleMode || (entries.isNotEmpty && realEntries.isEmpty)) {
      return CapacityActivationFitResult.hidden;
    }

    final momentCount = loopEngine.eligibleCapacityEntryIds(realEntries).length;
    final capacityCount = loopEngine.countCapacityEvidence(realEntries);

    return build(
      CapacityActivationFitInput(
        sampleMode: sampleMode,
        capacityWedgeActive: capacityLoopActive || capacityCohortActive,
        capacityEvidenceCount: capacityCount,
        capacityMomentCount: momentCount,
        pendingPullReasonOnHome: pendingPullReasonOnHome,
        pendingDecisionOutcomeOnHome: pendingDecisionOutcomeOnHome,
        pendingCostCheckinOnHome: pendingCostCheckinOnHome,
        threeMomentActivationOnHome: threeMomentActivationOnHome,
        record: record ?? CapacityActivationFitStore.cached,
      ),
    );
  }

  static bool _isEligible({
    required bool capacityWedgeActive,
    required int capacityEvidenceCount,
  }) => CapacityThreeMomentGates.isEligible(
    sampleMode: false,
    capacityWedgeActive: capacityWedgeActive,
    capacityEvidenceCount: capacityEvidenceCount,
  );

  static bool _showOnArchiveHome(CapacityActivationFitInput input) =>
      !input.pendingPullReasonOnHome &&
      !input.pendingDecisionOutcomeOnHome &&
      !input.pendingCostCheckinOnHome &&
      !input.threeMomentActivationOnHome;
}