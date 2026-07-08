import '../../billing/paywall_attribution_event.dart';
import '../../billing/paywall_attribution_store.dart';
import '../../services/app_services.dart';
import '../beta_activation/beta_activation_summary_tracker.dart';
import '../beta_proof_feedback/beta_proof_feedback_model.dart';
import '../beta_proof_feedback/beta_proof_feedback_store.dart';
import '../revenue_metrics/revenue_funnel_analytics.dart';
import '../revenue_metrics/revenue_funnel_event.dart';
import '../beta_decision_rules/beta_decision_rule_engine.dart';
import '../first_session_proof_repair/first_session_proof_repair_engine.dart';
import '../first_session_lift/first_session_lift_engine.dart';
import '../pro_understanding_lift/pro_understanding_lift_engine.dart';
import '../proof_floor_rescue/proof_floor_rescue_engine.dart';
import '../revenue_lift_experiment_v2/revenue_lift_experiment_v2_engine.dart';
import '../revenue_lift_experiment_v2/revenue_lift_experiment_v2_model.dart';
import 'revenue_readiness_dashboard_v2_copy.dart';
import 'revenue_readiness_dashboard_v2_model.dart';

/// Builds the unified revenue readiness dashboard from local metadata only.
abstract final class RevenueReadinessDashboardV2Engine {
  RevenueReadinessDashboardV2Engine._();

  static const firstSaveTarget = 0.50;
  static const secondSaveTarget = 0.30;
  static const thirdSaveTarget = 0.20;
  static const usefulFeedbackTarget = 0.25;
  static const returnAfterProofTarget = 0.25;
  static const paywallSeenAfterProofTarget = 0.35;
  static const purchaseCtaTarget = 0.05;
  static const firstSessionCaptureTarget = 0.30;
  static const proUnderstandingTarget = 0.20;

  static bool shouldShow({required bool betaMissionEnabled}) =>
      betaMissionEnabled;

  static Future<RevenueReadinessDashboardV2Dashboard> build() async {
    final input = await loadInput();
    return buildFromInput(input);
  }

  static Future<RevenueReadinessDashboardV2Input> loadInput() async {
    await BetaProofFeedbackStore.ensureLoaded();
    final loaded = await BetaActivationSummaryTracker.loadAll();
    final feedbackCounts = _feedbackCountsByType();
    final funnelEvents = RevenueFunnelAnalytics.recordedEvents;

    var purchaseStarted = 0;
    var purchaseCompleted = 0;
    var restoreAttempted = 0;
    var restoreCompleted = 0;

    if (AppServices.isInitialized) {
      final attribution = PaywallAttributionStore.instance();
      final events = await attribution.events();
      purchaseStarted = events
          .where((event) => event.type == PaywallAttributionEventType.purchaseStarted)
          .length;
      purchaseCompleted = events
          .where(
            (event) => event.type == PaywallAttributionEventType.purchaseCompleted,
          )
          .length;
      restoreAttempted = events
          .where((event) => event.type == PaywallAttributionEventType.restoreStarted)
          .length;
      restoreCompleted = events
          .where(
            (event) => event.type == PaywallAttributionEventType.restoreCompleted,
          )
          .length;
    }

    final sessionPaywallSeen = _countFunnelEvent(
      funnelEvents,
      RevenueFunnelEvent.paywallSeen,
    );
    final sessionPaywallCta = _countFunnelEvent(
      funnelEvents,
      RevenueFunnelEvent.paywallPurchaseCtaTapped,
    );
    final sessionRestoreTapped = _countFunnelEvent(
      funnelEvents,
      RevenueFunnelEvent.paywallRestoreTapped,
    );
    final sessionProBridgeSeen = _countProBridgeSeen(funnelEvents);
    final sessionProBridgeCta = _countProBridgeCta(funnelEvents);

    final loop = loaded.loop;
    final confirmedRepeatSeen = loop.confirmedRepeatSeen > 0
        ? loop.confirmedRepeatSeen
        : loaded.extension.firstProofReached;

    return RevenueReadinessDashboardV2Input(
      recordScreenSeen: loop.recordScreenSeen,
      firstMomentSaved: loop.firstMomentSaved,
      secondMomentSaved: loop.secondMomentSaved,
      thirdMomentSaved: loop.thirdMomentSaved,
      confirmedRepeatSeen: confirmedRepeatSeen,
      timelineProofSeen: _timelineProofSeenCount(confirmedRepeatSeen),
      usefulCount: feedbackCounts[BetaProofFeedbackType.useful] ?? 0,
      tooVagueCount: feedbackCounts[BetaProofFeedbackType.tooVague] ?? 0,
      alreadyKnewCount: feedbackCounts[BetaProofFeedbackType.alreadyKnew] ?? 0,
      notRelevantCount: feedbackCounts[BetaProofFeedbackType.notRelevant] ?? 0,
      returnedAfterFirstProof: loop.returnedAfterFirstProof,
      returnPromptSeen: _max(
        loop.oneEntryReturnScreenSeen,
        loop.returnCheckAnswered,
      ),
      returnPromptTapped: loop.returnCheckAnswered,
      proBridgeSeen: _max(loop.proBoundarySeen, sessionProBridgeSeen),
      proBridgeCtaTapped: sessionProBridgeCta,
      paywallSeen: _max(loop.paywallSeen, sessionPaywallSeen),
      paywallCtaTapped: _max(loop.purchaseTapped, sessionPaywallCta),
      purchaseStarted: purchaseStarted,
      purchaseCompleted: purchaseCompleted,
      restoreAttempted: _max(loop.restoreTapped, restoreAttempted + sessionRestoreTapped),
      restoreCompleted: restoreCompleted,
      firstSaveInFirstSession: loop.firstMomentSaved > 0 && loop.appOpened > 0
          ? loop.firstMomentSaved.clamp(0, 1)
          : 0,
      firstSessionOpportunities: loop.appOpened > 0 ? loop.appOpened : loop.recordScreenSeen,
      understandsProYesMaybe: 0,
      understandsProSurveyResponses: 0,
      testerCount: loaded.extension.betaFeedbackSubmitted > 0
          ? loaded.extension.betaFeedbackSubmitted
          : loop.appOpened,
      firstSessionSaveCount: loop.firstMomentSaved > 0 && loop.appOpened <= 1
          ? 1
          : 0,
      sawProCount: _max(
        loop.paywallSeen,
        _max(loop.proBoundarySeen, sessionPaywallSeen),
      ),
    );
  }

