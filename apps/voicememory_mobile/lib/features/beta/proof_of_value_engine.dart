import '../activation/activation_dropoff_review_engine.dart';
import 'beta_activation_loop_counts.dart';
import 'core_value_feedback_model.dart';
import 'core_value_feedback_store.dart';
import 'proof_of_value_copy.dart';
import 'proof_of_value_model.dart';

/// Read-only proof-of-value summary for beta TestFlight — no network or purchases.
abstract final class ProofOfValueEngine {
  ProofOfValueEngine._();

  static const defaultTotalTesters = 10;
  static const minTesterEvidence = 5;
  static const firstSaveTargetForTen = 7;
  static const secondSaveTargetForTen = 5;
  static const firstProofTargetForTen = 3;
  static const coreValueYesTargetForTen = 2;
  static const wouldKeepUsingTargetForTen = 2;
  static const wouldPayTargetForTen = 1;
  static const returnCheckTargetForTen = 2;

  static ProofOfValueReport build({required ProofOfValueInput input}) {
    final total = _displayTotal(input.totalTesters);
    final firstSaveTarget = _scaledTarget(firstSaveTargetForTen, input.totalTesters);
    final secondSaveTarget =
        _scaledTarget(secondSaveTargetForTen, input.totalTesters);
    final firstProofTarget =
        _scaledTarget(firstProofTargetForTen, input.totalTesters);
    final coreValueYesTarget =
        _scaledTarget(coreValueYesTargetForTen, input.totalTesters);
    final wouldKeepUsingTarget =
        _scaledTarget(wouldKeepUsingTargetForTen, input.totalTesters);
    final wouldPayTarget = _scaledTarget(wouldPayTargetForTen, input.totalTesters);
    final returnCheckTarget =
        _scaledTarget(returnCheckTargetForTen, input.totalTesters);

    final rows = [
      _firstSaveRow(input, total, firstSaveTarget),
      _secondSaveRow(input, total, secondSaveTarget),
      _firstProofRow(input, total, firstProofTarget),
      _coreValueYesRow(input, total, coreValueYesTarget),
      _feltGenericRow(input, total, firstProofTarget),
      _wouldKeepUsingRow(input, total, wouldKeepUsingTarget),
      _wouldPayRow(input, total, wouldPayTarget),
      _returnCheckRow(input, total, returnCheckTarget),
    ];

    final recommendation = _resolveRecommendation(
      input: input,
      firstSaveTarget: firstSaveTarget,
      secondSaveTarget: secondSaveTarget,
      firstProofTarget: firstProofTarget,
      coreValueYesTarget: coreValueYesTarget,
      wouldKeepUsingTarget: wouldKeepUsingTarget,
      wouldPayTarget: wouldPayTarget,
    );

    final summaryState = _resolveSummaryState(
      input: input,
      rows: rows,
      recommendation: recommendation,
      firstSaveTarget: firstSaveTarget,
      secondSaveTarget: secondSaveTarget,
      firstProofTarget: firstProofTarget,
      coreValueYesTarget: coreValueYesTarget,
      wouldKeepUsingTarget: wouldKeepUsingTarget,
      wouldPayTarget: wouldPayTarget,
    );

    return ProofOfValueReport(
      title: ProofOfValueCopy.cardTitle,
      primaryQuestion: ProofOfValueCopy.primaryQuestion,
      summary: _summaryFor(summaryState),
      summaryState: summaryState,
      recommendation: recommendation,
      rows: rows,
      localCoreValueNote: _localCoreValueNote(input),
    );
  }

  static ProofOfValueInput fromBetaCounts({
    BetaActivationLoopCounts? betaCounts,
    int? totalTesters,
    int? coreValueYes,
    int? coreValueNotYet,
    int? coreValueGeneric,
    int? proofFeltSpecific,
    int? proofUsefulCount,
    int? wouldKeepUsing,
    int? wouldPay,
    String? localCoreValueAnswerLabel,
  }) {
    final counters = ActivationDropoffReviewEngine.fromBetaCounts(betaCounts);
    final resolvedTotal = totalTesters ??
        (counters.appOpened > 0 ? counters.appOpened : 0);
    final localLabel = localCoreValueAnswerLabel ??
        _localAnswerLabelFromStore();

    return ProofOfValueInput(
      totalTesters: resolvedTotal,
      appOpened: counters.appOpened,
      firstMomentSaved: counters.firstMomentSaved,
      secondMomentSaved: counters.secondMomentSaved,
      firstProofReached: counters.firstProofReached,
      returnCheckAnswered: counters.returnCheckAnswered,
      proTapped: counters.proTapped,
      coreValueYes: coreValueYes,
      coreValueNotYet: coreValueNotYet,
      coreValueGeneric: coreValueGeneric,
      localCoreValueAnswerLabel: localLabel,
      proofFeltSpecific: proofFeltSpecific,
      proofUsefulCount: proofUsefulCount,
      wouldKeepUsing: wouldKeepUsing,
      wouldPay: wouldPay,
    );
  }

