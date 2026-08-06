import '../paid_intent_beta_proof/paid_intent_beta_proof.dart';
import 'payment_proof_not_interest_gate_copy.dart';

/// Payment proof not interest gate — separate idea interest from payment proof.
abstract final class PaymentProofNotInterestGate {
  PaymentProofNotInterestGate._();

  static const signalCount = 10;

  static PaymentProofNotInterestGateResult build(
    PaymentProofNotInterestGateInput input,
  ) {
    final signals = _buildSignals(input);
    final decision = _resolveDecision(input);
    return PaymentProofNotInterestGateResult(
      decision: decision,
      message: PaymentProofNotInterestGateCopy.messageFor(decision),
      recommendation: PaymentProofNotInterestGateCopy.recommendationFor(
        decision,
      ),
      signals: signals,
      earliestGap: _earliestGap(input, decision),
      hasPaymentProof: countsAsPaymentProof(decision),
      isInterestOnly:
          decision == PaymentProofNotInterestGateDecision.interestOnly,
      maybeCountedAsPaymentProof: false,
    );
  }

  static PaymentProofNotInterestGateReport report(
    PaymentProofNotInterestGateResult result,
  ) => PaymentProofNotInterestGateReport(
    headline: PaymentProofNotInterestGateCopy.headline,
    body: PaymentProofNotInterestGateCopy.body,
    orderLine: PaymentProofNotInterestGateCopy.orderLine,
    guardrail: PaymentProofNotInterestGateCopy.guardrail,
    result: result,
  );

  static bool countsAsPaymentProof(
    PaymentProofNotInterestGateDecision decision,
  ) =>
      decision == PaymentProofNotInterestGateDecision.purchaseProof ||
      decision == PaymentProofNotInterestGateDecision.restoreProof;

  static PaymentProofNotInterestGateInput fromPaidIntentBetaProof(
    PaidIntentBetaProofInput input, {
    bool testerSaysIdeaInteresting = false,
    bool testerSaysWouldPayMaybe = false,
    bool testerAsksForPriceDetails = false,
    bool testerContinuesUsingAfterProof = false,
    bool testerRestoresPurchase = false,
  }) => PaymentProofNotInterestGateInput(
    testerSaysIdeaInteresting: testerSaysIdeaInteresting,
    testerSaysWouldPayMaybe:
        testerSaysWouldPayMaybe ||
        input.testerWouldPay == PaidIntentBetaWouldPay.maybe,
    testerSeesFirstUsefulProof: input.firstUsefulProofSeen,
    testerSeesProPromise: input.proPromiseSeen,
    testerTapsPro: input.proTapped,
    testerStartsPurchase: input.purchaseAttempted,
    testerCompletesSandboxPurchase: input.purchaseCompleted,
    testerRestoresPurchase: testerRestoresPurchase || input.restoreAttempted,
    testerAsksForPriceDetails: testerAsksForPriceDetails,
    testerContinuesUsingAfterProof: testerContinuesUsingAfterProof,
  );

  static bool _hasAnySignal(PaymentProofNotInterestGateInput input) =>
      input.testerSaysIdeaInteresting ||
      input.testerSaysWouldPayMaybe ||
      input.testerSeesFirstUsefulProof ||
      input.testerSeesProPromise ||
      input.testerTapsPro ||
      input.testerStartsPurchase ||
      input.testerCompletesSandboxPurchase ||
      input.testerRestoresPurchase ||
      input.testerAsksForPriceDetails ||
      input.testerContinuesUsingAfterProof;

  static bool _hasComprehension(PaymentProofNotInterestGateInput input) =>
      input.testerSeesFirstUsefulProof &&
      (input.testerSeesProPromise ||
          input.testerContinuesUsingAfterProof ||
          input.testerAsksForPriceDetails);

  static PaymentProofNotInterestGateDecision _resolveDecision(
    PaymentProofNotInterestGateInput input,
  ) {
    if (!_hasAnySignal(input)) {
      return PaymentProofNotInterestGateDecision.notEnoughPaymentEvidence;
    }

    if (input.testerRestoresPurchase) {
      return PaymentProofNotInterestGateDecision.restoreProof;
    }
    if (input.testerCompletesSandboxPurchase) {
      return PaymentProofNotInterestGateDecision.purchaseProof;
    }
    if (input.testerStartsPurchase) {
      return PaymentProofNotInterestGateDecision.purchaseIntent;
    }
    if (input.testerTapsPro) {
      return PaymentProofNotInterestGateDecision.proCuriosity;
    }
    if (_hasComprehension(input)) {
      return PaymentProofNotInterestGateDecision.comprehensionOnly;
    }
    if (input.testerSaysIdeaInteresting || input.testerSaysWouldPayMaybe) {
      return PaymentProofNotInterestGateDecision.interestOnly;
    }

    return PaymentProofNotInterestGateDecision.notEnoughPaymentEvidence;
  }

