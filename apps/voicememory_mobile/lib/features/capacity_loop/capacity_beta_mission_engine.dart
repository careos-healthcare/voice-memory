import '../../models/journal_entry.dart';
import '../demo/sample_archive_mode.dart';
import '../pro_interest/pro_interest_models.dart';
import 'capacity_activation_fit_models.dart';
import 'capacity_activation_fit_store.dart';
import 'capacity_beta_mission_copy.dart';
import 'capacity_beta_mission_models.dart';
import 'capacity_beta_mission_store.dart';
import 'capacity_beta_signal_copy.dart';
import 'capacity_boundary_response_models.dart';
import 'capacity_cost_store.dart';
import 'capacity_decision_outcome_store.dart';
import 'capacity_loop_engine.dart';
import 'capacity_pull_reason_store.dart';
import 'capacity_return_trigger_engine.dart';
import 'capacity_return_trigger_models.dart';
import 'capacity_three_moment_gates.dart';
import 'capacity_weekly_review_engine.dart';

/// Builds capacity beta trial mission from local stores — no journal text.
class CapacityBetaMissionEngine {
  const CapacityBetaMissionEngine({
    this.loopEngine = const CapacityLoopEngine(),
    this.weeklyReviewEngine = const CapacityWeeklyReviewEngine(),
  });

  final CapacityLoopEngine loopEngine;
  final CapacityWeeklyReviewEngine weeklyReviewEngine;

  static const coreTaskCount = CapacityBetaMissionTaskIds.coreTaskCount;

  CapacityBetaMissionResult build(CapacityBetaMissionInput input) {
    if (input.sampleMode || input.missionRecord.isDismissed) {
      return CapacityBetaMissionResult.hidden;
    }

    final hasCapacityContext = _hasCapacityContext(input);
    if (!hasCapacityContext) {
      return CapacityBetaMissionResult.hidden;
    }

    final tasks = _buildTasks(input);
    final completedCore =
        tasks.where((task) => !task.isOptional && task.isDone).length;
    final allCoreDone = completedCore >= coreTaskCount;

    return CapacityBetaMissionResult(
      hasMission: true,
      showOnArchiveHome: (input.capacityWedgeActive) &&
          !allCoreDone &&
          !input.missionRecord.isDismissed,
      title: CapacityBetaMissionCopy.title,
      subtitle: CapacityBetaMissionCopy.subtitle,
      calmNote: CapacityBetaMissionCopy.calmNote,
      skipNote: CapacityBetaMissionCopy.skipNote,
      progressLabel: CapacityBetaMissionCopy.progressLabel(
        completedCore,
        coreTaskCount,
      ),
      completedCoreTaskCount: completedCore,
      coreTaskCount: coreTaskCount,
      tasks: tasks,
      openMissionCta: CapacityBetaMissionCopy.openMissionCta,
      dismissCta: CapacityBetaMissionCopy.dismissCta,
      viewBetaSignalsCta: CapacityBetaMissionCopy.ctaViewBetaSignals,
      betaSignalsRoute: CapacityBetaSignalCopy.route,
    );
  }

  CapacityBetaMissionResult buildFromJournal({
    required List<JournalEntry> entries,
    required bool capacityLoopActive,
    required bool capacityCohortActive,
    CapacityActivationFitRecord? fitRecord,
    CapacityBoundaryResponseSelection? boundarySelection,
    ProInterestState proInterestState = ProInterestState.empty,
    CapacityBetaMissionRecord missionRecord = CapacityBetaMissionRecord.empty,
    bool sampleMode = false,
  }) {
    if (sampleMode) return CapacityBetaMissionResult.hidden;

    final realEntries = SampleArchiveMode.excludeSampleEntries(entries);
    if (entries.isNotEmpty && realEntries.isEmpty) {
      return CapacityBetaMissionResult.hidden;
    }

    final momentCount = loopEngine.eligibleCapacityEntryIds(realEntries).length;
    final pullCount =
        CapacityPullReasonStore.countWithReason(CapacityPullReasonStore.cached);
    final outcomeCount = CapacityDecisionOutcomeStore.countWithOutcome(
      CapacityDecisionOutcomeStore.cached,
    );
    final costCount =
        CapacityCostStore.countWithLaterCost(CapacityCostStore.cached);

    final weeklyReview = weeklyReviewEngine.buildFromJournal(
      entries: entries,
      capacityLoopActive: capacityLoopActive,
      capacityCohortActive: capacityCohortActive,
    );

    final fit = fitRecord ?? CapacityActivationFitStore.cached;
    final fitComplete = fit?.isComplete ?? false;

    return build(
      CapacityBetaMissionInput(
        sampleMode: false,
        capacityWedgeActive: capacityLoopActive || capacityCohortActive,
        capacityMomentCount: momentCount,
        activationTarget: CapacityThreeMomentGates.activationTarget,
        pullReasonRecordCount: pullCount,
        outcomeRecordCount: outcomeCount,
        laterCostRecordCount: costCount,
        weeklyReviewAvailable: weeklyReview.hasReview,
        boundaryResponseSelected: boundarySelection?.hasSelection ?? false,
        activationFitComplete: fitComplete,
        proInterestCaptured: proInterestState.hasCapture,
        missionRecord: missionRecord,
      ),
    );
  }

