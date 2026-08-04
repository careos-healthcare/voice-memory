import '../beta_feedback/beta_feedback_engine.dart';
import '../../models/journal_entry.dart';
import '../demo/sample_archive_mode.dart';
import 'capacity_cost_models.dart';
import 'capacity_decision_outcome_models.dart';
import 'capacity_cost_store.dart';
import 'capacity_decision_outcome_store.dart';
import 'capacity_pull_reason_copy.dart';
import 'capacity_pull_reason_models.dart';
import 'capacity_pull_reason_store.dart';
import 'capacity_boundary_response_copy.dart';
import 'capacity_boundary_response_models.dart';
import 'capacity_boundary_response_store.dart';
import 'capacity_loop_engine.dart';
import 'capacity_weekly_review_gates.dart';

/// Builds capacity boundary response surfaces from local evidence — no journal text.
class CapacityBoundaryResponseEngine {
  const CapacityBoundaryResponseEngine({
    this.loopEngine = const CapacityLoopEngine(),
  });

  final CapacityLoopEngine loopEngine;

  static const minCapacityEvidenceForGeneric = 2;

  static bool shouldBuildFeature(CapacityBoundaryResponseGateInput input) {
    if (input.sampleMode) return false;
    if (input.realSavedMomentCount <= 0) return false;
    if (!_hasWedgeOrEvidence(input)) return false;
    return input.capacityMomentCount >=
            CapacityWeeklyReviewGates.minCapacityMoments ||
        input.outcomeOrCostRecordCount >=
            CapacityWeeklyReviewGates.minOutcomeOrCostRecords;
  }

  static bool showOnArchiveHome({
    required bool hasFeature,
    required bool sampleMode,
    required bool pendingPullReason,
    required bool pendingDecisionOutcome,
    required bool pendingCostCheckin,
    required bool beforeYesPauseOnHome,
    required bool weeklyReviewOnHome,
  }) =>
      hasFeature &&
      !sampleMode &&
      !pendingPullReason &&
      !pendingDecisionOutcome &&
      !pendingCostCheckin &&
      !beforeYesPauseOnHome &&
      !weeklyReviewOnHome;

  static bool showOnCapacityLoop({
    required bool hasFeature,
    required bool sampleMode,
  }) => hasFeature && !sampleMode;

  static bool showOnWeeklyReview({
    required bool hasFeature,
    required bool sampleMode,
  }) => hasFeature && !sampleMode;

  static bool showOnRecord({
    required bool hasFeature,
    required bool sampleMode,
    required bool capacityWedgeActive,
    required bool hasSelection,
  }) => hasFeature && !sampleMode && capacityWedgeActive && hasSelection;

  CapacityBoundaryResponseResult build(CapacityBoundaryResponseInput input) {
    if (input.sampleMode) return CapacityBoundaryResponseResult.hidden;

    final gateInput = CapacityBoundaryResponseGateInput(
      sampleMode: false,
      realSavedMomentCount: input.realSavedMomentCount,
      capacityEvidenceCount: input.capacityEvidenceCount,
      capacityWedgeActive: input.capacityWedgeActive,
      capacityMomentCount: input.capacityMomentCount,
      outcomeOrCostRecordCount: input.outcomeOrCostRecordCount,
    );

    if (!shouldBuildFeature(gateInput)) {
      return CapacityBoundaryResponseResult.hidden;
    }

    final selection = input.selection;
    final selectedId = selection != null && selection.hasSelection
        ? selection.responseId
        : '';
    final selectedText =
        CapacityBoundaryResponseCopy.textForId(selectedId) ?? '';
    final cardSummary = selectedText.isNotEmpty
        ? selectedText
        : CapacityBoundaryResponseCopy.body;

    final showOnArchiveHome = CapacityBoundaryResponseEngine.showOnArchiveHome(
      hasFeature: true,
      sampleMode: false,
      pendingPullReason: input.pendingPullReasonOnHome,
      pendingDecisionOutcome: input.pendingDecisionOutcome,
      pendingCostCheckin: input.pendingCostCheckin,
      beforeYesPauseOnHome: input.beforeYesPauseOnHome,
      weeklyReviewOnHome: input.weeklyReviewOnHome,
    );
    final showOnCapacityLoopFlag =
        CapacityBoundaryResponseEngine.showOnCapacityLoop(
          hasFeature: true,
          sampleMode: false,
        );
    final showOnWeeklyReviewFlag =
        CapacityBoundaryResponseEngine.showOnWeeklyReview(
          hasFeature: true,
          sampleMode: false,
        );
    final showOnRecordFlag = CapacityBoundaryResponseEngine.showOnRecord(
      hasFeature: true,
      sampleMode: false,
      capacityWedgeActive: input.capacityWedgeActive,
      hasSelection: selectedText.isNotEmpty,
    );

    final recommendedNote =
        input.mostCommonPullReasonId == CapacityPullReasonIds.soundedUrgent
        ? CapacityPullReasonCopy.boundaryUrgentFitNote
        : '';

    return CapacityBoundaryResponseResult(
      hasFeature: true,
      showOnArchiveHome: showOnArchiveHome,
      showOnCapacityLoop: showOnCapacityLoopFlag,
      showOnWeeklyReview: showOnWeeklyReviewFlag,
      showOnRecord: showOnRecordFlag,
      title: CapacityBoundaryResponseCopy.title,
      subtitle: CapacityBoundaryResponseCopy.subtitle,
      body: CapacityBoundaryResponseCopy.body,
      selectedResponseId: selectedId,
      selectedResponseText: selectedText,
      templates: CapacityBoundaryResponseCopy.templates,
      primaryCtaLabel: CapacityBoundaryResponseCopy.chooseResponseCta,
      secondaryCtaLabel: CapacityBoundaryResponseCopy.useNextTimeCta,
      primaryRoute: CapacityBoundaryResponseCopy.route,
      cardSummary: cardSummary,
      recommendedResponseNote: recommendedNote,
    );
  }