  static RevenueReadinessDashboardV2Dashboard buildFromInput(
    RevenueReadinessDashboardV2Input input,
  ) {
    final diagnoses = _buildDiagnoses(input);
    final diagnosisActions = {
      for (final diagnosis in diagnoses) diagnosis.id: diagnosis.nextActionLabel,
    };

    return RevenueReadinessDashboardV2Dashboard(
      title: RevenueReadinessDashboardV2Copy.title,
      subtitle: RevenueReadinessDashboardV2Copy.subtitle,
      liftFocus: RevenueLiftExperimentV2Engine.resolveLiftFocus(input),
      repairFocus: FirstSessionProofRepairEngine.resolveRepairFocus(input),
      proofFloorRescueFocus: ProofFloorRescueEngine.resolveRepairFocus(input),
      sections: [
        _captureSection(input, diagnosisActions),
        _proofSection(input, diagnosisActions),
        _returnSection(input, diagnosisActions),
        _revenueSection(input, diagnosisActions),
      ],
      diagnoses: diagnoses,
      decisionRule: BetaDecisionRuleEngine.fromRevenueInput(input),
    );
  }

  static RevenueReadinessDashboardV2Section _captureSection(
    RevenueReadinessDashboardV2Input input,
    Map<RevenueReadinessDashboardV2DiagnosisId, String> diagnosisActions,
  ) {
    final firstSaveRate =
        _rate(input.firstMomentSaved, input.recordScreenSeen);
    final secondSaveRate =
        _rate(input.secondMomentSaved, input.firstMomentSaved);
    final thirdSaveRate =
        _rate(input.thirdMomentSaved, input.secondMomentSaved);

    return RevenueReadinessDashboardV2Section(
      id: RevenueReadinessDashboardV2SectionId.capture,
      title: RevenueReadinessDashboardV2Copy.sectionCapture,
      rows: [
        _countRow(
          id: RevenueReadinessDashboardV2MetricId.firstSave,
          label: RevenueReadinessDashboardV2Copy.firstSave,
          count: input.firstMomentSaved,
          status: _rateStatus(
            rate: firstSaveRate,
            target: firstSaveTarget,
            hasDenominator: input.recordScreenSeen > 0,
            hasNumerator: input.firstMomentSaved > 0,
          ),
          nextActionLabel: diagnosisActions[
            RevenueReadinessDashboardV2DiagnosisId.lowFirstSave],
        ),
        _countRow(
          id: RevenueReadinessDashboardV2MetricId.secondSave,
          label: RevenueReadinessDashboardV2Copy.secondSave,
          count: input.secondMomentSaved,
          status: _rateStatus(
            rate: secondSaveRate,
            target: secondSaveTarget,
            hasDenominator: input.firstMomentSaved > 0,
            hasNumerator: input.secondMomentSaved > 0,
          ),
          nextActionLabel: diagnosisActions[
            RevenueReadinessDashboardV2DiagnosisId.lowSecondSave],
        ),
        _countRow(
          id: RevenueReadinessDashboardV2MetricId.thirdSave,
          label: RevenueReadinessDashboardV2Copy.thirdSave,
          count: input.thirdMomentSaved,
          status: _rateStatus(
            rate: thirdSaveRate,
            target: thirdSaveTarget,
            hasDenominator: input.secondMomentSaved > 0,
            hasNumerator: input.thirdMomentSaved > 0,
          ),
          nextActionLabel: diagnosisActions[
            RevenueReadinessDashboardV2DiagnosisId.lowThirdSave],
        ),
      ],
    );
  }

