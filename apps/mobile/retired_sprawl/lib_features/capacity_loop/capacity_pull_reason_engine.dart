import 'package:archiveme_mobile/features/capacity_loop/capacity_launch_wedge_gates.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_loop_engine.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_pull_reason_copy.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_pull_reason_models.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_pull_reason_store.dart';
import 'package:archiveme_mobile/features/demo/sample_archive_mode.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Builds pull reason visibility and pending targets — local only.
class CapacityPullReasonEngine {
  const CapacityPullReasonEngine({
    this.loopEngine = const CapacityLoopEngine(),
  });

  final CapacityLoopEngine loopEngine;

  static const minCapacityEvidenceForGeneric = 2;

  CapacityPullReasonResult build(CapacityPullReasonInput input) {
    if (input.sampleMode || input.realSavedMomentCount <= 0) {
      return CapacityPullReasonResult.hidden;
    }

    if (!_shouldOfferPullReason(input)) {
      return CapacityPullReasonResult.hidden;
    }

    final pendingId = input.pendingEntryId?.trim();
    if (pendingId == null || pendingId.isEmpty) {
      return CapacityPullReasonResult.hidden;
    }

    return CapacityPullReasonResult(
      hasCard: true,
      showOnArchiveHome:
          CapacityLaunchWedgeGates.showAdvancedSurfaceOnArchiveHome(
            capacityWedgeActive: input.capacityWedgeActive,
            capacityMomentCount: input.capacityMomentCount,
          ),
      title: CapacityPullReasonCopy.cardTitle,
      body: CapacityPullReasonCopy.cardBody,
      primaryCtaLabel: CapacityPullReasonCopy.saveReasonCta,
      secondaryCtaLabel: CapacityPullReasonCopy.skipCta,
      pendingEntryId: pendingId,
      recordedReasonCount: CapacityPullReasonStore.countWithReason(
        input.records,
      ),
    );
  }

  CapacityPullReasonResult buildFromJournal({
    required List<JournalEntry> entries,
    required bool capacityLoopActive,
    required bool capacityCohortActive,
    required List<CapacityPullReasonRecord> records,
    bool sampleMode = false,
  }) {
    final realEntries = SampleArchiveMode.excludeSampleEntries(entries);
    final realCount = loopEngine.realSavedMomentCount(realEntries);
    if (realCount <= 0) return CapacityPullReasonResult.hidden;

    final capacityCount = loopEngine.countCapacityEvidence(realEntries);
    final momentCount = loopEngine.eligibleCapacityEntryIds(realEntries).length;
    final pendingId = findPendingEntryId(
      entries: realEntries,
      records: records,
    );

    return build(
      CapacityPullReasonInput(
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
    required List<CapacityPullReasonRecord> records,
  }) {
    final eligible = loopEngine.eligibleCapacityEntryIds(entries);
    if (eligible.isEmpty) return null;

    for (final id in eligible.reversed) {
      if (!CapacityPullReasonStore.hasRecordFor(id, records)) return id;
    }
    return null;
  }

  static String loopPullSummary(List<CapacityPullReasonRecord> records) {
    final mostCommon = CapacityPullReasonStore.mostCommonReasonId(records);
    if (mostCommon == null) return CapacityPullReasonCopy.loopStrengthenPrompt;
    return CapacityPullReasonCopy.mostCommonPullLabel(
      CapacityPullReasonCopy.labelForReason(mostCommon),
    );
  }

  static String weeklyPullSummary(List<CapacityPullReasonRecord> records) {
    final mostCommon = CapacityPullReasonStore.mostCommonReasonId(records);
    if (mostCommon == null) return CapacityPullReasonCopy.weeklyFormingCopy;
    return CapacityPullReasonCopy.weeklyMostCommonLine(
      CapacityPullReasonCopy.shortLabelForReason(mostCommon),
    );
  }

  bool _shouldOfferPullReason(CapacityPullReasonInput input) {
    if (input.capacityEvidenceCount <= 0) return false;
    if (input.capacityWedgeActive) return true;
    return input.capacityEvidenceCount >= minCapacityEvidenceForGeneric;
  }
}