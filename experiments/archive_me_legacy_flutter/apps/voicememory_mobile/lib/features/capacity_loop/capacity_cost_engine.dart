import '../../models/journal_entry.dart';
import '../demo/sample_archive_mode.dart';
import 'capacity_launch_wedge_gates.dart';
import 'capacity_cost_copy.dart';
import 'capacity_cost_models.dart';
import 'capacity_cost_store.dart';
import 'capacity_decision_outcome_models.dart';
import 'capacity_decision_outcome_store.dart';
import 'capacity_loop_engine.dart';

/// Builds later-cost check-in visibility and pending targets — local only.
class CapacityCostEngine {
  const CapacityCostEngine({this.loopEngine = const CapacityLoopEngine()});

  final CapacityLoopEngine loopEngine;

  static const minCapacityEvidenceForGeneric = 2;

  CapacityCostCheckinResult build(CapacityCostInput input) {
    if (input.sampleMode || input.realSavedMomentCount <= 0) {
      return CapacityCostCheckinResult.hidden;
    }

    if (!_shouldOfferCheckin(input)) {
      return CapacityCostCheckinResult.hidden;
    }

    final pendingId = input.pendingEntryId?.trim();
    if (pendingId == null || pendingId.isEmpty) {
      return CapacityCostCheckinResult.hidden;
    }

    final recordedCount = CapacityCostStore.countWithLaterCost(input.records);

    return CapacityCostCheckinResult(
      hasCard: true,
      showOnArchiveHome:
          CapacityLaunchWedgeGates.showAdvancedSurfaceOnArchiveHome(
            capacityWedgeActive: input.capacityWedgeActive,
            capacityMomentCount: input.capacityMomentCount,
          ),
      title: CapacityCostCopy.cardTitle,
      body: CapacityCostCopy.cardBody,
      helperText: CapacityCostCopy.cardHelper,
      primaryCtaLabel: CapacityCostCopy.answerCheckinCta,
      secondaryCtaLabel: CapacityCostCopy.skipCta,
      pendingEntryId: pendingId,
      recordedCostCount: recordedCount,
      earlyStateBody: CapacityCostCopy.earlyStateBody,
    );
  }

  CapacityCostCheckinResult buildFromJournal({
    required List<JournalEntry> entries,
    required bool capacityLoopActive,
    required bool capacityCohortActive,
    required List<CapacityCostRecord> records,
    List<CapacityDecisionOutcomeRecord>? outcomeRecords,
    bool sampleMode = false,
  }) {
    final realEntries = SampleArchiveMode.excludeSampleEntries(entries);
    final realCount = loopEngine.realSavedMomentCount(realEntries);
    if (realCount <= 0) return CapacityCostCheckinResult.hidden;

    final capacityCount = loopEngine.countCapacityEvidence(realEntries);
    final momentCount = loopEngine.eligibleCapacityEntryIds(realEntries).length;
    final outcomes = outcomeRecords ?? CapacityDecisionOutcomeStore.cached;
    final pendingId = findPendingEntryId(
      entries: realEntries,
      records: records,
      outcomeRecords: outcomes,
    );

    return build(
      CapacityCostInput(
        realSavedMomentCount: realCount,
        capacityEvidenceCount: capacityCount,
        capacityWedgeActive: capacityLoopActive || capacityCohortActive,
        sampleMode: sampleMode,
        records: records,
        pendingEntryId: pendingId,
        capacityMomentCount: momentCount,
      ),
    );
  }

  String? findPendingEntryId({
    required List<JournalEntry> entries,
    required List<CapacityCostRecord> records,
    required List<CapacityDecisionOutcomeRecord> outcomeRecords,
  }) {
    final eligible = loopEngine.eligibleCapacityEntryIds(entries);
    if (eligible.isEmpty) return null;

    for (final id in eligible.reversed) {
      if (!CapacityDecisionOutcomeStore.hasRecordFor(id, outcomeRecords)) {
        continue;
      }
      if (!CapacityCostStore.hasRecordFor(id, records)) return id;
    }
    return null;
  }

  bool _shouldOfferCheckin(CapacityCostInput input) {
    if (input.capacityEvidenceCount <= 0) return false;
    if (input.capacityWedgeActive) return true;
    return input.capacityEvidenceCount >= minCapacityEvidenceForGeneric;
  }
}