  static RevenueReadinessDashboardV2Section _proofSection(
    RevenueReadinessDashboardV2Input input,
    Map<RevenueReadinessDashboardV2DiagnosisId, String> diagnosisActions,
  ) {
    final usefulRate = _rate(input.usefulCount, input.totalFeedbackCount);
    final negativeRate =
        _rate(input.negativeFeedbackCount, input.totalFeedbackCount);

    return RevenueReadinessDashboardV2Section(
      id: RevenueReadinessDashboardV2SectionId.proof,
      title: RevenueReadinessDashboardV2Copy.sectionProof,
      rows: [
        _countRow(
          id: RevenueReadinessDashboardV2MetricId.timelineProofSeen,
          label: RevenueReadinessDashboardV2Copy.timelineProofSeen,
          count: input.timelineProofSeen,
          status: input.timelineProofSeen > 0
              ? RevenueReadinessDashboardV2Status.healthy
              : RevenueReadinessDashboardV2Status.noData,
        ),
        _countRow(
          id: RevenueReadinessDashboardV2MetricId.useful,
          label: RevenueReadinessDashboardV2Copy.useful,
          count: input.usefulCount,
          status: input.totalFeedbackCount == 0
              ? RevenueReadinessDashboardV2Status.noData
              : usefulRate >= usefulFeedbackTarget
                  ? RevenueReadinessDashboardV2Status.healthy
                  : RevenueReadinessDashboardV2Status.failing,
          valueOverride: input.totalFeedbackCount == 0
              ? null
              : '${input.usefulCount} (${_formatRate(usefulRate)})',
          nextActionLabel: diagnosisActions[
            RevenueReadinessDashboardV2DiagnosisId.lowUsefulProof],
        ),
        _countRow(
          id: RevenueReadinessDashboardV2MetricId.tooVague,
          label: RevenueReadinessDashboardV2Copy.tooVague,
          count: input.tooVagueCount,
          status: input.totalFeedbackCount == 0
              ? RevenueReadinessDashboardV2Status.noData
              : RevenueReadinessDashboardV2Status.watch,
        ),
        _countRow(
          id: RevenueReadinessDashboardV2MetricId.alreadyKnew,
          label: RevenueReadinessDashboardV2Copy.alreadyKnew,
          count: input.alreadyKnewCount,
          status: input.totalFeedbackCount == 0
              ? RevenueReadinessDashboardV2Status.noData
              : RevenueReadinessDashboardV2Status.watch,
        ),
        _countRow(
          id: RevenueReadinessDashboardV2MetricId.notRelevant,
          label: RevenueReadinessDashboardV2Copy.notRelevant,
          count: input.notRelevantCount,
          status: input.totalFeedbackCount == 0
              ? RevenueReadinessDashboardV2Status.noData
              : RevenueReadinessDashboardV2Status.watch,
        ),
        _countRow(
          id: RevenueReadinessDashboardV2MetricId.negativeCombined,
          label: RevenueReadinessDashboardV2Copy.negativeCombined,
          count: input.negativeFeedbackCount,
          status: input.totalFeedbackCount == 0
              ? RevenueReadinessDashboardV2Status.noData
              : input.negativeFeedbackCount > input.usefulCount
                  ? RevenueReadinessDashboardV2Status.failing
                  : RevenueReadinessDashboardV2Status.healthy,
          valueOverride: input.totalFeedbackCount == 0
              ? null
              : '${input.negativeFeedbackCount} (${_formatRate(negativeRate)})',
          nextActionLabel: diagnosisActions[
            RevenueReadinessDashboardV2DiagnosisId.negativeAboveUseful],
        ),
      ],
    );
  }

