import 'package:archiveme_mobile/features/activation/activation_dropoff_review_engine.dart';
import 'package:archiveme_mobile/features/beta/beta_activation_loop_counts.dart';
import 'package:archiveme_mobile/features/beta/beta_metrics_decision_copy.dart';
import 'package:archiveme_mobile/features/beta/beta_metrics_decision_model.dart';
import 'package:archiveme_mobile/features/beta/core_value_feedback_store.dart';

/// Translates local beta counters into a product diagnosis — read-only.
abstract final class BetaMetricsDecisionEngine {
  BetaMetricsDecisionEngine._();

  static const defaultTotalTesters = 10;
  static const firstSaveTargetForTen = 7;
  static const secondSaveTargetForTen = 5;
  static const firstProofTargetForTen = 3;
  static const specificProofTargetForTen = 2;

  static BetaMetricsDecisionReport build({
    required BetaMetricsDecisionInput input,
  }) {
    final total = input.totalTesters;
    final firstSaveTarget = _scaledTarget(firstSaveTargetForTen, total);
    final secondSaveTarget = _scaledTarget(secondSaveTargetForTen, total);
    final firstProofTarget = _scaledTarget(firstProofTargetForTen, total);
    final specificProofTarget = _scaledTarget(specificProofTargetForTen, total);

    final rows = [
      _firstSaveRow(input, firstSaveTarget),
      _secondSaveRow(input, secondSaveTarget),
      _firstProofRow(input, firstProofTarget),
      _specificProofRow(input, firstProofTarget, specificProofTarget),
      _wouldContinueRow(input),
      _wouldPayRow(input, firstProofTarget, specificProofTarget),
    ];

    final bottleneck = _resolvePrimaryBottleneck(
      input: input,
      firstSaveTarget: firstSaveTarget,
      secondSaveTarget: secondSaveTarget,
      firstProofTarget: firstProofTarget,
      specificProofTarget: specificProofTarget,
    );

    return BetaMetricsDecisionReport(
      title: BetaMetricsDecisionCopy.cardTitle,
      summary: _summaryFor(bottleneck),
      primaryBottleneck: bottleneck,
      rows: rows,
      coreValueFeedbackLabel: BetaMetricsDecisionCopy.coreValueFeedbackLabel,
      coreValueFeedbackAnswer: CoreValueFeedbackStore.cached.diagnosticsSummary,
    );
  }

  static BetaMetricsDecisionInput fromBetaCounts({
    BetaActivationLoopCounts? betaCounts,
    int? totalTesters,
    int? proofFeltSpecific,
    int? proofUsefulCount,
    int? wouldKeepUsing,
    int? wouldPay,
  }) {
    final counters = ActivationDropoffReviewEngine.fromBetaCounts(betaCounts);
    final resolvedTotal =
        totalTesters ?? (counters.appOpened > 0 ? counters.appOpened : 0);

    return BetaMetricsDecisionInput(
      totalTesters: resolvedTotal,
      firstMomentSaved: counters.firstMomentSaved,
      secondMomentSaved: counters.secondMomentSaved,
      firstProofReached: counters.firstProofReached,
      returnCheckAnswered: counters.returnCheckAnswered,
      proTapped: counters.proTapped,
      proofFeltSpecific: proofFeltSpecific,
      proofUsefulCount: proofUsefulCount,
      wouldKeepUsing: wouldKeepUsing,
      wouldPay: wouldPay,
    );
  }

  static int _scaledTarget(int targetForTen, int totalTesters) {
    if (totalTesters <= 0) return targetForTen;
    if (totalTesters == defaultTotalTesters) return targetForTen;
    return ((targetForTen * totalTesters) / defaultTotalTesters).ceil();
  }

  static BetaMetricsDecisionRow _firstSaveRow(
    BetaMetricsDecisionInput input,
    int target,
  ) {
    final total = _displayTotal(input.totalTesters);
    final status = _automaticStatus(
      totalTesters: input.totalTesters,
      current: input.firstMomentSaved,
      target: target,
    );
    return BetaMetricsDecisionRow(
      id: BetaMetricsDecisionRowId.firstSave,
      metricName: BetaMetricsDecisionCopy.rowFirstSave,
      currentValue: BetaMetricsDecisionCopy.valueLabel(
        input.firstMomentSaved,
        total,
      ),
      targetValue: BetaMetricsDecisionCopy.targetLabel(target, total),
      status: status,
      fixArea: BetaMetricsDecisionCopy.fixFirstUse,
      problemLabel: status == BetaMetricsDecisionRowStatus.belowTarget
          ? BetaMetricsDecisionCopy.problemFirstScreen
          : null,
    );
  }

