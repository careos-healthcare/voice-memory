import 'package:archiveme_mobile/features/paid_intent_beta_proof/paid_intent_beta_proof.dart';
import 'package:archiveme_mobile/features/payment_proof_beta/payment_proof_beta_copy.dart';

/// Payment proof beta instrument — concrete beta payment evidence.
abstract final class PaymentProofBetaInstrument {
  PaymentProofBetaInstrument._();

  static const signalCount = 15;

  static PaymentProofBetaResult build(PaymentProofBetaInput input) {
    final signals = _buildSignals(input);
    final decision = _resolveDecision(input);
    return PaymentProofBetaResult(
      decision: decision,
      message: PaymentProofBetaCopy.messageFor(decision),
      recommendation: PaymentProofBetaCopy.recommendationFor(decision),
      signals: signals,
      earliestGap: _earliestGap(input, decision),
      hasPaymentProof: countsAsPaymentProof(decision),
      blocksPaidInterpretation: blocksPaidInterpretation(decision),
      maybeCountedAsPaymentProof: false,
    );
  }

  static PaymentProofBetaReport report(PaymentProofBetaResult result) =>
      PaymentProofBetaReport(
        headline: PaymentProofBetaCopy.headline,
        body: PaymentProofBetaCopy.body,
        trackedLine: PaymentProofBetaCopy.trackedLine,
        guardrail: PaymentProofBetaCopy.guardrail,
        result: result,
      );

  static bool countsAsPaymentProof(PaymentProofBetaDecision decision) =>
      decision == PaymentProofBetaDecision.purchaseProof ||
      decision == PaymentProofBetaDecision.restoreProof;

  static bool blocksPaidInterpretation(PaymentProofBetaDecision decision) =>
      decision == PaymentProofBetaDecision.proofNotReached ||
      decision == PaymentProofBetaDecision.interestOnly;

  static PaymentProofBetaInput fromPaidIntentBetaProof(
    PaidIntentBetaProofInput input, {
    bool secondSave = false,
    bool proofCorrected = false,
    bool restoreCompleted = false,
    bool entitlementActive = false,
  }) => PaymentProofBetaInput(
    firstSave: input.firstSaveCompleted,
    secondSave: secondSave || input.firstUsefulProofSeen,
    firstUsefulProofSeen: input.firstUsefulProofSeen,
    proofAccepted: input.proofAcceptedOrCorrected && !proofCorrected,
    proofCorrected: proofCorrected,
    proPromiseSeen: input.proPromiseSeen,
    proTapped: input.proTapped,
    purchaseStarted: input.purchaseAttempted,
    purchaseCompleted: input.purchaseCompleted,
    restoreStarted: input.restoreAttempted,
    restoreCompleted: restoreCompleted,
    entitlementActive: entitlementActive || input.purchaseCompleted,
    testerWouldPayYes: input.testerWouldPay == PaidIntentBetaWouldPay.yes,
    testerWouldPayMaybe: input.testerWouldPay == PaidIntentBetaWouldPay.maybe,
    testerWouldPayNo: input.testerWouldPay == PaidIntentBetaWouldPay.no,
  );

  static bool _hasActionSignals(PaymentProofBetaInput input) =>
      input.proTapped ||
      input.purchaseStarted ||
      input.purchaseCompleted ||
      input.restoreStarted ||
      input.restoreCompleted;

  static bool _proofUseful(PaymentProofBetaInput input) =>
      input.proofAccepted || input.proofCorrected;