  static bool _hasCapacityContext(CapacityBetaMissionInput input) {
    if (input.capacityWedgeActive) return true;
    if (input.capacityMomentCount > 0) return true;
    if (input.pullReasonRecordCount > 0) return true;
    if (input.outcomeRecordCount > 0) return true;
    if (input.laterCostRecordCount > 0) return true;
    if (input.activationFitComplete) return true;
    if (input.boundaryResponseSelected) return true;
    if (input.proInterestCaptured) return true;
    return input.missionRecord.startedAt != null;
  }

  List<CapacityBetaMissionTask> _buildTasks(CapacityBetaMissionInput input) {
    final count = input.capacityMomentCount;
    final target = input.activationTarget;

    return [
      _task(
        id: CapacityBetaMissionTaskIds.firstYesMoment,
        done: count >= 1,
        ready: true,
        route: '/record',
        cta: CapacityBetaMissionCopy.ctaSaveYesMoment,
      ),
      _task(
        id: CapacityBetaMissionTaskIds.threeYesMoments,
        done: count >= target,
        ready: count >= 1,
        route: '/record',
        cta: CapacityBetaMissionCopy.ctaSaveYesMoment,
        hint: _threeYesMomentsHint(count, target, input),
      ),
      _task(
        id: CapacityBetaMissionTaskIds.pullReason,
        done: input.pullReasonRecordCount >= 1,
        ready: count >= 1,
        route: '/capacity-loop',
        cta: CapacityBetaMissionCopy.ctaMarkPullReason,
      ),
      _task(
        id: CapacityBetaMissionTaskIds.decisionOutcome,
        done: input.outcomeRecordCount >= 1,
        ready: input.pullReasonRecordCount >= 1,
        route: '/capacity-loop',
        cta: CapacityBetaMissionCopy.ctaMarkOutcome,
      ),
      _task(
        id: CapacityBetaMissionTaskIds.laterCost,
        done: input.laterCostRecordCount >= 1,
        ready: input.outcomeRecordCount >= 1,
        route: '/capacity-loop',
        cta: CapacityBetaMissionCopy.ctaRecordCost,
      ),
      _task(
        id: CapacityBetaMissionTaskIds.reviewLoop,
        done: count >= target,
        ready: count >= target,
        route: '/capacity-loop',
        cta: CapacityBetaMissionCopy.ctaReviewLoop,
      ),
      _task(
        id: CapacityBetaMissionTaskIds.activationFit,
        done: input.activationFitComplete,
        ready: count >= target,
        route: '/capacity-loop',
        cta: CapacityBetaMissionCopy.ctaAnswerFit,
      ),
      _task(
        id: CapacityBetaMissionTaskIds.weeklyReview,
        done: input.weeklyReviewAvailable,
        ready: count >= target,
        route: '/capacity-weekly-review',
        cta: CapacityBetaMissionCopy.ctaReviewWeek,
      ),
      _task(
        id: CapacityBetaMissionTaskIds.boundaryResponse,
        done: input.boundaryResponseSelected,
        ready: count >= target,
        route: '/capacity-boundary-response',
        cta: CapacityBetaMissionCopy.ctaChooseResponse,
      ),
      _task(
        id: CapacityBetaMissionTaskIds.proInterest,
        done: input.proInterestCaptured,
        ready: count >= 1,
        route: '/pro-interest',
        cta: CapacityBetaMissionCopy.ctaProInterest,
        isOptional: true,
      ),
    ];
  }

  CapacityBetaMissionTask _task({
    required String id,
    required bool done,
    required bool ready,
    required String route,
    required String cta,
    bool isOptional = false,
    String hint = '',
  }) {
    final status = done
        ? CapacityBetaMissionTaskStatus.done
        : isOptional
            ? CapacityBetaMissionTaskStatus.optional
            : ready
                ? CapacityBetaMissionTaskStatus.ready
                : CapacityBetaMissionTaskStatus.notStarted;

    final statusLabel = switch (status) {
      CapacityBetaMissionTaskStatus.done => CapacityBetaMissionCopy.statusDone,
      CapacityBetaMissionTaskStatus.ready => CapacityBetaMissionCopy.statusReady,
      CapacityBetaMissionTaskStatus.optional =>
        CapacityBetaMissionCopy.statusOptional,
      CapacityBetaMissionTaskStatus.notStarted =>
        CapacityBetaMissionCopy.statusNotStarted,
    };

    return CapacityBetaMissionTask(
      id: id,
      label: CapacityBetaMissionCopy.labelForTask(id),
      status: status,
      statusLabel: statusLabel,
      route: route,
      ctaLabel: cta,
      isOptional: isOptional,
      hintLabel: hint,
    );
  }

  String _threeYesMomentsHint(
    int count,
    int target,
    CapacityBetaMissionInput input,
  ) {
    if (!input.capacityWedgeActive) return '';
    final hint = const CapacityReturnTriggerEngine().build(
      CapacityReturnTriggerInput(
        sampleMode: input.sampleMode,
        screenshotMode: false,
        capacityWedgeActive: input.capacityWedgeActive,
        capacityMomentCount: count,
        surface: CapacityReturnTriggerSurface.betaMissionHint,
      ),
    );
    return CapacityReturnTriggerEngine.betaMissionHint(hint);
  }

  static bool shouldMarkCompleted(CapacityBetaMissionResult result) =>
      result.hasMission &&
      result.completedCoreTaskCount >= result.coreTaskCount;
}