  static BetaMetricsDecisionRow _secondSaveRow(
    BetaMetricsDecisionInput input,
    int target,
  ) {
    final total = _displayTotal(input.totalTesters);
    final status = _automaticStatus(
      totalTesters: input.totalTesters,
      current: input.secondMomentSaved,
      target: target,
    );
    return BetaMetricsDecisionRow(
      id: BetaMetricsDecisionRowId.secondSave,
      metricName: BetaMetricsDecisionCopy.rowSecondSave,
      currentValue: BetaMetricsDecisionCopy.valueLabel(
        input.secondMomentSaved,
        total,
      ),
      targetValue: BetaMetricsDecisionCopy.targetLabel(target, total),
      status: status,
      fixArea: BetaMetricsDecisionCopy.fixReturnHandoff,
      problemLabel: status == BetaMetricsDecisionRowStatus.belowTarget
          ? BetaMetricsDecisionCopy.problemReturn
          : null,
    );
  }

  static BetaMetricsDecisionRow _firstProofRow(
    BetaMetricsDecisionInput input,
    int target,
  ) {
    final total = _displayTotal(input.totalTesters);
    final status = _automaticStatus(
      totalTesters: input.totalTesters,
      current: input.firstProofReached,
      target: target,
    );
    return BetaMetricsDecisionRow(
      id: BetaMetricsDecisionRowId.firstProof,
      metricName: BetaMetricsDecisionCopy.rowFirstProof,
      currentValue: BetaMetricsDecisionCopy.valueLabel(
        input.firstProofReached,
        total,
      ),
      targetValue: BetaMetricsDecisionCopy.targetLabel(target, total),
      status: status,
      fixArea: BetaMetricsDecisionCopy.fixActivationJourney,
      problemLabel: status == BetaMetricsDecisionRowStatus.belowTarget
          ? BetaMetricsDecisionCopy.problemActivation
          : null,
    );
  }

  static BetaMetricsDecisionRow _specificProofRow(
    BetaMetricsDecisionInput input,
    int firstProofTarget,
    int specificTarget,
  ) {
    final total = _displayTotal(input.totalTesters);
    if (input.proofFeltSpecific == null) {
      return BetaMetricsDecisionRow(
        id: BetaMetricsDecisionRowId.specificProof,
        metricName: BetaMetricsDecisionCopy.rowSpecificProof,
        currentValue: BetaMetricsDecisionCopy.noDecisionYet,
        targetValue: BetaMetricsDecisionCopy.targetLabel(specificTarget, total),
        status: BetaMetricsDecisionRowStatus.checkManually,
        fixArea: BetaMetricsDecisionCopy.fixEvidence,
      );
    }
    if (input.totalTesters <= 0 || input.firstProofReached < firstProofTarget) {
      return BetaMetricsDecisionRow(
        id: BetaMetricsDecisionRowId.specificProof,
        metricName: BetaMetricsDecisionCopy.rowSpecificProof,
        currentValue: BetaMetricsDecisionCopy.valueLabel(
          input.proofFeltSpecific!,
          total,
        ),
        targetValue: BetaMetricsDecisionCopy.targetLabel(specificTarget, total),
        status: BetaMetricsDecisionRowStatus.notEnoughData,
        fixArea: BetaMetricsDecisionCopy.fixEvidence,
      );
    }
    final below = input.proofFeltSpecific! < specificTarget;
    return BetaMetricsDecisionRow(
      id: BetaMetricsDecisionRowId.specificProof,
      metricName: BetaMetricsDecisionCopy.rowSpecificProof,
      currentValue: BetaMetricsDecisionCopy.valueLabel(
        input.proofFeltSpecific!,
        total,
      ),
      targetValue: BetaMetricsDecisionCopy.targetLabel(specificTarget, total),
      status: below
          ? BetaMetricsDecisionRowStatus.belowTarget
          : BetaMetricsDecisionRowStatus.ready,
      fixArea: BetaMetricsDecisionCopy.fixEvidence,
      problemLabel: below ? BetaMetricsDecisionCopy.problemEvidence : null,
    );
  }