  static PaymentProofBetaDecision _resolveDecision(
    PaymentProofBetaInput input,
  ) {
    if (input.restoreCompleted) {
      return PaymentProofBetaDecision.restoreProof;
    }
    if (input.purchaseCompleted) {
      return PaymentProofBetaDecision.purchaseProof;
    }
    if (input.purchaseStarted) {
      return PaymentProofBetaDecision.purchaseIntent;
    }
    if (input.proTapped) {
      if (!input.firstUsefulProofSeen) {
        return PaymentProofBetaDecision.proofNotReached;
      }
      return PaymentProofBetaDecision.proCuriosity;
    }

    if (!input.firstUsefulProofSeen) {
      if (input.testerWouldPayMaybe && !_hasActionSignals(input)) {
        return PaymentProofBetaDecision.interestOnly;
      }
      return PaymentProofBetaDecision.proofNotReached;
    }

    if (_proofUseful(input) && input.proPromiseSeen && !input.proTapped) {
      if (input.testerWouldPayYes) {
        return PaymentProofBetaDecision.paidIntentPromising;
      }
      if (input.testerWouldPayNo) {
        return PaymentProofBetaDecision.paidIntentWeak;
      }
      return PaymentProofBetaDecision.proofReachedNoProTap;
    }

    if (input.testerWouldPayYes) {
      return PaymentProofBetaDecision.paidIntentPromising;
    }
    if (input.testerWouldPayNo) {
      return PaymentProofBetaDecision.paidIntentWeak;
    }
    if (input.testerWouldPayMaybe) {
      return PaymentProofBetaDecision.interestOnly;
    }

    if (!_proofUseful(input)) {
      return PaymentProofBetaDecision.proofNotReached;
    }

    return PaymentProofBetaDecision.proofNotReached;
  }

  static PaymentProofBetaSignalId? _earliestGap(
    PaymentProofBetaInput input,
    PaymentProofBetaDecision decision,
  ) {
    return switch (decision) {
      PaymentProofBetaDecision.proofNotReached =>
        !input.firstSave
            ? PaymentProofBetaSignalId.firstSave
            : !input.secondSave
            ? PaymentProofBetaSignalId.secondSave
            : PaymentProofBetaSignalId.firstUsefulProofSeen,
      PaymentProofBetaDecision.interestOnly =>
        PaymentProofBetaSignalId.firstUsefulProofSeen,
      PaymentProofBetaDecision.proofReachedNoProTap =>
        PaymentProofBetaSignalId.proTapped,
      PaymentProofBetaDecision.proCuriosity =>
        PaymentProofBetaSignalId.purchaseStarted,
      PaymentProofBetaDecision.purchaseIntent =>
        PaymentProofBetaSignalId.purchaseCompleted,
      PaymentProofBetaDecision.purchaseProof => null,
      PaymentProofBetaDecision.restoreProof => null,
      PaymentProofBetaDecision.paidIntentPromising =>
        PaymentProofBetaSignalId.proTapped,
      PaymentProofBetaDecision.paidIntentWeak =>
        PaymentProofBetaSignalId.proTapped,
    };
  }

