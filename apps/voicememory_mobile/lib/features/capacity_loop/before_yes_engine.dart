import '../../models/journal_entry.dart';
import '../demo/sample_archive_mode.dart';
import 'capacity_launch_wedge_gates.dart';
import 'capacity_cost_models.dart';
import 'capacity_cost_store.dart';
import 'capacity_loop_engine.dart';
import 'capacity_loop_gates.dart';
import 'before_yes_copy.dart';

/// Visibility for the before-you-say-yes pause — local metadata only.
class BeforeYesPauseResult {
  const BeforeYesPauseResult({
    required this.showOnRecord,
    required this.showOnArchiveHome,
    required this.showOnCapacityLoop,
    required this.title,
    required this.body,
    required this.pauseCtaLabel,
    required this.alreadyYesCtaLabel,
    required this.recordPrompt,
    required this.loopSectionTitle,
    required this.loopSectionBody,
  });

  const BeforeYesPauseResult.hidden()
    : showOnRecord = false,
      showOnArchiveHome = false,
      showOnCapacityLoop = false,
      title = BeforeYesCopy.title,
      body = BeforeYesCopy.body,
      pauseCtaLabel = BeforeYesCopy.pauseCta,
      alreadyYesCtaLabel = BeforeYesCopy.alreadyYesCta,
      recordPrompt = BeforeYesCopy.recordPrompt,
      loopSectionTitle = BeforeYesCopy.loopSectionTitle,
      loopSectionBody = BeforeYesCopy.loopSectionBody;

  final bool showOnRecord;
  final bool showOnArchiveHome;
  final bool showOnCapacityLoop;
  final String title;
  final String body;
  final String pauseCtaLabel;
  final String alreadyYesCtaLabel;
  final String recordPrompt;
  final String loopSectionTitle;
  final String loopSectionBody;
}

class BeforeYesPauseInput {
  const BeforeYesPauseInput({
    required this.capacityWedgeActive,
    required this.sampleMode,
    required this.realSavedMomentCount,
    required this.capacityEvidenceCount,
    required this.capacityLoopHasCard,
    required this.costLaterCheckinVisible,
    required this.recordedCostCount,
    this.capacityMomentCount = 0,
  });

  final bool capacityWedgeActive;
  final bool sampleMode;
  final int realSavedMomentCount;
  final int capacityEvidenceCount;
  final bool capacityLoopHasCard;
  final bool costLaterCheckinVisible;
  final int recordedCostCount;
  final int capacityMomentCount;
}

/// Builds before-you-say-yes visibility — capacity wedge only.
class BeforeYesPauseEngine {
  const BeforeYesPauseEngine({this.loopEngine = const CapacityLoopEngine()});

  final CapacityLoopEngine loopEngine;

  BeforeYesPauseResult build(BeforeYesPauseInput input) {
    if (input.sampleMode || !input.capacityWedgeActive) {
      return const BeforeYesPauseResult.hidden();
    }

    final hasLoopOrCostEvidence = _hasLoopOrCostEvidence(input);

    return BeforeYesPauseResult(
      showOnRecord: true,
      showOnArchiveHome:
          hasLoopOrCostEvidence &&
          !input.costLaterCheckinVisible &&
          CapacityLaunchWedgeGates.showAdvancedSurfaceOnArchiveHome(
            capacityWedgeActive: input.capacityWedgeActive,
            capacityMomentCount: input.capacityMomentCount,
          ),
      showOnCapacityLoop: hasLoopOrCostEvidence,
      title: BeforeYesCopy.title,
      body: BeforeYesCopy.body,
      pauseCtaLabel: BeforeYesCopy.pauseCta,
      alreadyYesCtaLabel: BeforeYesCopy.alreadyYesCta,
      recordPrompt: BeforeYesCopy.recordPrompt,
      loopSectionTitle: BeforeYesCopy.loopSectionTitle,
      loopSectionBody: BeforeYesCopy.loopSectionBody,
    );
  }

  BeforeYesPauseResult buildFromJournal({
    required List<JournalEntry> entries,
    required bool capacityLoopActive,
    required bool capacityCohortActive,
    required bool capacityLoopHasCard,
    required bool costLaterCheckinVisible,
    List<CapacityCostRecord>? costRecords,
    bool sampleMode = false,
  }) {
    final realEntries = SampleArchiveMode.excludeSampleEntries(entries);
    final realCount = loopEngine.realSavedMomentCount(realEntries);
    final capacityCount = loopEngine.countCapacityEvidence(realEntries);
    final momentCount = loopEngine.eligibleCapacityEntryIds(realEntries).length;
    final recordedCostCount = CapacityCostStore.countWithLaterCost(
      costRecords ?? const [],
    );

    return build(
      BeforeYesPauseInput(
        capacityWedgeActive: capacityLoopActive || capacityCohortActive,
        sampleMode: sampleMode,
        realSavedMomentCount: realCount,
        capacityEvidenceCount: capacityCount,
        capacityLoopHasCard: capacityLoopHasCard,
        costLaterCheckinVisible: costLaterCheckinVisible,
        recordedCostCount: recordedCostCount,
        capacityMomentCount: momentCount,
      ),
    );
  }

  bool _hasLoopOrCostEvidence(BeforeYesPauseInput input) {
    if (input.capacityLoopHasCard) return true;
    if (input.recordedCostCount > 0) return true;
    return input.capacityEvidenceCount >=
        CapacityLoopGates.minRealMomentsForWedgeHint;
  }
}