  static BetaMetricsDecisionRow _wouldContinueRow(
    BetaMetricsDecisionInput input,
  ) {
    final total = _displayTotal(input.totalTesters);
    if (input.wouldKeepUsing == null || input.proofUsefulCount == null) {
      return const BetaMetricsDecisionRow(
        id: BetaMetricsDecisionRowId.wouldContinue,
        metricName: BetaMetricsDecisionCopy.rowWouldContinue,
        currentValue: BetaMetricsDecisionCopy.noDecisionYet,
        targetValue: BetaMetricsDecisionCopy.statusCheckManually,
        status: BetaMetricsDecisionRowStatus.checkManually,
        fixArea: BetaMetricsDecisionCopy.fixRetention,
      );
    }
    if (input.proofUsefulCount! <= 0) {
      return BetaMetricsDecisionRow(
        id: BetaMetricsDecisionRowId.wouldContinue,
        metricName: BetaMetricsDecisionCopy.rowWouldContinue,
        currentValue: BetaMetricsDecisionCopy.valueLabel(
          input.wouldKeepUsing!,
          total,
        ),
        targetValue: BetaMetricsDecisionCopy.statusCheckManually,
        status: BetaMetricsDecisionRowStatus.notEnoughData,
        fixArea: BetaMetricsDecisionCopy.fixRetention,
      );
    }
    final below = input.wouldKeepUsing! <= 0;
    return BetaMetricsDecisionRow(
      id: BetaMetricsDecisionRowId.wouldContinue,
      metricName: BetaMetricsDecisionCopy.rowWouldContinue,
      currentValue: BetaMetricsDecisionCopy.valueLabel(
        input.wouldKeepUsing!,
        total,
      ),
      targetValue: '> 0 / ${input.proofUsefulCount!}',
      status: below
          ? BetaMetricsDecisionRowStatus.belowTarget
          : BetaMetricsDecisionRowStatus.ready,
      fixArea: BetaMetricsDecisionCopy.fixRetention,
      problemLabel: below ? BetaMetricsDecisionCopy.problemRetention : null,
    );
  }

  static BetaMetricsDecisionRow _wouldPayRow(
    BetaMetricsDecisionInput input,
    int firstProofTarget,
    int specificProofTarget,
  ) {
    final total = _displayTotal(input.totalTesters);
    if (!_canEvaluateMonetisation(
      input: input,
      firstProofTarget: firstProofTarget,
      specificProofTarget: specificProofTarget,
    )) {
      return const BetaMetricsDecisionRow(
        id: BetaMetricsDecisionRowId.wouldPay,
        metricName: BetaMetricsDecisionCopy.rowWouldPay,
        currentValue: BetaMetricsDecisionCopy.noDecisionYet,
        targetValue: BetaMetricsDecisionCopy.statusCheckManually,
        status: BetaMetricsDecisionRowStatus.checkManually,
        fixArea: BetaMetricsDecisionCopy.fixMonetisation,
      );
    }
    if (input.wouldPay == null) {
      return const BetaMetricsDecisionRow(
        id: BetaMetricsDecisionRowId.wouldPay,
        metricName: BetaMetricsDecisionCopy.rowWouldPay,
        currentValue: BetaMetricsDecisionCopy.noDecisionYet,
        targetValue: BetaMetricsDecisionCopy.statusCheckManually,
        status: BetaMetricsDecisionRowStatus.checkManually,
        fixArea: BetaMetricsDecisionCopy.fixMonetisation,
      );
    }
    final usefulCount = input.proofUsefulCount ?? input.firstProofReached;
    if (usefulCount <= 0) {
      return BetaMetricsDecisionRow(
        id: BetaMetricsDecisionRowId.wouldPay,
        metricName: BetaMetricsDecisionCopy.rowWouldPay,
        currentValue: BetaMetricsDecisionCopy.valueLabel(
          input.wouldPay!,
          total,
        ),
        targetValue: '> 0',
        status: BetaMetricsDecisionRowStatus.notEnoughData,
        fixArea: BetaMetricsDecisionCopy.fixMonetisation,
      );
    }
    final below = input.wouldPay! <= 0;
    return BetaMetricsDecisionRow(
      id: BetaMetricsDecisionRowId.wouldPay,
      metricName: BetaMetricsDecisionCopy.rowWouldPay,
      currentValue: BetaMetricsDecisionCopy.valueLabel(input.wouldPay!, total),
      targetValue: '> 0',
      status: below
          ? BetaMetricsDecisionRowStatus.belowTarget
          : BetaMetricsDecisionRowStatus.ready,
      fixArea: BetaMetricsDecisionCopy.fixMonetisation,
      problemLabel: below ? BetaMetricsDecisionCopy.problemMonetisation : null,
    );
  }

  static BetaMetricsDecisionRowStatus _automaticStatus({
    required int totalTesters,
    required int current,
    required int target,
  }) {
    if (totalTesters <= 0) {
      return BetaMetricsDecisionRowStatus.notEnoughData;
    }
    if (current >= target) return BetaMetricsDecisionRowStatus.ready;
    return BetaMetricsDecisionRowStatus.belowTarget;
  }

  static int _displayTotal(int totalTesters) =>
      totalTesters > 0 ? totalTesters : defaultTotalTesters;

  static bool _activationWorking({
    required BetaMetricsDecisionInput input,
    required int firstSaveTarget,
    required int secondSaveTarget,
    required int firstProofTarget,
  }) =>
      input.totalTesters > 0 &&
      input.firstMomentSaved >= firstSaveTarget &&
      input.secondMomentSaved >= secondSaveTarget &&
      input.firstProofReached >= firstProofTarget;