  static String? _localAnswerLabelFromStore() {
    final answer = CoreValueFeedbackStore.cached.answer;
    if (answer == null) return null;
    return answer.diagnosticsLabel;
  }

  static String? _localCoreValueNote(ProofOfValueInput input) {
    final label = input.localCoreValueAnswerLabel;
    if (label == null || label.isEmpty) return null;
    if (input.coreValueYes != null ||
        input.coreValueNotYet != null ||
        input.coreValueGeneric != null) {
      return null;
    }
    return ProofOfValueCopy.localAnswerLabel(label);
  }

  static int _effectiveCoreValueYes(ProofOfValueInput input) {
    if (input.coreValueYes != null) return input.coreValueYes!;
    if (input.localCoreValueAnswerLabel ==
        CoreValueFeedbackAnswer.yes.diagnosticsLabel) {
      return 1;
    }
    return 0;
  }

  static int _effectiveCoreValueGeneric(ProofOfValueInput input) {
    if (input.coreValueGeneric != null) return input.coreValueGeneric!;
    if (input.localCoreValueAnswerLabel ==
        CoreValueFeedbackAnswer.generic.diagnosticsLabel) {
      return 1;
    }
    return 0;
  }

  static bool _specificityProven(ProofOfValueInput input, int target) =>
      _effectiveCoreValueYes(input) >= target ||
      (input.proofFeltSpecific != null && input.proofFeltSpecific! >= target);

  static bool _genericWarning(ProofOfValueInput input, int firstProofTarget) {
    final generic = _effectiveCoreValueGeneric(input);
    if (generic <= 0) return false;
    final yes = _effectiveCoreValueYes(input);
    if (generic >= yes && yes > 0) return true;
    if (generic > 0 && input.firstProofReached <= firstProofTarget) return true;
    return false;
  }

  static bool _notEnoughTesterEvidence(ProofOfValueInput input) =>
      input.totalTesters < minTesterEvidence ||
      input.appOpened < minTesterEvidence;

  static ProofOfValueRow _firstSaveRow(
    ProofOfValueInput input,
    int total,
    int target,
  ) {
    final status = _automaticStatus(
      notEnough: _notEnoughTesterEvidence(input),
      current: input.firstMomentSaved,
      target: target,
    );
    return ProofOfValueRow(
      id: ProofOfValueRowId.firstSave,
      label: ProofOfValueCopy.rowFirstSave,
      question: ProofOfValueCopy.questionFirstSave,
      currentValue: ProofOfValueCopy.valueLabel(input.firstMomentSaved, total),
      targetValue: ProofOfValueCopy.targetLabel(target, total),
      status: status,
    );
  }

  static ProofOfValueRow _secondSaveRow(
    ProofOfValueInput input,
    int total,
    int target,
  ) {
    final status = _automaticStatus(
      notEnough: _notEnoughTesterEvidence(input),
      current: input.secondMomentSaved,
      target: target,
    );
    return ProofOfValueRow(
      id: ProofOfValueRowId.secondSave,
      label: ProofOfValueCopy.rowSecondSave,
      question: ProofOfValueCopy.questionSecondSave,
      currentValue: ProofOfValueCopy.valueLabel(input.secondMomentSaved, total),
      targetValue: ProofOfValueCopy.targetLabel(target, total),
      status: status,
    );
  }

  static ProofOfValueRow _firstProofRow(
    ProofOfValueInput input,
    int total,
    int target,
  ) {
    final status = _automaticStatus(
      notEnough: _notEnoughTesterEvidence(input),
      current: input.firstProofReached,
      target: target,
    );
    return ProofOfValueRow(
      id: ProofOfValueRowId.firstProof,
      label: ProofOfValueCopy.rowFirstProof,
      question: ProofOfValueCopy.questionFirstProof,
      currentValue: ProofOfValueCopy.valueLabel(input.firstProofReached, total),
      targetValue: ProofOfValueCopy.targetLabel(target, total),
      status: status,
    );
  }