  static List<PaymentProofBetaSignal> _buildSignals(
    PaymentProofBetaInput input,
  ) {
    PaymentProofBetaSignalStatus statusFor({
      required bool prerequisite,
      required bool value,
    }) {
      if (!prerequisite) return PaymentProofBetaSignalStatus.blocked;
      return value
          ? PaymentProofBetaSignalStatus.pass
          : PaymentProofBetaSignalStatus.fail;
    }

    PaymentProofBetaSignalStatus trackedStatus(bool value) => value
        ? PaymentProofBetaSignalStatus.pass
        : PaymentProofBetaSignalStatus.tracked;

    String detailFor(PaymentProofBetaSignalStatus status) => switch (status) {
      PaymentProofBetaSignalStatus.pass => PaymentProofBetaCopy.detailObserved,
      PaymentProofBetaSignalStatus.fail => PaymentProofBetaCopy.detailMissing,
      PaymentProofBetaSignalStatus.blocked =>
        PaymentProofBetaCopy.detailBlocked,
      PaymentProofBetaSignalStatus.interestOnly =>
        PaymentProofBetaCopy.detailInterestOnly,
      PaymentProofBetaSignalStatus.tracked =>
        PaymentProofBetaCopy.detailTracked,
    };

    final saveOk = input.firstSave;
    final secondSaveOk = saveOk && input.secondSave;
    final proofSeenOk = secondSaveOk && input.firstUsefulProofSeen;
    final proofUsefulOk = proofSeenOk && _proofUseful(input);
    final proSeenOk = proofUsefulOk && input.proPromiseSeen;
    final proTappedOk = proSeenOk && input.proTapped;
    final purchaseStartedOk = proTappedOk && input.purchaseStarted;
    final purchaseCompletedOk = purchaseStartedOk && input.purchaseCompleted;
    final restoreStartedOk = proTappedOk && input.restoreStarted;
    final restoreCompletedOk = restoreStartedOk && input.restoreCompleted;

    return [
      _signal(
        id: PaymentProofBetaSignalId.firstSave,
        status: statusFor(prerequisite: true, value: input.firstSave),
        detailLabel: detailFor(
          statusFor(prerequisite: true, value: input.firstSave),
        ),
      ),
      _signal(
        id: PaymentProofBetaSignalId.secondSave,
        status: statusFor(prerequisite: saveOk, value: input.secondSave),
        detailLabel: detailFor(
          statusFor(prerequisite: saveOk, value: input.secondSave),
        ),
      ),
      _signal(
        id: PaymentProofBetaSignalId.firstUsefulProofSeen,
        status: statusFor(
          prerequisite: secondSaveOk,
          value: input.firstUsefulProofSeen,
        ),
        detailLabel: detailFor(
          statusFor(
            prerequisite: secondSaveOk,
            value: input.firstUsefulProofSeen,
          ),
        ),
      ),
      _signal(
        id: PaymentProofBetaSignalId.proofAccepted,
        status: statusFor(
          prerequisite: proofSeenOk,
          value: input.proofAccepted,
        ),
        detailLabel: detailFor(
          statusFor(prerequisite: proofSeenOk, value: input.proofAccepted),
        ),
      ),
      _signal(
        id: PaymentProofBetaSignalId.proofCorrected,
        status: statusFor(
          prerequisite: proofSeenOk,
          value: input.proofCorrected,
        ),
        detailLabel: detailFor(
          statusFor(prerequisite: proofSeenOk, value: input.proofCorrected),
        ),
      ),
      _signal(
        id: PaymentProofBetaSignalId.proPromiseSeen,
        status: statusFor(
          prerequisite: proofUsefulOk,
          value: input.proPromiseSeen,
        ),
        detailLabel: detailFor(
          statusFor(prerequisite: proofUsefulOk, value: input.proPromiseSeen),
        ),
      ),
      _signal(
        id: PaymentProofBetaSignalId.proTapped,
        status: statusFor(prerequisite: proSeenOk, value: input.proTapped),
        detailLabel: detailFor(
          statusFor(prerequisite: proSeenOk, value: input.proTapped),
        ),
      ),
      _signal(
        id: PaymentProofBetaSignalId.purchaseStarted,
        status: statusFor(
          prerequisite: proTappedOk,
          value: input.purchaseStarted,
        ),
        detailLabel: detailFor(
          statusFor(prerequisite: proTappedOk, value: input.purchaseStarted),
        ),
      ),
      _signal(
        id: PaymentProofBetaSignalId.purchaseCompleted,
        status: statusFor(
          prerequisite: purchaseStartedOk,
          value: input.purchaseCompleted,
        ),
        detailLabel: detailFor(
          statusFor(
            prerequisite: purchaseStartedOk,
            value: input.purchaseCompleted,
          ),
        ),
      ),
      _signal(
        id: PaymentProofBetaSignalId.restoreStarted,
        status: statusFor(
          prerequisite: proTappedOk,
          value: input.restoreStarted,
        ),
        detailLabel: detailFor(
          statusFor(prerequisite: proTappedOk, value: input.restoreStarted),
        ),
      ),
      _signal(
        id: PaymentProofBetaSignalId.restoreCompleted,
        status: statusFor(
          prerequisite: restoreStartedOk,
          value: input.restoreCompleted,
        ),
        detailLabel: detailFor(
          statusFor(
            prerequisite: restoreStartedOk,
            value: input.restoreCompleted,
          ),
        ),
      ),
      _signal(
        id: PaymentProofBetaSignalId.entitlementActive,
        status: statusFor(
          prerequisite: purchaseCompletedOk || restoreCompletedOk,
          value: input.entitlementActive,
        ),
        detailLabel: detailFor(
          statusFor(
            prerequisite: purchaseCompletedOk || restoreCompletedOk,
            value: input.entitlementActive,
          ),
        ),
      ),
      _signal(
        id: PaymentProofBetaSignalId.testerWouldPayYes,
        status: trackedStatus(input.testerWouldPayYes),
        detailLabel: input.testerWouldPayYes
            ? PaymentProofBetaCopy.detailObserved
            : PaymentProofBetaCopy.detailTracked,
      ),
      _signal(
        id: PaymentProofBetaSignalId.testerWouldPayMaybe,
        status: input.testerWouldPayMaybe
            ? PaymentProofBetaSignalStatus.interestOnly
            : PaymentProofBetaSignalStatus.tracked,
        detailLabel: input.testerWouldPayMaybe
            ? PaymentProofBetaCopy.detailInterestOnly
            : PaymentProofBetaCopy.detailTracked,
      ),
      _signal(
        id: PaymentProofBetaSignalId.testerWouldPayNo,
        status: trackedStatus(input.testerWouldPayNo),
        detailLabel: input.testerWouldPayNo
            ? PaymentProofBetaCopy.detailObserved
            : PaymentProofBetaCopy.detailTracked,
      ),
    ];
  }