  static RevenueReadinessDashboardV2Section _returnSection(
    RevenueReadinessDashboardV2Input input,
    Map<RevenueReadinessDashboardV2DiagnosisId, String> diagnosisActions,
  ) {
    final returnRate =
        _rate(input.returnedAfterFirstProof, input.confirmedRepeatSeen);

    return RevenueReadinessDashboardV2Section(
      id: RevenueReadinessDashboardV2SectionId.returnFunnel,
      title: RevenueReadinessDashboardV2Copy.sectionReturn,
      rows: [
        _countRow(
          id: RevenueReadinessDashboardV2MetricId.returnAfterProof,
          label: RevenueReadinessDashboardV2Copy.returnAfterProof,
          count: input.returnedAfterFirstProof,
          status: input.confirmedRepeatSeen == 0
              ? RevenueReadinessDashboardV2Status.noData
              : returnRate >= returnAfterProofTarget
                  ? RevenueReadinessDashboardV2Status.healthy
                  : RevenueReadinessDashboardV2Status.failing,
          valueOverride: input.confirmedRepeatSeen == 0
              ? null
              : '${input.returnedAfterFirstProof} (${_formatRate(returnRate)})',
          nextActionLabel: diagnosisActions[
            RevenueReadinessDashboardV2DiagnosisId.lowReturnAfterProof],
        ),
        _countRow(
          id: RevenueReadinessDashboardV2MetricId.returnPromptSeen,
          label: RevenueReadinessDashboardV2Copy.returnPromptSeen,
          count: input.returnPromptSeen,
          status: input.returnPromptSeen > 0
              ? RevenueReadinessDashboardV2Status.healthy
              : RevenueReadinessDashboardV2Status.noData,
        ),
        _countRow(
          id: RevenueReadinessDashboardV2MetricId.returnPromptTapped,
          label: RevenueReadinessDashboardV2Copy.returnPromptTapped,
          count: input.returnPromptTapped,
          status: input.returnPromptTapped > 0
              ? RevenueReadinessDashboardV2Status.healthy
              : RevenueReadinessDashboardV2Status.noData,
        ),
      ],
    );
  }