  static ProofOfValueRow _coreValueYesRow(
    ProofOfValueInput input,
    int total,
    int target,
  ) {
    if (_notEnoughTesterEvidence(input)) {
      return ProofOfValueRow(
        id: ProofOfValueRowId.coreValueYes,
        label: ProofOfValueCopy.rowCoreValueYes,
        question: ProofOfValueCopy.questionCoreValueYes,
        currentValue: ProofOfValueCopy.noManualCountYet,
        targetValue: ProofOfValueCopy.targetLabel(target, total),
        status: ProofOfValueRowStatus.notEnoughData,
      );
    }

    if (input.coreValueYes != null) {
      final current = input.coreValueYes!;
      final proven = _specificityProven(input, target);
      return ProofOfValueRow(
        id: ProofOfValueRowId.coreValueYes,
        label: ProofOfValueCopy.rowCoreValueYes,
        question: ProofOfValueCopy.questionCoreValueYes,
        currentValue: ProofOfValueCopy.valueLabel(current, total),
        targetValue: ProofOfValueCopy.targetLabel(target, total),
        status: proven
            ? ProofOfValueRowStatus.proven
            : ProofOfValueRowStatus.notProven,
      );
    }

    if (input.proofFeltSpecific != null) {
      final current = input.proofFeltSpecific!;
      return ProofOfValueRow(
        id: ProofOfValueRowId.coreValueYes,
        label: ProofOfValueCopy.rowCoreValueYes,
        question: ProofOfValueCopy.questionCoreValueYes,
        currentValue: ProofOfValueCopy.valueLabel(current, total),
        targetValue: ProofOfValueCopy.targetLabel(target, total),
        status: current >= target
            ? ProofOfValueRowStatus.proven
            : ProofOfValueRowStatus.notProven,
      );
    }

    if (input.localCoreValueAnswerLabel != null) {
      return ProofOfValueRow(
        id: ProofOfValueRowId.coreValueYes,
        label: ProofOfValueCopy.rowCoreValueYes,
        question: ProofOfValueCopy.questionCoreValueYes,
        currentValue: ProofOfValueCopy.localAnswerLabel(
          input.localCoreValueAnswerLabel!,
        ),
        targetValue: ProofOfValueCopy.targetLabel(target, total),
        status: ProofOfValueRowStatus.checkManually,
      );
    }

    return ProofOfValueRow(
      id: ProofOfValueRowId.coreValueYes,
      label: ProofOfValueCopy.rowCoreValueYes,
      question: ProofOfValueCopy.questionCoreValueYes,
      currentValue: ProofOfValueCopy.noManualCountYet,
      targetValue: ProofOfValueCopy.targetLabel(target, total),
      status: ProofOfValueRowStatus.checkManually,
    );
  }

  static ProofOfValueRow _feltGenericRow(
    ProofOfValueInput input,
    int total,
    int firstProofTarget,
  ) {
    if (_notEnoughTesterEvidence(input)) {
      return ProofOfValueRow(
        id: ProofOfValueRowId.feltGeneric,
        label: ProofOfValueCopy.rowFeltGeneric,
        question: ProofOfValueCopy.questionFeltGeneric,
        currentValue: ProofOfValueCopy.noManualCountYet,
        targetValue: '0',
        status: ProofOfValueRowStatus.notEnoughData,
      );
    }

    final generic = _effectiveCoreValueGeneric(input);
    final currentValue = input.coreValueGeneric != null
        ? ProofOfValueCopy.valueLabel(generic, total)
        : (input.localCoreValueAnswerLabel ==
                CoreValueFeedbackAnswer.generic.diagnosticsLabel
            ? ProofOfValueCopy.localAnswerLabel(
                input.localCoreValueAnswerLabel!,
              )
            : ProofOfValueCopy.valueLabel(generic, total));

    final warning = _genericWarning(input, firstProofTarget);
    return ProofOfValueRow(
      id: ProofOfValueRowId.feltGeneric,
      label: ProofOfValueCopy.rowFeltGeneric,
      question: ProofOfValueCopy.questionFeltGeneric,
      currentValue: currentValue,
      targetValue: '0',
      status: warning
          ? ProofOfValueRowStatus.warning
          : (generic > 0
              ? ProofOfValueRowStatus.checkManually
              : ProofOfValueRowStatus.proven),
    );
  }

