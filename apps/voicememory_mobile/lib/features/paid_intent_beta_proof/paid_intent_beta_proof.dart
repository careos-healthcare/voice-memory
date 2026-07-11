import '../paid_intent/paid_intent_confirmation_models.dart';
import 'paid_intent_beta_proof_copy.dart';

/// Paid intent beta proof — measure real paid intent after first useful proof.
abstract final class PaidIntentBetaProof {
  PaidIntentBetaProof._();

  static PaidIntentBetaProofResult build(PaidIntentBetaProofInput input) {
    final signals = _buildSignals(input);
    final decision = _resolveDecision(input);
    return PaidIntentBetaProofResult(
      decision: decision,
      message: _messageFor(decision),
      signals: signals,
      earliestGap: _earliestGap(input),
      paidIntentSignalWeak: isPaidIntentSignalWeak(decision),
      paidIntentSignalPromising: decision == PaidIntentBetaProofDecision.paidIntentPromising,
    );
  }

  static PaidIntentBetaProofReport report(PaidIntentBetaProofResult result) =>
      PaidIntentBetaProofReport(
        headline: PaidIntentBetaProofCopy.headline,
        body: PaidIntentBetaProofCopy.body,
        trackedLine: PaidIntentBetaProofCopy.trackedLine,
        guardrail: PaidIntentBetaProofCopy.guardrail,
        result: result,
      );

  static PaidIntentBetaProofInput fromWouldPayResponseId(String? responseId) =>
      PaidIntentBetaProofInput(
        testerWouldPay: wouldPayFromResponseId(responseId),
      );

  static PaidIntentBetaWouldPay? wouldPayFromResponseId(String? responseId) {
    if (responseId == null || responseId.isEmpty) return null;
    return switch (responseId) {
      PaidIntentConfirmationResponseIds.yes999 => PaidIntentBetaWouldPay.yes,
      PaidIntentConfirmationResponseIds.maybe => PaidIntentBetaWouldPay.maybe,
      PaidIntentConfirmationResponseIds.no => PaidIntentBetaWouldPay.no,
      PaidIntentConfirmationResponseIds.notYet => PaidIntentBetaWouldPay.notYet,
      _ => null,
    };
  }

  static PaidIntentBetaProofInput fromAttribution({
    bool firstSaveCompleted = false,
    bool firstUsefulProofSeen = false,
    bool proofAcceptedOrCorrected = false,
    bool proPromiseSeen = false,
    bool proTapped = false,
    bool purchaseAttempted = false,
    bool purchaseCompleted = false,
    bool restoreAttempted = false,
    bool purchaseMechanicsBlocked = false,
    PaidIntentBetaWouldPay? testerWouldPay,
  }) =>
      PaidIntentBetaProofInput(
        firstSaveCompleted: firstSaveCompleted,
        firstUsefulProofSeen: firstUsefulProofSeen,
        proofAcceptedOrCorrected: proofAcceptedOrCorrected,
        proPromiseSeen: proPromiseSeen,
        proTapped: proTapped,
        purchaseAttempted: purchaseAttempted,
        purchaseCompleted: purchaseCompleted,
        restoreAttempted: restoreAttempted,
        purchaseMechanicsBlocked: purchaseMechanicsBlocked,
        testerWouldPay: testerWouldPay,
      );

  static bool isPaidIntentSignalWeak(PaidIntentBetaProofDecision decision) =>
      switch (decision) {
        PaidIntentBetaProofDecision.insufficientData => true,
        PaidIntentBetaProofDecision.proofNotReached => true,
        PaidIntentBetaProofDecision.proofNotUseful => true,
        PaidIntentBetaProofDecision.proNotSeen => true,
        PaidIntentBetaProofDecision.proNotTapped => true,
        PaidIntentBetaProofDecision.purchaseBlocked => true,
        PaidIntentBetaProofDecision.paidIntentWeak => true,
        PaidIntentBetaProofDecision.paidIntentPromising => false,
      };