  static RevenueReadinessDashboardV2Section _revenueSection(
    RevenueReadinessDashboardV2Input input,
    Map<RevenueReadinessDashboardV2DiagnosisId, String> diagnosisActions,
  ) {
    final paywallSeenRate =
        _rate(input.paywallSeen, input.confirmedRepeatSeen);
    final ctaRate = _rate(input.paywallCtaTapped, input.paywallSeen);

    return RevenueReadinessDashboardV2Section(
      id: RevenueReadinessDashboardV2SectionId.revenue,
      title: RevenueReadinessDashboardV2Copy.sectionRevenue,
      rows: [
        _countRow(
          id: RevenueReadinessDashboardV2MetricId.proBridgeSeen,
          label: RevenueReadinessDashboardV2Copy.proBridgeSeen,
          count: input.proBridgeSeen,
          status: input.proBridgeSeen > 0
              ? RevenueReadinessDashboardV2Status.healthy
              : RevenueReadinessDashboardV2Status.noData,
        ),
        _countRow(
          id: RevenueReadinessDashboardV2MetricId.proBridgeCtaTapped,
          label: RevenueReadinessDashboardV2Copy.proBridgeCtaTapped,
          count: input.proBridgeCtaTapped,
          status: input.proBridgeCtaTapped > 0
              ? RevenueReadinessDashboardV2Status.healthy
              : RevenueReadinessDashboardV2Status.noData,
        ),
        _countRow(
          id: RevenueReadinessDashboardV2MetricId.paywallSeen,
          label: RevenueReadinessDashboardV2Copy.paywallSeen,
          count: input.paywallSeen,
          status: input.confirmedRepeatSeen == 0
              ? (input.paywallSeen > 0
                  ? RevenueReadinessDashboardV2Status.watch
                  : RevenueReadinessDashboardV2Status.noData)
              : paywallSeenRate >= paywallSeenAfterProofTarget
                  ? RevenueReadinessDashboardV2Status.healthy
                  : RevenueReadinessDashboardV2Status.failing,
          valueOverride: input.confirmedRepeatSeen == 0
              ? null
              : '${input.paywallSeen} (${_formatRate(paywallSeenRate)})',
          nextActionLabel: diagnosisActions[
            RevenueReadinessDashboardV2DiagnosisId.lowPaywallSeen],
        ),
        _countRow(
          id: RevenueReadinessDashboardV2MetricId.paywallCtaTapped,
          label: RevenueReadinessDashboardV2Copy.paywallCtaTapped,
          count: input.paywallCtaTapped,
          status: input.paywallSeen == 0
              ? RevenueReadinessDashboardV2Status.noData
              : ctaRate >= purchaseCtaTarget
                  ? RevenueReadinessDashboardV2Status.healthy
                  : RevenueReadinessDashboardV2Status.failing,
          valueOverride: input.paywallSeen == 0
              ? null
              : '${input.paywallCtaTapped} (${_formatRate(ctaRate)})',
          nextActionLabel:
              diagnosisActions[RevenueReadinessDashboardV2DiagnosisId.weakCtaTap],
        ),
        _countRow(
          id: RevenueReadinessDashboardV2MetricId.purchaseStarted,
          label: RevenueReadinessDashboardV2Copy.purchaseStarted,
          count: input.purchaseStarted,
          status: input.purchaseStarted > 0
              ? RevenueReadinessDashboardV2Status.watch
              : RevenueReadinessDashboardV2Status.noData,
          nextActionLabel: diagnosisActions[
            RevenueReadinessDashboardV2DiagnosisId.purchaseCompletionIssue],
        ),
        _countRow(
          id: RevenueReadinessDashboardV2MetricId.purchaseCompleted,
          label: RevenueReadinessDashboardV2Copy.purchaseCompleted,
          count: input.purchaseCompleted,
          status: input.purchaseCompleted > 0
              ? RevenueReadinessDashboardV2Status.healthy
              : input.purchaseStarted > 0
                  ? RevenueReadinessDashboardV2Status.failing
                  : RevenueReadinessDashboardV2Status.noData,
        ),
        _countRow(
          id: RevenueReadinessDashboardV2MetricId.restoreAttempted,
          label: RevenueReadinessDashboardV2Copy.restoreAttempted,
          count: input.restoreAttempted,
          status: input.restoreAttempted > 0
              ? RevenueReadinessDashboardV2Status.watch
              : RevenueReadinessDashboardV2Status.noData,
          nextActionLabel:
              diagnosisActions[RevenueReadinessDashboardV2DiagnosisId.restoreFailure],
        ),
        _countRow(
          id: RevenueReadinessDashboardV2MetricId.restoreCompleted,
          label: RevenueReadinessDashboardV2Copy.restoreCompleted,
          count: input.restoreCompleted,
          status: input.restoreCompleted > 0
              ? RevenueReadinessDashboardV2Status.healthy
              : input.restoreAttempted > input.restoreCompleted
                  ? RevenueReadinessDashboardV2Status.failing
                  : RevenueReadinessDashboardV2Status.noData,
        ),
      ],
    );
  }