  static ProofOfValueRow _wouldKeepUsingRow(
    ProofOfValueInput input,
    int total,
    int target,
  ) {
    if (_notEnoughTesterEvidence(input)) {
      return ProofOfValueRow(
        id: ProofOfValueRowId.wouldKeepUsing,
        label: ProofOfValueCopy.rowWouldKeepUsing,
        question: ProofOfValueCopy.questionWouldKeepUsing,
        currentValue: ProofOfValueCopy.noManualCountYet,
        targetValue: ProofOfValueCopy.targetLabel(target, total),
        status: ProofOfValueRowStatus.notEnoughData,
      );
    }

    if (input.wouldKeepUsing == null) {
      return ProofOfValueRow(
        id: ProofOfValueRowId.wouldKeepUsing,
        label: ProofOfValueCopy.rowWouldKeepUsing,
        question: ProofOfValueCopy.questionWouldKeepUsing,
        currentValue: ProofOfValueCopy.noManualCountYet,
        targetValue: ProofOfValueCopy.targetLabel(target, total),
        status: ProofOfValueRowStatus.checkManually,
      );
    }

    return ProofOfValueRow(
      id: ProofOfValueRowId.wouldKeepUsing,
      label: ProofOfValueCopy.rowWouldKeepUsing,
      question: ProofOfValueCopy.questionWouldKeepUsing,
      currentValue: ProofOfValueCopy.valueLabel(input.wouldKeepUsing!, total),
      targetValue: ProofOfValueCopy.targetLabel(target, total),
      status: input.wouldKeepUsing! >= target
          ? ProofOfValueRowStatus.proven
          : ProofOfValueRowStatus.notProven,
    );
  }

  static ProofOfValueRow _wouldPayRow(
    ProofOfValueInput input,
    int total,
    int target,
  ) {
    if (_notEnoughTesterEvidence(input)) {
      return ProofOfValueRow(
        id: ProofOfValueRowId.wouldPay,
        label: ProofOfValueCopy.rowWouldPay,
        question: ProofOfValueCopy.questionWouldPay,
        currentValue: ProofOfValueCopy.noManualCountYet,
        targetValue: ProofOfValueCopy.targetLabel(target, total),
        status: ProofOfValueRowStatus.notEnoughData,
      );
    }

    if (input.wouldPay != null) {
      final proven = input.wouldPay! >= target || input.proTapped >= target;
      return ProofOfValueRow(
        id: ProofOfValueRowId.wouldPay,
        label: ProofOfValueCopy.rowWouldPay,
        question: ProofOfValueCopy.questionWouldPay,
        currentValue: ProofOfValueCopy.valueLabel(input.wouldPay!, total),
        targetValue: ProofOfValueCopy.targetLabel(target, total),
        status: proven
            ? ProofOfValueRowStatus.proven
            : ProofOfValueRowStatus.notProven,
      );
    }

    if (input.proTapped >= target) {
      return ProofOfValueRow(
        id: ProofOfValueRowId.wouldPay,
        label: ProofOfValueCopy.rowWouldPay,
        question: ProofOfValueCopy.questionWouldPay,
        currentValue: ProofOfValueCopy.valueLabel(input.proTapped, total),
        targetValue: ProofOfValueCopy.targetLabel(target, total),
        status: ProofOfValueRowStatus.proven,
      );
    }

    return ProofOfValueRow(
      id: ProofOfValueRowId.wouldPay,
      label: ProofOfValueCopy.rowWouldPay,
      question: ProofOfValueCopy.questionWouldPay,
      currentValue: ProofOfValueCopy.noManualCountYet,
      targetValue: ProofOfValueCopy.targetLabel(target, total),
      status: ProofOfValueRowStatus.checkManually,
    );
  }

  static ProofOfValueRow _returnCheckRow(
    ProofOfValueInput input,
    int total,
    int target,
  ) {
    final status = _automaticStatus(
      notEnough: _notEnoughTesterEvidence(input),
      current: input.returnCheckAnswered,
      target: target,
    );
    return ProofOfValueRow(
      id: ProofOfValueRowId.returnCheck,
      label: ProofOfValueCopy.rowReturnCheck,
      question: ProofOfValueCopy.questionReturnCheck,
      currentValue: ProofOfValueCopy.valueLabel(input.returnCheckAnswered, total),
      targetValue: ProofOfValueCopy.targetLabel(target, total),
      status: status,
    );
  }

  static ProofOfValueRowStatus _automaticStatus({
    required bool notEnough,
    required int current,
    required int target,
  }) {
    if (notEnough) return ProofOfValueRowStatus.notEnoughData;
    if (current >= target) return ProofOfValueRowStatus.proven;
    return ProofOfValueRowStatus.notProven;
  }