  static List<PaidIntentBetaProofSignal> _buildSignals(
    PaidIntentBetaProofInput input,
  ) {
    PaidIntentBetaProofSignalStatus statusFor({
      required bool prerequisite,
      required bool value,
      bool trackedOnly = false,
    }) {
      if (trackedOnly) {
        return value
            ? PaidIntentBetaProofSignalStatus.pass
            : PaidIntentBetaProofSignalStatus.notRequired;
      }
      if (!prerequisite) return PaidIntentBetaProofSignalStatus.blocked;
      return value
          ? PaidIntentBetaProofSignalStatus.pass
          : PaidIntentBetaProofSignalStatus.fail;
    }

    final saveOk = input.firstSaveCompleted;
    final proofSeenOk = saveOk && input.firstUsefulProofSeen;
    final proofUsefulOk = proofSeenOk && input.proofAcceptedOrCorrected;
    final proSeenOk = proofUsefulOk && input.proPromiseSeen;
    final proTappedOk = proSeenOk && input.proTapped;
    final purchaseAttemptedOk = proTappedOk && input.purchaseAttempted;

    return [
      PaidIntentBetaProofSignal(
        id: PaidIntentBetaProofSignalId.firstSaveCompleted,
        label: PaidIntentBetaProofCopy.signalFirstSaveCompleted,
        status: statusFor(prerequisite: true, value: input.firstSaveCompleted),
        detailLabel: input.firstSaveCompleted
            ? PaidIntentBetaProofCopy.detailPass
            : PaidIntentBetaProofCopy.detailPending,
      ),
      PaidIntentBetaProofSignal(
        id: PaidIntentBetaProofSignalId.firstUsefulProofSeen,
        label: PaidIntentBetaProofCopy.signalFirstUsefulProofSeen,
        status: statusFor(prerequisite: saveOk, value: input.firstUsefulProofSeen),
        detailLabel: !saveOk
            ? PaidIntentBetaProofCopy.detailBlocked
            : input.firstUsefulProofSeen
                ? PaidIntentBetaProofCopy.detailPass
                : PaidIntentBetaProofCopy.detailPending,
      ),
      PaidIntentBetaProofSignal(
        id: PaidIntentBetaProofSignalId.proofAcceptedOrCorrected,
        label: PaidIntentBetaProofCopy.signalProofAcceptedOrCorrected,
        status: statusFor(
          prerequisite: proofSeenOk,
          value: input.proofAcceptedOrCorrected,
        ),
        detailLabel: !proofSeenOk
            ? PaidIntentBetaProofCopy.detailBlocked
            : input.proofAcceptedOrCorrected
                ? PaidIntentBetaProofCopy.detailPass
                : PaidIntentBetaProofCopy.detailFail,
      ),
      PaidIntentBetaProofSignal(
        id: PaidIntentBetaProofSignalId.proPromiseSeen,
        label: PaidIntentBetaProofCopy.signalProPromiseSeen,
        status: statusFor(prerequisite: proofUsefulOk, value: input.proPromiseSeen),
        detailLabel: !proofUsefulOk
            ? PaidIntentBetaProofCopy.detailBlocked
            : input.proPromiseSeen
                ? PaidIntentBetaProofCopy.detailPass
                : PaidIntentBetaProofCopy.detailPending,
      ),
      PaidIntentBetaProofSignal(
        id: PaidIntentBetaProofSignalId.proTapped,
        label: PaidIntentBetaProofCopy.signalProTapped,
        status: statusFor(prerequisite: proSeenOk, value: input.proTapped),
        detailLabel: !proSeenOk
            ? PaidIntentBetaProofCopy.detailBlocked
            : input.proTapped
                ? PaidIntentBetaProofCopy.detailPass
                : PaidIntentBetaProofCopy.detailPending,
      ),
      PaidIntentBetaProofSignal(
        id: PaidIntentBetaProofSignalId.purchaseAttempted,
        label: PaidIntentBetaProofCopy.signalPurchaseAttempted,
        status: statusFor(prerequisite: proTappedOk, value: input.purchaseAttempted),
        detailLabel: !proTappedOk
            ? PaidIntentBetaProofCopy.detailBlocked
            : input.purchaseAttempted
                ? PaidIntentBetaProofCopy.detailPass
                : PaidIntentBetaProofCopy.detailPending,
      ),
      PaidIntentBetaProofSignal(
        id: PaidIntentBetaProofSignalId.purchaseCompleted,
        label: PaidIntentBetaProofCopy.signalPurchaseCompleted,
        status: statusFor(
          prerequisite: purchaseAttemptedOk,
          value: input.purchaseCompleted,
        ),
        detailLabel: !purchaseAttemptedOk
            ? PaidIntentBetaProofCopy.detailBlocked
            : input.purchaseCompleted
                ? PaidIntentBetaProofCopy.detailPass
                : PaidIntentBetaProofCopy.detailPending,
      ),
      PaidIntentBetaProofSignal(
        id: PaidIntentBetaProofSignalId.restoreAttempted,
        label: PaidIntentBetaProofCopy.signalRestoreAttempted,
        status: statusFor(
          prerequisite: proTappedOk,
          value: input.restoreAttempted,
          trackedOnly: true,
        ),
        detailLabel: input.restoreAttempted
            ? PaidIntentBetaProofCopy.detailPass
            : PaidIntentBetaProofCopy.detailNotRequired,
      ),
      PaidIntentBetaProofSignal(
        id: PaidIntentBetaProofSignalId.testerWouldPay,
        label: PaidIntentBetaProofCopy.signalTesterWouldPay,
        status: _wouldPayStatus(input),
        detailLabel: _wouldPayDetail(input),
      ),
    ];
  }