  static PaymentProofNotInterestGateSignalId? _earliestGap(
    PaymentProofNotInterestGateInput input,
    PaymentProofNotInterestGateDecision decision,
  ) {
    if (decision ==
        PaymentProofNotInterestGateDecision.notEnoughPaymentEvidence) {
      return PaymentProofNotInterestGateSignalId.testerSeesFirstUsefulProof;
    }
    if (decision == PaymentProofNotInterestGateDecision.interestOnly) {
      return PaymentProofNotInterestGateSignalId.testerSeesFirstUsefulProof;
    }
    if (decision == PaymentProofNotInterestGateDecision.comprehensionOnly) {
      return PaymentProofNotInterestGateSignalId.testerTapsPro;
    }
    if (decision == PaymentProofNotInterestGateDecision.proCuriosity) {
      return PaymentProofNotInterestGateSignalId.testerStartsPurchase;
    }
    if (decision == PaymentProofNotInterestGateDecision.purchaseIntent) {
      return PaymentProofNotInterestGateSignalId.testerCompletesSandboxPurchase;
    }
    if (decision == PaymentProofNotInterestGateDecision.purchaseProof) {
      return null;
    }
    if (decision == PaymentProofNotInterestGateDecision.restoreProof) {
      return null;
    }
    return null;
  }

  static List<PaymentProofNotInterestGateSignal> _buildSignals(
    PaymentProofNotInterestGateInput input,
  ) {
    PaymentProofNotInterestGateSignalStatus statusFor({
      required bool prerequisite,
      required bool value,
      bool interestOnlySignal = false,
    }) {
      if (!prerequisite) {
        return PaymentProofNotInterestGateSignalStatus.blocked;
      }
      if (!value) return PaymentProofNotInterestGateSignalStatus.fail;
      if (interestOnlySignal) {
        return PaymentProofNotInterestGateSignalStatus.interestOnly;
      }
      return PaymentProofNotInterestGateSignalStatus.pass;
    }

    String detailFor(PaymentProofNotInterestGateSignalStatus status) =>
        switch (status) {
          PaymentProofNotInterestGateSignalStatus.pass =>
            PaymentProofNotInterestGateCopy.detailObserved,
          PaymentProofNotInterestGateSignalStatus.fail =>
            PaymentProofNotInterestGateCopy.detailMissing,
          PaymentProofNotInterestGateSignalStatus.blocked =>
            PaymentProofNotInterestGateCopy.detailBlocked,
          PaymentProofNotInterestGateSignalStatus.interestOnly =>
            PaymentProofNotInterestGateCopy.detailInterestOnly,
        };

    final proofSeen = input.testerSeesFirstUsefulProof;
    final proSeen = proofSeen && input.testerSeesProPromise;
    final proTapped = proSeen && input.testerTapsPro;
    final purchaseStarted = proTapped && input.testerStartsPurchase;

    return [
      _signal(
        id: PaymentProofNotInterestGateSignalId.testerSaysIdeaInteresting,
        status: statusFor(
          prerequisite: true,
          value: input.testerSaysIdeaInteresting,
          interestOnlySignal: true,
        ),
        detailLabel: detailFor(
          statusFor(
            prerequisite: true,
            value: input.testerSaysIdeaInteresting,
            interestOnlySignal: true,
          ),
        ),
      ),
      _signal(
        id: PaymentProofNotInterestGateSignalId.testerSaysWouldPayMaybe,
        status: statusFor(
          prerequisite: true,
          value: input.testerSaysWouldPayMaybe,
          interestOnlySignal: true,
        ),
        detailLabel: detailFor(
          statusFor(
            prerequisite: true,
            value: input.testerSaysWouldPayMaybe,
            interestOnlySignal: true,
          ),
        ),
      ),
      _signal(
        id: PaymentProofNotInterestGateSignalId.testerSeesFirstUsefulProof,
        status: statusFor(
          prerequisite: true,
          value: input.testerSeesFirstUsefulProof,
        ),
        detailLabel: detailFor(
          statusFor(
            prerequisite: true,
            value: input.testerSeesFirstUsefulProof,
          ),
        ),
      ),
      _signal(
        id: PaymentProofNotInterestGateSignalId.testerSeesProPromise,
        status: statusFor(
          prerequisite: proofSeen,
          value: input.testerSeesProPromise,
        ),
        detailLabel: detailFor(
          statusFor(prerequisite: proofSeen, value: input.testerSeesProPromise),
        ),
      ),
      _signal(
        id: PaymentProofNotInterestGateSignalId.testerTapsPro,
        status: statusFor(prerequisite: proSeen, value: input.testerTapsPro),
        detailLabel: detailFor(
          statusFor(prerequisite: proSeen, value: input.testerTapsPro),
        ),
      ),
      _signal(
        id: PaymentProofNotInterestGateSignalId.testerStartsPurchase,
        status: statusFor(
          prerequisite: proTapped,
          value: input.testerStartsPurchase,
        ),
        detailLabel: detailFor(
          statusFor(prerequisite: proTapped, value: input.testerStartsPurchase),
        ),
      ),
      _signal(
        id: PaymentProofNotInterestGateSignalId.testerCompletesSandboxPurchase,
        status: statusFor(
          prerequisite: purchaseStarted,
          value: input.testerCompletesSandboxPurchase,
        ),
        detailLabel: detailFor(
          statusFor(
            prerequisite: purchaseStarted,
            value: input.testerCompletesSandboxPurchase,
          ),
        ),
      ),
      _signal(
        id: PaymentProofNotInterestGateSignalId.testerRestoresPurchase,
        status: statusFor(
          prerequisite: proTapped,
          value: input.testerRestoresPurchase,
        ),
        detailLabel: detailFor(
          statusFor(
            prerequisite: proTapped,
            value: input.testerRestoresPurchase,
          ),
        ),
      ),
      _signal(
        id: PaymentProofNotInterestGateSignalId.testerAsksForPriceDetails,
        status: statusFor(
          prerequisite: proofSeen,
          value: input.testerAsksForPriceDetails,
        ),
        detailLabel: detailFor(
          statusFor(
            prerequisite: proofSeen,
            value: input.testerAsksForPriceDetails,
          ),
        ),
      ),
      _signal(
        id: PaymentProofNotInterestGateSignalId.testerContinuesUsingAfterProof,
        status: statusFor(
          prerequisite: proofSeen,
          value: input.testerContinuesUsingAfterProof,
        ),
        detailLabel: detailFor(
          statusFor(
            prerequisite: proofSeen,
            value: input.testerContinuesUsingAfterProof,
          ),
        ),
      ),
    ];
  }