  static List<RevenueReadinessDashboardV2Diagnosis> _buildDiagnoses(
    RevenueReadinessDashboardV2Input input,
  ) {
    final diagnoses = <RevenueReadinessDashboardV2Diagnosis>[];

    final firstSaveRate =
        _rate(input.firstMomentSaved, input.recordScreenSeen);
    final secondSaveRate =
        _rate(input.secondMomentSaved, input.firstMomentSaved);
    final thirdSaveRate =
        _rate(input.thirdMomentSaved, input.secondMomentSaved);
    final usefulRate = _rate(input.usefulCount, input.totalFeedbackCount);
    final returnRate =
        _rate(input.returnedAfterFirstProof, input.confirmedRepeatSeen);
    final paywallSeenRate =
        _rate(input.paywallSeen, input.confirmedRepeatSeen);
    final ctaRate = _rate(input.paywallCtaTapped, input.paywallSeen);
    final firstSessionSaveRate = _rate(
      input.firstSaveInFirstSession,
      input.firstSessionOpportunities,
    );
    final proUnderstandingRate = _rate(
      input.understandsProYesMaybe,
      input.understandsProSurveyResponses,
    );

    if (input.firstSessionOpportunities > 0 &&
        firstSessionSaveRate < firstSessionCaptureTarget) {
      diagnoses.add(
        _diagnosis(
          id: RevenueReadinessDashboardV2DiagnosisId.firstSessionCaptureWeak,
          title: RevenueReadinessDashboardV2Copy.diagnosisFirstSessionCaptureWeak,
          nextActionLabel: RevenueReadinessDashboardV2Copy.actionFirstSessionLift,
          metricValueLabel: _formatRate(firstSessionSaveRate),
        ),
      );
    }

    if (input.understandsProSurveyResponses > 0 &&
        proUnderstandingRate < proUnderstandingTarget) {
      diagnoses.add(
        _diagnosis(
          id: RevenueReadinessDashboardV2DiagnosisId.proUnderstandingWeak,
          title: RevenueReadinessDashboardV2Copy.diagnosisProUnderstandingWeak,
          nextActionLabel:
              RevenueReadinessDashboardV2Copy.actionProUnderstandingLift,
          metricValueLabel: _formatRate(proUnderstandingRate),
        ),
      );
    }

    if (input.recordScreenSeen > 0 && firstSaveRate < firstSaveTarget) {
      diagnoses.add(
        _diagnosis(
          id: RevenueReadinessDashboardV2DiagnosisId.lowFirstSave,
          title: RevenueReadinessDashboardV2Copy.diagnosisLowFirstSave,
          nextActionLabel: RevenueReadinessDashboardV2Copy.actionFixFirstCapture,
          metricValueLabel: _formatRate(firstSaveRate),
        ),
      );
      diagnoses.add(
        _diagnosis(
          id: RevenueReadinessDashboardV2DiagnosisId.firstSaveLiftNeeded,
          title: RevenueReadinessDashboardV2Copy.diagnosisFirstSaveLiftNeeded,
          nextActionLabel: RevenueReadinessDashboardV2Copy.actionFirstSaveLift,
          metricValueLabel: _formatRate(firstSaveRate),
        ),
      );
    }

    if (input.firstMomentSaved > 0 && secondSaveRate < secondSaveTarget) {
      diagnoses.add(
        _diagnosis(
          id: RevenueReadinessDashboardV2DiagnosisId.lowSecondSave,
          title: RevenueReadinessDashboardV2Copy.diagnosisLowSecondSave,
          nextActionLabel: RevenueReadinessDashboardV2Copy.actionFixReturnPrompt,
          metricValueLabel: _formatRate(secondSaveRate),
        ),
      );
    }

    if (input.secondMomentSaved > 0 && thirdSaveRate < thirdSaveTarget) {
      diagnoses.add(
        _diagnosis(
          id: RevenueReadinessDashboardV2DiagnosisId.lowThirdSave,
          title: RevenueReadinessDashboardV2Copy.diagnosisLowThirdSave,
          nextActionLabel: RevenueReadinessDashboardV2Copy.actionFixReasonToReturn,
          metricValueLabel: _formatRate(thirdSaveRate),
        ),
      );
    }

    if (input.totalFeedbackCount > 0 && usefulRate < usefulFeedbackTarget) {
      diagnoses.add(
        _diagnosis(
          id: RevenueReadinessDashboardV2DiagnosisId.lowUsefulProof,
          title: RevenueReadinessDashboardV2Copy.diagnosisLowUsefulProof,
          nextActionLabel: RevenueReadinessDashboardV2Copy.actionFixProofWeak,
          metricValueLabel: _formatRate(usefulRate),
        ),
      );
    }

    if (input.totalFeedbackCount > 0 &&
        input.negativeFeedbackCount > input.usefulCount) {
      diagnoses.add(
        _diagnosis(
          id: RevenueReadinessDashboardV2DiagnosisId.negativeAboveUseful,
          title: RevenueReadinessDashboardV2Copy.diagnosisNegativeAboveUseful,
          nextActionLabel:
              RevenueReadinessDashboardV2Copy.actionFixAnchorCalibration,
          metricValueLabel:
              '${input.negativeFeedbackCount} vs ${input.usefulCount} useful',
        ),
      );
    }

    if (input.confirmedRepeatSeen > 0 &&
        returnRate < returnAfterProofTarget) {
      diagnoses.add(
        _diagnosis(
          id: RevenueReadinessDashboardV2DiagnosisId.lowReturnAfterProof,
          title: RevenueReadinessDashboardV2Copy.diagnosisLowReturnAfterProof,
          nextActionLabel: RevenueReadinessDashboardV2Copy.actionFixReturnLoop,
          metricValueLabel: _formatRate(returnRate),
        ),
      );
      diagnoses.add(
        _diagnosis(
          id: RevenueReadinessDashboardV2DiagnosisId.returnAfterProofLiftNeeded,
          title:
              RevenueReadinessDashboardV2Copy.diagnosisReturnAfterProofLiftNeeded,
          nextActionLabel:
              RevenueReadinessDashboardV2Copy.actionReturnAfterProofLift,
          metricValueLabel: _formatRate(returnRate),
        ),
      );
    }

    if (input.confirmedRepeatSeen > 0 &&
        paywallSeenRate < paywallSeenAfterProofTarget) {
      diagnoses.add(
        _diagnosis(
          id: RevenueReadinessDashboardV2DiagnosisId.lowPaywallSeen,
          title: RevenueReadinessDashboardV2Copy.diagnosisLowPaywallSeen,
          nextActionLabel:
              RevenueReadinessDashboardV2Copy.actionFixProBridgeHidden,
          metricValueLabel: _formatRate(paywallSeenRate),
        ),
      );
      diagnoses.add(
        _diagnosis(
          id: RevenueReadinessDashboardV2DiagnosisId.proVisibilityLiftNeeded,
          title: RevenueReadinessDashboardV2Copy.diagnosisProVisibilityLiftNeeded,
          nextActionLabel: RevenueReadinessDashboardV2Copy.actionProVisibilityLift,
          metricValueLabel: _formatRate(paywallSeenRate),
        ),
      );
    }

    if (input.paywallSeen > 0 && ctaRate < purchaseCtaTarget) {
      diagnoses.add(
        _diagnosis(
          id: RevenueReadinessDashboardV2DiagnosisId.weakCtaTap,
          title: RevenueReadinessDashboardV2Copy.diagnosisWeakCtaTap,
          nextActionLabel: RevenueReadinessDashboardV2Copy.actionFixPaywallValue,
          metricValueLabel: _formatRate(ctaRate),
        ),
      );
      diagnoses.add(
        _diagnosis(
          id: RevenueReadinessDashboardV2DiagnosisId.paywallCtaLiftNeeded,
          title: RevenueReadinessDashboardV2Copy.diagnosisPaywallCtaLiftNeeded,
          nextActionLabel: RevenueReadinessDashboardV2Copy.actionPaywallCtaLift,
          metricValueLabel: _formatRate(ctaRate),
        ),
      );
    }

    if (input.purchaseStarted > 0 && input.purchaseCompleted == 0) {
      diagnoses.add(
        _diagnosis(
          id: RevenueReadinessDashboardV2DiagnosisId.purchaseCompletionIssue,
          title: RevenueReadinessDashboardV2Copy.diagnosisPurchaseCompletion,
          nextActionLabel:
              RevenueReadinessDashboardV2Copy.actionFixBillingConfidence,
          metricValueLabel:
              '${input.purchaseStarted} started · ${input.purchaseCompleted} completed',
        ),
      );
    }

    if (input.restoreAttempted > input.restoreCompleted) {
      diagnoses.add(
        _diagnosis(
          id: RevenueReadinessDashboardV2DiagnosisId.restoreFailure,
          title: RevenueReadinessDashboardV2Copy.diagnosisRestoreFailure,
          nextActionLabel: RevenueReadinessDashboardV2Copy.actionFixRestoreFlow,
          metricValueLabel:
              '${input.restoreAttempted} attempted · ${input.restoreCompleted} completed',
        ),
      );
    }

    return diagnoses;
  }