  static PaidIntentBetaProofSignalStatus _wouldPayStatus(
    PaidIntentBetaProofInput input,
  ) {
    final response = input.testerWouldPay;
    if (response == null) return PaidIntentBetaProofSignalStatus.pending;
    return switch (response) {
      PaidIntentBetaWouldPay.yes || PaidIntentBetaWouldPay.maybe =>
        PaidIntentBetaProofSignalStatus.pass,
      PaidIntentBetaWouldPay.no || PaidIntentBetaWouldPay.notYet =>
        PaidIntentBetaProofSignalStatus.fail,
    };
  }

  static String _wouldPayDetail(PaidIntentBetaProofInput input) {
    return switch (input.testerWouldPay) {
      PaidIntentBetaWouldPay.yes => 'Would pay yes',
      PaidIntentBetaWouldPay.maybe => 'Would pay maybe',
      PaidIntentBetaWouldPay.no => 'Would pay no',
      PaidIntentBetaWouldPay.notYet => 'Not yet answered',
      null => PaidIntentBetaProofCopy.detailPending,
    };
  }

  static PaidIntentBetaProofDecision _resolveDecision(
    PaidIntentBetaProofInput input,
  ) {
    if (!input.firstSaveCompleted && !_hasAnySignal(input)) {
      return PaidIntentBetaProofDecision.insufficientData;
    }

    if (!input.firstSaveCompleted) {
      return PaidIntentBetaProofDecision.insufficientData;
    }

    if (!input.firstUsefulProofSeen) {
      return PaidIntentBetaProofDecision.proofNotReached;
    }

    if (!input.proofAcceptedOrCorrected) {
      return PaidIntentBetaProofDecision.proofNotUseful;
    }

    if (!input.proPromiseSeen) {
      return PaidIntentBetaProofDecision.proNotSeen;
    }

    if (!input.proTapped) {
      return PaidIntentBetaProofDecision.proNotTapped;
    }

    if (input.purchaseCompleted) {
      return PaidIntentBetaProofDecision.paidIntentPromising;
    }

    if (input.purchaseAttempted &&
        !input.purchaseCompleted &&
        input.purchaseMechanicsBlocked) {
      return PaidIntentBetaProofDecision.purchaseBlocked;
    }

    if (input.testerWouldPay == PaidIntentBetaWouldPay.yes ||
        input.testerWouldPay == PaidIntentBetaWouldPay.maybe) {
      return PaidIntentBetaProofDecision.paidIntentPromising;
    }

    if (input.testerWouldPay == PaidIntentBetaWouldPay.no) {
      return PaidIntentBetaProofDecision.paidIntentWeak;
    }

    if (input.purchaseAttempted && !input.purchaseCompleted) {
      return PaidIntentBetaProofDecision.paidIntentWeak;
    }

    if (input.testerWouldPay == null ||
        input.testerWouldPay == PaidIntentBetaWouldPay.notYet) {
      return PaidIntentBetaProofDecision.insufficientData;
    }

    return PaidIntentBetaProofDecision.paidIntentWeak;
  }

  static bool _hasAnySignal(PaidIntentBetaProofInput input) =>
      input.firstUsefulProofSeen ||
      input.proofAcceptedOrCorrected ||
      input.proPromiseSeen ||
      input.proTapped ||
      input.purchaseAttempted ||
      input.purchaseCompleted ||
      input.restoreAttempted ||
      input.testerWouldPay != null;

