import 'package:archiveme_mobile/features/beta_feedback/beta_feedback_engine.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_cost_models.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_cost_store.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_decision_outcome_models.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_decision_outcome_store.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_loop_engine.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_loop_gates.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_pull_reason_engine.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_pull_reason_models.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_pull_reason_store.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_weekly_review_copy.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_weekly_review_gates.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_weekly_review_models.dart';
import 'package:archiveme_mobile/features/demo/sample_archive_mode.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Builds capacity weekly review from local loop evidence — no journal text.
class CapacityWeeklyReviewEngine {
  const CapacityWeeklyReviewEngine({
    this.loopEngine = const CapacityLoopEngine(),
  });

  final CapacityLoopEngine loopEngine;

  CapacityWeeklyReviewResult build(CapacityWeeklyReviewInput input) {
    if (input.sampleMode) {
      return CapacityWeeklyReviewResult.hidden;
    }

    final gateInput = CapacityWeeklyReviewGateInput(
      sampleMode: false,
      realSavedMomentCount: input.realSavedMomentCount,
      capacityEvidenceCount: input.capacityEvidenceCount,
      capacityWedgeActive: input.capacityWedgeActive,
      capacityMomentCount: input.capacityMomentCount,
      outcomeOrCostRecordCount:
          input.outcomeRecordedCount + input.laterCostRecordedCount,
    );

    if (!CapacityWeeklyReviewGates.shouldBuildReview(gateInput)) {
      return CapacityWeeklyReviewResult.hidden;
    }

    final momentCount = input.capacityMomentCount > 0
        ? input.capacityMomentCount
        : input.capacityEvidenceCount;
    final whatRepeated =
        input.capacityEvidenceCount >=
            CapacityLoopGates.minRealMomentsForFullCard
        ? CapacityWeeklyReviewCopy.whatRepeatedStrong
        : CapacityWeeklyReviewCopy.whatRepeatedForming;
    final whatChanged = _whatChanged(input);
    final laterCostSection = input.laterCostRecordedCount > 0
        ? CapacityWeeklyReviewCopy.laterCostRecordedLine(
            input.laterCostRecordedCount,
          )
        : CapacityWeeklyReviewCopy.laterCostForming;

    final showOnArchiveHome = CapacityWeeklyReviewGates.showOnArchiveHome(
      hasReview: true,
      sampleMode: false,
      pendingPullReason: input.pendingPullReasonOnHome,
      pendingDecisionOutcome: input.pendingDecisionOutcome,
      pendingCostCheckin: input.pendingCostCheckin,
      beforeYesPauseOnHome: input.beforeYesPauseOnHome,
    );
    final showOnCapacityLoop = CapacityWeeklyReviewGates.showOnCapacityLoop(
      hasReview: true,
      sampleMode: false,
    );

    return CapacityWeeklyReviewResult(
      hasReview: true,
      showOnArchiveHome: showOnArchiveHome,
      showOnCapacityLoop: showOnCapacityLoop,
      title: CapacityWeeklyReviewCopy.title,
      subtitle: CapacityWeeklyReviewCopy.subtitle,
      evidenceCountLabel: CapacityWeeklyReviewCopy.evidenceCountLabel(
        momentCount,
      ),
      outcomeLine: input.outcomeRecordedCount > 0
          ? CapacityWeeklyReviewCopy.outcomesMarkedLine(
              input.outcomeRecordedCount,
            )
          : '',
      laterCostLine: input.laterCostRecordedCount > 0
          ? CapacityWeeklyReviewCopy.laterCostRecordedLine(
              input.laterCostRecordedCount,
            )
          : '',
      whatRepeated: whatRepeated,
      whatChanged: whatChanged,
      laterCostSection: laterCostSection,
      whatPulledYouIn: input.pullReasonSummary,
      watchNext: CapacityWeeklyReviewCopy.watchNextBody,
      primaryCtaLabel: CapacityWeeklyReviewCopy.reviewThisWeekCta,
      secondaryCtaLabel: CapacityWeeklyReviewCopy.saveNextYesMomentCta,
      primaryRoute: CapacityWeeklyReviewCopy.route,
      secondaryRoute: CapacityWeeklyReviewCopy.recordRoute,
      cardSummary: whatChanged,
    );
  }

  CapacityWeeklyReviewResult buildFromJournal({
    required List<JournalEntry> entries,
    required bool capacityLoopActive,
    required bool capacityCohortActive,
    bool sampleMode = false,
    List<CapacityCostRecord>? costRecords,
    List<CapacityDecisionOutcomeRecord>? outcomeRecords,
    bool pendingDecisionOutcome = false,
    bool pendingCostCheckin = false,
    bool beforeYesPauseOnHome = false,
    bool pendingPullReasonOnHome = false,
    List<CapacityPullReasonRecord>? pullReasonRecords,
  }) {
    if (sampleMode) return CapacityWeeklyReviewResult.hidden;

    final realEntries = SampleArchiveMode.excludeSampleEntries(entries);
    final realSavedCount = BetaFeedbackEngine.realEntryCountFor(realEntries);
    final capacityMomentCount = loopEngine
        .eligibleCapacityEntryIds(realEntries)
        .length;
    final capacityEvidenceCount = loopEngine.countCapacityEvidence(realEntries);
    final outcomes = outcomeRecords ?? CapacityDecisionOutcomeStore.cached;
    final costs = costRecords ?? CapacityCostStore.cached;
    final outcomeCount = CapacityDecisionOutcomeStore.countWithOutcome(
      outcomes,
    );
    final costCount = CapacityCostStore.countWithLaterCost(costs);
    final answeredOutcomes = outcomes
        .where((record) => record.hasOutcome)
        .toList();
    final hasPatternChange = CapacityDecisionOutcomeStore.hasAnyPatternChange(
      outcomes,
    );
    final allYes =
        answeredOutcomes.isNotEmpty &&
        answeredOutcomes.every(
          (record) => record.outcomeId == CapacityDecisionOutcomeIds.saidYes,
        );

    final pullReasons = pullReasonRecords ?? CapacityPullReasonStore.cached;

    return build(
      CapacityWeeklyReviewInput(
        sampleMode: false,
        realSavedMomentCount: realSavedCount,
        capacityWedgeActive: capacityLoopActive || capacityCohortActive,
        capacityMomentCount: capacityMomentCount,
        capacityEvidenceCount: capacityEvidenceCount,
        outcomeRecordedCount: outcomeCount,
        laterCostRecordedCount: costCount,
        hasPatternChangeOutcomes: hasPatternChange,
        allAnsweredOutcomesAreYes: allYes,
        hasAnsweredOutcomes: answeredOutcomes.isNotEmpty,
        pendingDecisionOutcome: pendingDecisionOutcome,
        pendingCostCheckin: pendingCostCheckin,
        beforeYesPauseOnHome: beforeYesPauseOnHome,
        pendingPullReasonOnHome: pendingPullReasonOnHome,
        pullReasonSummary: CapacityPullReasonEngine.weeklyPullSummary(
          pullReasons,
        ),
      ),
    );
  }

  String _whatChanged(CapacityWeeklyReviewInput input) {
    if (input.hasPatternChangeOutcomes) {
      return CapacityWeeklyReviewCopy.patternMayHaveChanged;
    }
    if (input.hasAnsweredOutcomes && input.allAnsweredOutcomesAreYes) {
      return CapacityWeeklyReviewCopy.patternMostlyRepeating;
    }
    return CapacityWeeklyReviewCopy.patternForming;
  }
}