  static RevenueReadinessDashboardV2Diagnosis _diagnosis({
    required RevenueReadinessDashboardV2DiagnosisId id,
    required String title,
    required String nextActionLabel,
    String? metricValueLabel,
  }) {
    return RevenueReadinessDashboardV2Diagnosis(
      id: id,
      title: title,
      nextActionLabel: nextActionLabel,
      metricValueLabel: metricValueLabel,
    );
  }

  static RevenueReadinessDashboardV2MetricRow _countRow({
    required RevenueReadinessDashboardV2MetricId id,
    required String label,
    required int count,
    required RevenueReadinessDashboardV2Status status,
    String? valueOverride,
    String? nextActionLabel,
  }) {
    final valueLabel = status == RevenueReadinessDashboardV2Status.noData
        ? RevenueReadinessDashboardV2Copy.notEnoughData
        : valueOverride ?? count.toString();

    return RevenueReadinessDashboardV2MetricRow(
      id: id,
      label: label,
      status: status,
      valueLabel: valueLabel,
      nextActionLabel: nextActionLabel,
    );
  }

  static RevenueReadinessDashboardV2Status _rateStatus({
    required double rate,
    required double target,
    required bool hasDenominator,
    required bool hasNumerator,
  }) {
    if (!hasDenominator && !hasNumerator) {
      return RevenueReadinessDashboardV2Status.noData;
    }
    if (!hasNumerator) {
      return RevenueReadinessDashboardV2Status.noData;
    }
    if (rate >= target) {
      return RevenueReadinessDashboardV2Status.healthy;
    }
    if (rate >= target * 0.7) {
      return RevenueReadinessDashboardV2Status.watch;
    }
    return RevenueReadinessDashboardV2Status.failing;
  }