  static PaidIntentBetaProofSignalId? _earliestGap(
    PaidIntentBetaProofInput input,
  ) {
    if (!input.firstSaveCompleted) {
      return PaidIntentBetaProofSignalId.firstSaveCompleted;
    }
    if (!input.firstUsefulProofSeen) {
      return PaidIntentBetaProofSignalId.firstUsefulProofSeen;
    }
    if (!input.proofAcceptedOrCorrected) {
      return PaidIntentBetaProofSignalId.proofAcceptedOrCorrected;
    }
    if (!input.proPromiseSeen) {
      return PaidIntentBetaProofSignalId.proPromiseSeen;
    }
    if (!input.proTapped) {
      return PaidIntentBetaProofSignalId.proTapped;
    }
    if (input.testerWouldPay == null) {
      return PaidIntentBetaProofSignalId.testerWouldPay;
    }
    if (!input.purchaseAttempted) {
      return PaidIntentBetaProofSignalId.purchaseAttempted;
    }
    if (!input.purchaseCompleted && input.purchaseMechanicsBlocked) {
      return PaidIntentBetaProofSignalId.purchaseCompleted;
    }
    return null;
  }

  static String _messageFor(PaidIntentBetaProofDecision decision) =>
      switch (decision) {
        PaidIntentBetaProofDecision.insufficientData =>
          PaidIntentBetaProofCopy.insufficientDataLine,
        PaidIntentBetaProofDecision.proofNotReached =>
          PaidIntentBetaProofCopy.proofNotReachedLine,
        PaidIntentBetaProofDecision.proofNotUseful =>
          PaidIntentBetaProofCopy.proofNotUsefulLine,
        PaidIntentBetaProofDecision.proNotSeen =>
          PaidIntentBetaProofCopy.proNotSeenLine,
        PaidIntentBetaProofDecision.proNotTapped =>
          PaidIntentBetaProofCopy.proNotTappedLine,
        PaidIntentBetaProofDecision.purchaseBlocked =>
          PaidIntentBetaProofCopy.purchaseBlockedLine,
        PaidIntentBetaProofDecision.paidIntentWeak =>
          PaidIntentBetaProofCopy.paidIntentWeakLine,
        PaidIntentBetaProofDecision.paidIntentPromising =>
          PaidIntentBetaProofCopy.paidIntentPromisingLine,
      };
}

enum PaidIntentBetaProofSignalId {
  firstSaveCompleted,
  firstUsefulProofSeen,
  proofAcceptedOrCorrected,
  proPromiseSeen,
  proTapped,
  purchaseAttempted,
  purchaseCompleted,
  restoreAttempted,
  testerWouldPay,
}

enum PaidIntentBetaProofSignalStatus {
  pass,
  fail,
  pending,
  blocked,
  notRequired,
}

enum PaidIntentBetaWouldPay {
  yes,
  maybe,
  no,
  notYet,
}

enum PaidIntentBetaProofDecision {
  insufficientData,
  proofNotReached,
  proofNotUseful,
  proNotSeen,
  proNotTapped,
  purchaseBlocked,
  paidIntentWeak,
  paidIntentPromising,
}

class PaidIntentBetaProofInput {
  const PaidIntentBetaProofInput({
    this.firstSaveCompleted = false,
    this.firstUsefulProofSeen = false,
    this.proofAcceptedOrCorrected = false,
    this.proPromiseSeen = false,
    this.proTapped = false,
    this.purchaseAttempted = false,
    this.purchaseCompleted = false,
    this.restoreAttempted = false,
    this.purchaseMechanicsBlocked = false,
    this.testerWouldPay,
  });

  final bool firstSaveCompleted;
  final bool firstUsefulProofSeen;
  final bool proofAcceptedOrCorrected;
  final bool proPromiseSeen;
  final bool proTapped;
  final bool purchaseAttempted;
  final bool purchaseCompleted;
  final bool restoreAttempted;
  final bool purchaseMechanicsBlocked;
  final PaidIntentBetaWouldPay? testerWouldPay;
}

class PaidIntentBetaProofSignal {
  const PaidIntentBetaProofSignal({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final PaidIntentBetaProofSignalId id;
  final String label;
  final PaidIntentBetaProofSignalStatus status;
  final String detailLabel;
}

class PaidIntentBetaProofResult {
  const PaidIntentBetaProofResult({
    required this.decision,
    required this.message,
    required this.signals,
    required this.earliestGap,
    required this.paidIntentSignalWeak,
    required this.paidIntentSignalPromising,
  });

  final PaidIntentBetaProofDecision decision;
  final String message;
  final List<PaidIntentBetaProofSignal> signals;
  final PaidIntentBetaProofSignalId? earliestGap;
  final bool paidIntentSignalWeak;
  final bool paidIntentSignalPromising;
}

class PaidIntentBetaProofReport {
  const PaidIntentBetaProofReport({
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
  final PaidIntentBetaProofResult result;

  List<String> get allDisplayedText => [
        headline,
        body,
        trackedLine,
        for (final signal in result.signals) ...[
          signal.label,
          signal.detailLabel,
        ],
        result.message,
      ];
}
