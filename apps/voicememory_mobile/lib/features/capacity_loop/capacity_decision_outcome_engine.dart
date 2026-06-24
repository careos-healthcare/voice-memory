import '../../models/journal_entry.dart';
import '../demo/sample_archive_mode.dart';
import 'capacity_decision_outcome_copy.dart';
import 'capacity_decision_outcome_models.dart';
import 'capacity_decision_outcome_store.dart';
import 'capacity_loop_engine.dart';
import 'capacity_pull_reason_store.dart';

/// Builds decision outcome visibility and pending targets — local only.
class CapacityDecisionOutcomeEngine {
  const CapacityDecisionOutcomeEngine({
    this.loopEngine = const CapacityLoopEngine(),
  });

  final CapacityLoopEngine loopEngine;

  static const minCapacityEvidenceForGeneric = 2;

  CapacityDecisionOutcomeResult build(CapacityDecisionOutcomeInput input) {
    if (input.sampleMode || input.realSavedMomentCount <= 0) {
      return CapacityDecisionOutcomeResult.hidden;
    }

    if (!_shouldOfferOutcome(input)) {
      return CapacityDecisionOutcomeResult.hidden;
    }

    final pendingId = input.pendingEntryId?.trim();
    if (pendingId == null || pendingId.isEmpty) {
      return CapacityDecisionOutcomeResult.hidden;
    }

    final recordedCount =
        CapacityDecisionOutcomeStore.countWithOutcome(input.records);

    return CapacityDecisionOutcomeResult(
      hasCard: true,
      showOnArchiveHome: true,
      title: CapacityDecisionOutcomeCopy.cardTitle,
      body: CapacityDecisionOutcomeCopy.cardBody,
      helperText: CapacityDecisionOutcomeCopy.cardHelper,
      primaryCtaLabel: CapacityDecisionOutcomeCopy.saveOutcomeCta,
      secondaryCtaLabel: CapacityDecisionOutcomeCopy.skipCta,
      pendingEntryId: pendingId,
      recordedOutcomeCount: recordedCount,
    );
  }

  CapacityDecisionOutcomeResult buildFromJournal({
    required List<JournalEntry> entries,
    required bool capacityLoopActive,
    required bool capacityCohortActive,
    required List<CapacityDecisionOutcomeRecord> records,
    bool sampleMode = false,
  }) {
    final realEntries = SampleArchiveMode.excludeSampleEntries(entries);
    final realCount = loopEngine.realSavedMomentCount(realEntries);
    if (realCount <= 0) return CapacityDecisionOutcomeResult.hidden;

    final capacityCount = loopEngine.countCapacityEvidence(realEntries);
    final pendingId = findPendingEntryId(
      entries: realEntries,
      records: records,
    );

    return build(
      CapacityDecisionOutcomeInput(
        realSavedMomentCount: realCount,
        capacityEvidenceCount: capacityCount,
        capacityWedgeActive: capacityLoopActive || capacityCohortActive,
        sampleMode: sampleMode,
        records: records,
        pendingEntryId: pendingId,
      ),
    );
  }

  String? findPendingEntryId({
    required List<JournalEntry> entries,
    required List<CapacityDecisionOutcomeRecord> records,
  }) {
    final eligible = loopEngine.eligibleCapacityEntryIds(entries);
    if (eligible.isEmpty) return null;

    for (final id in eligible.reversed) {
      if (!CapacityPullReasonStore.hasRecordFor(id)) continue;
      if (!CapacityDecisionOutcomeStore.hasRecordFor(id, records)) return id;
    }
    return null;
  }

  bool _shouldOfferOutcome(CapacityDecisionOutcomeInput input) {
    if (input.capacityEvidenceCount <= 0) return false;
    if (input.capacityWedgeActive) return true;
    return input.capacityEvidenceCount >= minCapacityEvidenceForGeneric;
  }
}