  CapacityBoundaryResponseResult buildFromJournal({
    required List<JournalEntry> entries,
    required bool capacityLoopActive,
    required bool capacityCohortActive,
    bool sampleMode = false,
    List<CapacityDecisionOutcomeRecord>? outcomeRecords,
    List<CapacityCostRecord>? costRecords,
    CapacityBoundaryResponseSelection? selection,
    bool pendingDecisionOutcome = false,
    bool pendingCostCheckin = false,
    bool beforeYesPauseOnHome = false,
    bool weeklyReviewOnHome = false,
    bool pendingPullReasonOnHome = false,
    List<CapacityPullReasonRecord>? pullReasonRecords,
  }) {
    if (sampleMode) return CapacityBoundaryResponseResult.hidden;

    final realEntries = SampleArchiveMode.excludeSampleEntries(entries);
    final realSavedCount = BetaFeedbackEngine.realEntryCountFor(realEntries);
    final capacityMomentCount = loopEngine
        .eligibleCapacityEntryIds(realEntries)
        .length;
    final capacityEvidenceCount = loopEngine.countCapacityEvidence(realEntries);
    final outcomes = outcomeRecords ?? CapacityDecisionOutcomeStore.cached;
    final costs = costRecords ?? CapacityCostStore.cached;
    final outcomeOrCostCount =
        CapacityDecisionOutcomeStore.countWithOutcome(outcomes) +
        CapacityCostStore.countWithLaterCost(costs);
    final storedSelection = selection ?? CapacityBoundaryResponseStore.cached;

    final pullReasons = pullReasonRecords ?? CapacityPullReasonStore.cached;
    final mostCommonPull = CapacityPullReasonStore.mostCommonReasonId(
      pullReasons,
    );

    return build(
      CapacityBoundaryResponseInput(
        sampleMode: false,
        realSavedMomentCount: realSavedCount,
        capacityWedgeActive: capacityLoopActive || capacityCohortActive,
        capacityMomentCount: capacityMomentCount,
        capacityEvidenceCount: capacityEvidenceCount,
        outcomeOrCostRecordCount: outcomeOrCostCount,
        pendingDecisionOutcome: pendingDecisionOutcome,
        pendingCostCheckin: pendingCostCheckin,
        beforeYesPauseOnHome: beforeYesPauseOnHome,
        weeklyReviewOnHome: weeklyReviewOnHome,
        pendingPullReasonOnHome: pendingPullReasonOnHome,
        mostCommonPullReasonId: mostCommonPull,
        selection: storedSelection,
      ),
    );
  }

  static bool _hasWedgeOrEvidence(CapacityBoundaryResponseGateInput input) {
    if (input.capacityWedgeActive) return true;
    return input.capacityEvidenceCount >= minCapacityEvidenceForGeneric;
  }
}