  static PaymentProofBetaSignal _signal({
    required PaymentProofBetaSignalId id,
    required PaymentProofBetaSignalStatus status,
    required String detailLabel,
  }) => PaymentProofBetaSignal(
    id: id,
    label: PaymentProofBetaCopy.labelFor(id),
    status: status,
    detailLabel: detailLabel,
  );
}

class PaymentProofBetaInput {
  const PaymentProofBetaInput({
    this.firstSave = false,
    this.secondSave = false,
    this.firstUsefulProofSeen = false,
    this.proofAccepted = false,
    this.proofCorrected = false,
    this.proPromiseSeen = false,
    this.proTapped = false,
    this.purchaseStarted = false,
    this.purchaseCompleted = false,
    this.restoreStarted = false,
    this.restoreCompleted = false,
    this.entitlementActive = false,
    this.testerWouldPayYes = false,
    this.testerWouldPayMaybe = false,
    this.testerWouldPayNo = false,
  });

  final bool firstSave;
  final bool secondSave;
  final bool firstUsefulProofSeen;
  final bool proofAccepted;
  final bool proofCorrected;
  final bool proPromiseSeen;
  final bool proTapped;
  final bool purchaseStarted;
  final bool purchaseCompleted;
  final bool restoreStarted;
  final bool restoreCompleted;
  final bool entitlementActive;
  final bool testerWouldPayYes;
  final bool testerWouldPayMaybe;
  final bool testerWouldPayNo;
}

class PaymentProofBetaSignal {
  const PaymentProofBetaSignal({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final PaymentProofBetaSignalId id;
  final String label;
  final PaymentProofBetaSignalStatus status;
  final String detailLabel;
}

class PaymentProofBetaResult {
  const PaymentProofBetaResult({
    required this.decision,
    required this.message,
    required this.recommendation,
    required this.signals,
    required this.earliestGap,
    required this.hasPaymentProof,
    required this.blocksPaidInterpretation,
    required this.maybeCountedAsPaymentProof,
  });

  final PaymentProofBetaDecision decision;
  final String message;
  final String recommendation;
  final List<PaymentProofBetaSignal> signals;
  final PaymentProofBetaSignalId? earliestGap;
  final bool hasPaymentProof;
  final bool blocksPaidInterpretation;
  final bool maybeCountedAsPaymentProof;
}

class PaymentProofBetaReport {
  const PaymentProofBetaReport({
    required this.headline,
    required this.body,
    required this.trackedLine,
    required this.guardrail,
    required this.result,
  });

  final String headline;
  final String body;
  final String trackedLine;
  final String guardrail;
  final PaymentProofBetaResult result;
}