  static Map<BetaProofFeedbackType, int> _feedbackCountsByType() {
    final counts = <BetaProofFeedbackType, int>{};
    for (final surface in BetaProofFeedbackSurface.values) {
      final record = BetaProofFeedbackStore.recordFor(surface);
      final type = record.feedbackType;
      if (type == null) continue;
      counts[type] = (counts[type] ?? 0) + 1;
    }
    return counts;
  }

  static int _timelineProofSeenCount(int confirmedRepeatSeen) {
    var seen = 0;
    for (final surface in [
      BetaProofFeedbackSurface.timelineProofMoment,
      BetaProofFeedbackSurface.archiveTimelineSpine,
    ]) {
      if (BetaProofFeedbackStore.recordFor(surface).answered) {
        seen += 1;
      }
    }
    if (seen == 0 && confirmedRepeatSeen > 0) {
      return confirmedRepeatSeen;
    }
    return seen;
  }

  static int _countFunnelEvent(
    List<({RevenueFunnelEvent event, Map<String, Object> metadata})> events,
    RevenueFunnelEvent target,
  ) =>
      events.where((record) => record.event == target).length;

  static int _countProBridgeSeen(
    List<({RevenueFunnelEvent event, Map<String, Object> metadata})> events,
  ) =>
      events
          .where(
            (record) =>
                record.event == RevenueFunnelEvent.proLockSeen ||
                record.event == RevenueFunnelEvent.monthlyReportPreviewSeen ||
                record.event == RevenueFunnelEvent.backupBridgeSeen ||
                record.event == RevenueFunnelEvent.proEvidenceValueSeen,
          )
          .length;

  static int _countProBridgeCta(
    List<({RevenueFunnelEvent event, Map<String, Object> metadata})> events,
  ) =>
      events
          .where(
            (record) =>
                record.event == RevenueFunnelEvent.proLockCtaTapped ||
                record.event ==
                    RevenueFunnelEvent.monthlyReportPreviewCtaTapped ||
                record.event == RevenueFunnelEvent.backupBridgeCtaTapped ||
                record.event == RevenueFunnelEvent.proEvidenceValueCtaTapped,
          )
          .length;

  static double _rate(int numerator, int denominator) {
    if (denominator <= 0) return 0;
    return numerator / denominator;
  }

  static String _formatRate(double value) {
    final percent = (value * 100).round();
    return '$percent%';
  }

  static int _max(int a, int b) => a > b ? a : b;
}