  static bool _evidenceWorking({
    required BetaMetricsDecisionInput input,
    required int firstProofTarget,
    required int specificProofTarget,
  }) =>
      input.firstProofReached >= firstProofTarget &&
      input.proofFeltSpecific != null &&
      input.proofFeltSpecific! >= specificProofTarget;

  static bool _canEvaluateMonetisation({
    required BetaMetricsDecisionInput input,
    required int firstProofTarget,
    required int specificProofTarget,
  }) {
    final firstSaveTarget = _scaledTarget(
      firstSaveTargetForTen,
      input.totalTesters,
    );
    final secondSaveTarget = _scaledTarget(
      secondSaveTargetForTen,
      input.totalTesters,
    );
    return _activationWorking(
          input: input,
          firstSaveTarget: firstSaveTarget,
          secondSaveTarget: secondSaveTarget,
          firstProofTarget: firstProofTarget,
        ) &&
        _evidenceWorking(
          input: input,
          firstProofTarget: firstProofTarget,
          specificProofTarget: specificProofTarget,
        );
  }

  static BetaMetricsDecisionBottleneck _resolvePrimaryBottleneck({
    required BetaMetricsDecisionInput input,
    required int firstSaveTarget,
    required int secondSaveTarget,
    required int firstProofTarget,
    required int specificProofTarget,
  }) {
    if (input.totalTesters <= 0) {
      return BetaMetricsDecisionBottleneck.notEnoughData;
    }

    if (input.firstMomentSaved < firstSaveTarget) {
      return BetaMetricsDecisionBottleneck.firstScreen;
    }
    if (input.secondMomentSaved < secondSaveTarget) {
      return BetaMetricsDecisionBottleneck.returnLoop;
    }
    if (input.firstProofReached < firstProofTarget) {
      return BetaMetricsDecisionBottleneck.firstProofActivation;
    }

    if (input.proofFeltSpecific != null &&
        input.firstProofReached >= firstProofTarget &&
        input.proofFeltSpecific! < specificProofTarget) {
      return BetaMetricsDecisionBottleneck.evidenceSpecificity;
    }

    if (input.proofUsefulCount != null &&
        input.wouldKeepUsing != null &&
        input.proofUsefulCount! > 0 &&
        input.wouldKeepUsing! <= 0) {
      return BetaMetricsDecisionBottleneck.retention;
    }

    if (_canEvaluateMonetisation(
      input: input,
      firstProofTarget: firstProofTarget,
      specificProofTarget: specificProofTarget,
    )) {
      if (input.wouldPay != null && input.wouldPay! <= 0) {
        return BetaMetricsDecisionBottleneck.monetisation;
      }
    }

    final automaticHealthy =
        input.firstMomentSaved >= firstSaveTarget &&
        input.secondMomentSaved >= secondSaveTarget &&
        input.firstProofReached >= firstProofTarget &&
        (input.proofFeltSpecific == null ||
            input.proofFeltSpecific! >= specificProofTarget) &&
        !(input.proofUsefulCount != null &&
            input.wouldKeepUsing != null &&
            input.proofUsefulCount! > 0 &&
            input.wouldKeepUsing! <= 0) &&
        !(_canEvaluateMonetisation(
              input: input,
              firstProofTarget: firstProofTarget,
              specificProofTarget: specificProofTarget,
            ) &&
            input.wouldPay != null &&
            input.wouldPay! <= 0);

    if (automaticHealthy) {
      return BetaMetricsDecisionBottleneck.healthy;
    }

    if (input.proofFeltSpecific == null) {
      return BetaMetricsDecisionBottleneck.healthy;
    }

    return BetaMetricsDecisionBottleneck.healthy;
  }

  static String _summaryFor(BetaMetricsDecisionBottleneck bottleneck) =>
      switch (bottleneck) {
        BetaMetricsDecisionBottleneck.notEnoughData =>
          BetaMetricsDecisionCopy.summaryNotEnoughData,
        BetaMetricsDecisionBottleneck.firstScreen =>
          BetaMetricsDecisionCopy.summaryFirstScreen,
        BetaMetricsDecisionBottleneck.returnLoop =>
          BetaMetricsDecisionCopy.summaryReturnLoop,
        BetaMetricsDecisionBottleneck.firstProofActivation =>
          BetaMetricsDecisionCopy.summaryFirstProof,
        BetaMetricsDecisionBottleneck.evidenceSpecificity =>
          BetaMetricsDecisionCopy.summaryEvidence,
        BetaMetricsDecisionBottleneck.retention =>
          BetaMetricsDecisionCopy.summaryRetention,
        BetaMetricsDecisionBottleneck.monetisation =>
          BetaMetricsDecisionCopy.summaryMonetisation,
        BetaMetricsDecisionBottleneck.healthy =>
          BetaMetricsDecisionCopy.summaryHealthy,
      };
}