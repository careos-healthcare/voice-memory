import '../../models/journal_entry.dart';
import '../demo/sample_archive_mode.dart';
import 'capacity_loop_engine.dart';
import 'capacity_three_moment_copy.dart';
import 'capacity_three_moment_gates.dart';
import 'capacity_three_moment_models.dart';
import 'low_effort_yes_capture_copy.dart';
import 'low_effort_yes_capture_engine.dart';
import 'low_effort_yes_capture_models.dart';

/// Builds capacity 3-moment activation from local entry counts — no storage.
class CapacityThreeMomentEngine {
  const CapacityThreeMomentEngine({
    this.loopEngine = const CapacityLoopEngine(),
  });

  final CapacityLoopEngine loopEngine;

  CapacityThreeMomentResult build(CapacityThreeMomentInput input) {
    if (!CapacityThreeMomentGates.isEligible(
      sampleMode: input.sampleMode,
      capacityWedgeActive: input.capacityWedgeActive,
      capacityEvidenceCount: input.capacityEvidenceCount,
    )) {
      return CapacityThreeMomentResult.hidden;
    }

    final count = input.capacityMomentCount.clamp(0, 999);
    if (count > CapacityThreeMomentGates.activationTarget) {
      return CapacityThreeMomentResult.hidden;
    }

    final target = CapacityThreeMomentGates.activationTarget;
    final atTarget = count >= target;
    final hasCard = true;
    final quickCapture = const LowEffortYesCaptureEngine().build(
      LowEffortYesCaptureInput(
        capacityWedgeActive: input.capacityWedgeActive,
        sampleMode: input.sampleMode,
        screenshotMode: false,
      ),
    );

    return CapacityThreeMomentResult(
      hasCard: hasCard,
      showOnArchiveHome: CapacityThreeMomentGates.showOnArchiveHome(
        hasCard: hasCard,
        capacityMomentCount: count,
      ),
      showOnRecordProgress: CapacityThreeMomentGates.showOnRecordProgress(
        eligible: true,
        capacityWedgeActive: input.capacityWedgeActive,
        capacityMomentCount: count,
      ),
      showOnCapacityLoop: CapacityThreeMomentGates.showOnCapacityLoop(
        eligible: true,
        capacityMomentCount: count,
      ),
      title: CapacityThreeMomentCopy.cardTitle,
      subtitle: CapacityThreeMomentCopy.cardSubtitle,
      progressLabel: CapacityThreeMomentCopy.progressLabel(
        count,
        target: target,
      ),
      emptyBody: count <= 0 ? CapacityThreeMomentCopy.emptyBody : '',
      primaryCtaLabel: atTarget
          ? CapacityThreeMomentCopy.reviewLoopCta
          : CapacityThreeMomentCopy.saveYesMomentCta,
      primaryRoute: atTarget
          ? CapacityThreeMomentCopy.loopRoute
          : CapacityThreeMomentCopy.recordRoute,
      showQuickSaveSecondary: !atTarget && quickCapture.showCard,
      quickSaveRoute: LowEffortYesCaptureCopy.route,
      capacityMomentCount: count,
      activationTarget: target,
    );
  }

  CapacityThreeMomentResult buildFromJournal({
    required List<JournalEntry> entries,
    required bool capacityLoopActive,
    required bool capacityCohortActive,
    bool sampleMode = false,
  }) {
    final realEntries = SampleArchiveMode.excludeSampleEntries(entries);
    if (sampleMode || (entries.isNotEmpty && realEntries.isEmpty)) {
      return CapacityThreeMomentResult.hidden;
    }
    final capacityCount = loopEngine.countCapacityEvidence(realEntries);
    final momentCount =
        loopEngine.eligibleCapacityEntryIds(realEntries).length;

    return build(
      CapacityThreeMomentInput(
        sampleMode: sampleMode,
        capacityWedgeActive: capacityLoopActive || capacityCohortActive,
        capacityEvidenceCount: capacityCount,
        capacityMomentCount: momentCount,
      ),
    );
  }

  static String recordProgressLine(CapacityThreeMomentResult result) {
    if (!result.showOnRecordProgress) return '';
    return CapacityThreeMomentCopy.recordProgressLine(
      result.capacityMomentCount,
      target: result.activationTarget,
    );
  }
}