  static PaymentProofNotInterestGateSignal _signal({
    required PaymentProofNotInterestGateSignalId id,
    required PaymentProofNotInterestGateSignalStatus status,
    required String detailLabel,
  }) => PaymentProofNotInterestGateSignal(
    id: id,
    label: PaymentProofNotInterestGateCopy.labelFor(id),
    status: status,
    detailLabel: detailLabel,
  );
}

class PaymentProofNotInterestGateInput {
  const PaymentProofNotInterestGateInput({
    this.testerSaysIdeaInteresting = false,
    this.testerSaysWouldPayMaybe = false,
    this.testerSeesFirstUsefulProof = false,
    this.testerSeesProPromise = false,
    this.testerTapsPro = false,
    this.testerStartsPurchase = false,
    this.testerCompletesSandboxPurchase = false,
    this.testerRestoresPurchase = false,
    this.testerAsksForPriceDetails = false,
    this.testerContinuesUsingAfterProof = false,
  });

  final bool testerSaysIdeaInteresting;
  final bool testerSaysWouldPayMaybe;
  final bool testerSeesFirstUsefulProof;
  final bool testerSeesProPromise;
  final bool testerTapsPro;
  final bool testerStartsPurchase;
  final bool testerCompletesSandboxPurchase;
  final bool testerRestoresPurchase;
  final bool testerAsksForPriceDetails;
  final bool testerContinuesUsingAfterProof;
}

class PaymentProofNotInterestGateSignal {
  const PaymentProofNotInterestGateSignal({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final PaymentProofNotInterestGateSignalId id;
  final String label;
  final PaymentProofNotInterestGateSignalStatus status;
  final String detailLabel;
}

class PaymentProofNotInterestGateResult {
  const PaymentProofNotInterestGateResult({
    required this.decision,
    required this.message,
    required this.recommendation,
    required this.signals,
    required this.earliestGap,
    required this.hasPaymentProof,
    required this.isInterestOnly,
    required this.maybeCountedAsPaymentProof,
  });

  final PaymentProofNotInterestGateDecision decision;
  final String message;
  final String recommendation;
  final List<PaymentProofNotInterestGateSignal> signals;
  final PaymentProofNotInterestGateSignalId? earliestGap;
  final bool hasPaymentProof;
  final bool isInterestOnly;
  final bool maybeCountedAsPaymentProof;
}

class PaymentProofNotInterestGateReport {
  const PaymentProofNotInterestGateReport({
    required this.headline,
    required this.body,
    required this.orderLine,
    required this.guardrail,
    required this.result,
  });

  final String headline;
  final String body;
  final String orderLine;
  final String guardrail;
  final PaymentProofNotInterestGateResult result;
}