  static int _scaledTarget(int targetForTen, int totalTesters) {
    if (totalTesters <= 0) return targetForTen;
    if (totalTesters == defaultTotalTesters) return targetForTen;
    return ((targetForTen * totalTesters) / defaultTotalTesters).ceil();
  }

  static int _displayTotal(int totalTesters) =>
      totalTesters > 0 ? totalTesters : defaultTotalTesters;

  static String _resolveRecommendation({
    required ProofOfValueInput input,
    required int firstSaveTarget,
    required int secondSaveTarget,
    required int firstProofTarget,
    required int coreValueYesTarget,
    required int wouldKeepUsingTarget,
    required int wouldPayTarget,
  }) {
    if (_notEnoughTesterEvidence(input)) {
      return ProofOfValueCopy.recommendationRunMoreTesters;
    }
    if (input.firstMomentSaved < firstSaveTarget) {
      return ProofOfValueCopy.recommendationFixFirstUse;
    }
    if (input.secondMomentSaved < secondSaveTarget) {
      return ProofOfValueCopy.recommendationFixReturnLoop;
    }
    if (input.firstProofReached < firstProofTarget) {
      return ProofOfValueCopy.recommendationFixFirstProof;
    }
    if (!_specificityProven(input, coreValueYesTarget) ||
        _genericWarning(input, firstProofTarget)) {
      return ProofOfValueCopy.recommendationFixEvidence;
    }
    if (input.wouldKeepUsing == null || input.wouldKeepUsing! < wouldKeepUsingTarget) {
      return ProofOfValueCopy.recommendationStrengthenRetention;
    }
    if ((input.wouldPay == null || input.wouldPay! < wouldPayTarget) &&
        input.proTapped == 0) {
      return ProofOfValueCopy.recommendationStrengthenPro;
    }
    return ProofOfValueCopy.recommendationWidenBeta;
  }

  static ProofOfValueSummaryState _resolveSummaryState({
    required ProofOfValueInput input,
    required List<ProofOfValueRow> rows,
    required String recommendation,
    required int firstSaveTarget,
    required int secondSaveTarget,
    required int firstProofTarget,
    required int coreValueYesTarget,
    required int wouldKeepUsingTarget,
    required int wouldPayTarget,
  }) {
    if (_notEnoughTesterEvidence(input)) {
      return ProofOfValueSummaryState.notEnoughEvidence;
    }
    if (input.firstMomentSaved < firstSaveTarget ||
        input.secondMomentSaved < secondSaveTarget) {
      return ProofOfValueSummaryState.activationNotProven;
    }
    if (input.firstProofReached < firstProofTarget) {
      return ProofOfValueSummaryState.firstProofNotProven;
    }
    if (!_specificityProven(input, coreValueYesTarget) ||
        _genericWarning(input, firstProofTarget)) {
      return ProofOfValueSummaryState.specificityNotProven;
    }
    if (input.wouldKeepUsing == null || input.wouldKeepUsing! < wouldKeepUsingTarget) {
      return ProofOfValueSummaryState.retentionNotProven;
    }
    if ((input.wouldPay == null || input.wouldPay! < wouldPayTarget) &&
        input.proTapped == 0) {
      return ProofOfValueSummaryState.paymentNotProven;
    }
    if (recommendation == ProofOfValueCopy.recommendationWidenBeta) {
      return ProofOfValueSummaryState.strong;
    }
    return ProofOfValueSummaryState.emerging;
  }

  static String _summaryFor(ProofOfValueSummaryState state) => switch (state) {
        ProofOfValueSummaryState.notEnoughEvidence =>
          ProofOfValueCopy.summaryNotEnoughEvidence,
        ProofOfValueSummaryState.activationNotProven =>
          ProofOfValueCopy.summaryActivationNotProven,
        ProofOfValueSummaryState.firstProofNotProven =>
          ProofOfValueCopy.summaryFirstProofNotProven,
        ProofOfValueSummaryState.specificityNotProven =>
          ProofOfValueCopy.summarySpecificityNotProven,
        ProofOfValueSummaryState.retentionNotProven =>
          ProofOfValueCopy.summaryRetentionNotProven,
        ProofOfValueSummaryState.paymentNotProven =>
          ProofOfValueCopy.summaryPaymentNotProven,
        ProofOfValueSummaryState.emerging => ProofOfValueCopy.summaryEmerging,
        ProofOfValueSummaryState.strong => ProofOfValueCopy.summaryStrong,
      };
}
