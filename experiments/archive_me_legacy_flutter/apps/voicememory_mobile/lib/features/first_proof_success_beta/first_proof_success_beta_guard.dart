import '../archive_evidence/archive_evidence_quality_gate.dart';
import '../proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'first_proof_success_beta_copy.dart';

/// First proof success beta guard — measurement and prompt/input guidance only.
abstract final class FirstProofSuccessBetaGuard {
  FirstProofSuccessBetaGuard._();

  static const signalCount = 11;
  static const requiredUsableMoments =
      ArchiveEvidenceQualityGate.minProofEntryCount;

  static FirstProofSuccessBetaResult build(FirstProofSuccessBetaInput input) {
    final signals = _buildSignals(input);
    final decision = _resolveDecision(input);
    return FirstProofSuccessBetaResult(
      decision: decision,
      message: FirstProofSuccessBetaCopy.messageFor(decision),
      recommendation: FirstProofSuccessBetaCopy.recommendationFor(decision),
      signals: signals,
      earliestConcern: _earliestConcern(signals),
      proofWorking:
          decision == FirstProofSuccessBetaDecision.proofWorking ||
          decision == FirstProofSuccessBetaDecision.proofStrongEnoughForPro,
      thresholdsUnchanged: _thresholdsUnchanged(input),
    );
  }

  static FirstProofSuccessBetaReport report(
    FirstProofSuccessBetaResult result,
  ) => FirstProofSuccessBetaReport(
    headline: FirstProofSuccessBetaCopy.headline,
    body: FirstProofSuccessBetaCopy.body,
    orderLine: FirstProofSuccessBetaCopy.orderLine,
    guardrail: FirstProofSuccessBetaCopy.guardrail,
    result: result,
  );

  static bool detectProofThresholdStillThree(String gateSource) =>
      gateSource.contains('static const minProofEntryCount = 3;');

  static bool detectBetaReadinessStillGuardsThree(String betaReadinessSource) =>
      betaReadinessSource.contains(
        'ArchiveEvidenceQualityGate.minProofEntryCount != 3',
      );

  static FirstProofSuccessBetaInput fromRepoSignals({
    required String archiveEvidenceQualityGateSource,
    required String betaReadinessEngineSource,
    int usableMomentCount = requiredUsableMoments,
    bool hasSafeAnchor = true,
    bool hasMatchQuality = true,
    ProofConfidenceLevel? proofConfidence = ProofConfidenceLevel.strong,
    bool proofShown = true,
    bool proofAccepted = false,
    bool proofCorrected = false,
    bool tooVagueSelected = false,
    bool notRelevantSelected = false,
    bool userUnderstoodWhy = false,
    bool userSavedAnotherAfterProof = false,
    bool proPromiseSeen = false,
  }) => FirstProofSuccessBetaInput(
    usableMomentCount: usableMomentCount,
    hasSafeAnchor: hasSafeAnchor,
    hasMatchQuality: hasMatchQuality,
    proofConfidence: proofConfidence,
    proofShown: proofShown,
    proofAccepted: proofAccepted,
    proofCorrected: proofCorrected,
    tooVagueSelected: tooVagueSelected,
    notRelevantSelected: notRelevantSelected,
    userUnderstoodWhy: userUnderstoodWhy,
    userSavedAnotherAfterProof: userSavedAnotherAfterProof,
    proPromiseSeen: proPromiseSeen,
    proofThresholdStillThree: detectProofThresholdStillThree(
      archiveEvidenceQualityGateSource,
    ),
    betaReadinessStillGuardsThree: detectBetaReadinessStillGuardsThree(
      betaReadinessEngineSource,
    ),
  );

  static bool _thresholdsUnchanged(FirstProofSuccessBetaInput input) =>
      requiredUsableMoments == 3 &&
      input.proofThresholdStillThree &&
      input.betaReadinessStillGuardsThree;

  static bool _hasReachedProofAttempt(FirstProofSuccessBetaInput input) =>
      input.usableMomentCount >= requiredUsableMoments;

  static bool _isStrongConfidence(ProofConfidenceLevel? level) =>
      level == ProofConfidenceLevel.strong ||
      level == ProofConfidenceLevel.useful ||
      level == ProofConfidenceLevel.freshReturn ||
      level == ProofConfidenceLevel.corrected;

  static bool _isWeakConfidence(ProofConfidenceLevel? level) =>
      level == null ||
      level == ProofConfidenceLevel.watchOnly ||
      level == ProofConfidenceLevel.emerging;

  static bool _hasProofFeedback(FirstProofSuccessBetaInput input) =>
      input.proofAccepted ||
      input.proofCorrected ||
      input.tooVagueSelected ||
      input.notRelevantSelected;

  static bool _proofStrongEnoughForPro(FirstProofSuccessBetaInput input) =>
      input.proofAccepted &&
      input.proPromiseSeen &&
      input.userUnderstoodWhy &&
      input.hasSafeAnchor &&
      input.hasMatchQuality &&
      _isStrongConfidence(input.proofConfidence);

  static List<FirstProofSuccessBetaSignal> _buildSignals(
    FirstProofSuccessBetaInput input,
  ) {
    final reachedProof = _hasReachedProofAttempt(input);

    return [
      _signal(
        id: FirstProofSuccessBetaSignalId.usableMomentsReady,
        status: input.usableMomentCount >= requiredUsableMoments
            ? FirstProofSuccessBetaSignalStatus.pass
            : FirstProofSuccessBetaSignalStatus.concern,
      ),
      _signal(
        id: FirstProofSuccessBetaSignalId.safeAnchorPresent,
        status: !reachedProof
            ? FirstProofSuccessBetaSignalStatus.notObserved
            : input.hasSafeAnchor
            ? FirstProofSuccessBetaSignalStatus.pass
            : FirstProofSuccessBetaSignalStatus.concern,
      ),
      _signal(
        id: FirstProofSuccessBetaSignalId.matchQualityPresent,
        status: !reachedProof
            ? FirstProofSuccessBetaSignalStatus.notObserved
            : input.hasMatchQuality
            ? FirstProofSuccessBetaSignalStatus.pass
            : FirstProofSuccessBetaSignalStatus.concern,
      ),
      _signal(
        id: FirstProofSuccessBetaSignalId.proofConfidenceStrong,
        status: !reachedProof
            ? FirstProofSuccessBetaSignalStatus.notObserved
            : _isStrongConfidence(input.proofConfidence)
            ? FirstProofSuccessBetaSignalStatus.pass
            : FirstProofSuccessBetaSignalStatus.concern,
      ),
      _signal(
        id: FirstProofSuccessBetaSignalId.proofShown,
        status: !reachedProof
            ? FirstProofSuccessBetaSignalStatus.notObserved
            : input.proofShown
            ? FirstProofSuccessBetaSignalStatus.pass
            : FirstProofSuccessBetaSignalStatus.concern,
      ),
      _signal(
        id: FirstProofSuccessBetaSignalId.proofAccepted,
        status: !reachedProof || !input.proofShown
            ? FirstProofSuccessBetaSignalStatus.notObserved
            : input.proofAccepted
            ? FirstProofSuccessBetaSignalStatus.pass
            : FirstProofSuccessBetaSignalStatus.notObserved,
      ),
      _signal(
        id: FirstProofSuccessBetaSignalId.proofCorrected,
        status: !reachedProof || !input.proofShown
            ? FirstProofSuccessBetaSignalStatus.notObserved
            : input.proofCorrected
            ? FirstProofSuccessBetaSignalStatus.pass
            : FirstProofSuccessBetaSignalStatus.notObserved,
      ),
      _signal(
        id: FirstProofSuccessBetaSignalId.tooVagueSelected,
        status: !reachedProof || !input.proofShown
            ? FirstProofSuccessBetaSignalStatus.notObserved
            : input.tooVagueSelected
            ? FirstProofSuccessBetaSignalStatus.concern
            : FirstProofSuccessBetaSignalStatus.pass,
      ),
      _signal(
        id: FirstProofSuccessBetaSignalId.notRelevantSelected,
        status: !reachedProof || !input.proofShown
            ? FirstProofSuccessBetaSignalStatus.notObserved
            : input.notRelevantSelected
            ? FirstProofSuccessBetaSignalStatus.concern
            : FirstProofSuccessBetaSignalStatus.pass,
      ),
      _signal(
        id: FirstProofSuccessBetaSignalId.userUnderstoodWhy,
        status: !reachedProof || !input.proofShown
            ? FirstProofSuccessBetaSignalStatus.notObserved
            : input.userUnderstoodWhy
            ? FirstProofSuccessBetaSignalStatus.pass
            : FirstProofSuccessBetaSignalStatus.concern,
      ),
      _signal(
        id: FirstProofSuccessBetaSignalId.userSavedAnotherAfterProof,
        status: !reachedProof || !input.proofShown
            ? FirstProofSuccessBetaSignalStatus.notObserved
            : input.userSavedAnotherAfterProof
            ? FirstProofSuccessBetaSignalStatus.pass
            : FirstProofSuccessBetaSignalStatus.notObserved,
      ),
    ];
  }

  static FirstProofSuccessBetaDecision _resolveDecision(
    FirstProofSuccessBetaInput input,
  ) {
    if (input.usableMomentCount < requiredUsableMoments) {
      return FirstProofSuccessBetaDecision.notEnoughMoments;
    }

    if (!input.hasMatchQuality || _isWeakConfidence(input.proofConfidence)) {
      return FirstProofSuccessBetaDecision.weakInputQuality;
    }

    if (!input.hasSafeAnchor) {
      return FirstProofSuccessBetaDecision.noSafeAnchor;
    }

    if (!input.proofShown) {
      return FirstProofSuccessBetaDecision.proofNotShown;
    }

    if (input.tooVagueSelected) {
      return FirstProofSuccessBetaDecision.proofTooVagueRisk;
    }

    if (input.notRelevantSelected) {
      return FirstProofSuccessBetaDecision.proofNotRelevantRisk;
    }

    if (!_hasProofFeedback(input)) {
      return FirstProofSuccessBetaDecision.proofShownNeedsFeedback;
    }

    if (_proofStrongEnoughForPro(input)) {
      return FirstProofSuccessBetaDecision.proofStrongEnoughForPro;
    }

    if (input.proofAccepted || input.proofCorrected) {
      return FirstProofSuccessBetaDecision.proofWorking;
    }

    return FirstProofSuccessBetaDecision.proofShownNeedsFeedback;
  }

  static FirstProofSuccessBetaSignal? _earliestConcern(
    List<FirstProofSuccessBetaSignal> signals,
  ) {
    for (final signal in signals) {
      if (signal.status == FirstProofSuccessBetaSignalStatus.concern) {
        return signal;
      }
    }
    return null;
  }

  static FirstProofSuccessBetaSignal _signal({
    required FirstProofSuccessBetaSignalId id,
    required FirstProofSuccessBetaSignalStatus status,
  }) => FirstProofSuccessBetaSignal(
    id: id,
    label: FirstProofSuccessBetaCopy.labelFor(id),
    status: status,
    detailLabel: switch (status) {
      FirstProofSuccessBetaSignalStatus.pass =>
        FirstProofSuccessBetaCopy.detailPass,
      FirstProofSuccessBetaSignalStatus.concern =>
        FirstProofSuccessBetaCopy.detailConcern,
      FirstProofSuccessBetaSignalStatus.notObserved =>
        FirstProofSuccessBetaCopy.detailNotObserved,
    },
  );
}

class FirstProofSuccessBetaInput {
  const FirstProofSuccessBetaInput({
    required this.usableMomentCount,
    this.hasSafeAnchor = false,
    this.hasMatchQuality = false,
    this.proofConfidence,
    this.proofShown = false,
    this.proofAccepted = false,
    this.proofCorrected = false,
    this.tooVagueSelected = false,
    this.notRelevantSelected = false,
    this.userUnderstoodWhy = false,
    this.userSavedAnotherAfterProof = false,
    this.proPromiseSeen = false,
    this.proofThresholdStillThree = true,
    this.betaReadinessStillGuardsThree = true,
  });

  final int usableMomentCount;
  final bool hasSafeAnchor;
  final bool hasMatchQuality;
  final ProofConfidenceLevel? proofConfidence;
  final bool proofShown;
  final bool proofAccepted;
  final bool proofCorrected;
  final bool tooVagueSelected;
  final bool notRelevantSelected;
  final bool userUnderstoodWhy;
  final bool userSavedAnotherAfterProof;
  final bool proPromiseSeen;
  final bool proofThresholdStillThree;
  final bool betaReadinessStillGuardsThree;
}

class FirstProofSuccessBetaSignal {
  const FirstProofSuccessBetaSignal({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final FirstProofSuccessBetaSignalId id;
  final String label;
  final FirstProofSuccessBetaSignalStatus status;
  final String detailLabel;
}

class FirstProofSuccessBetaResult {
  const FirstProofSuccessBetaResult({
    required this.decision,
    required this.message,
    required this.recommendation,
    required this.signals,
    required this.earliestConcern,
    required this.proofWorking,
    required this.thresholdsUnchanged,
  });

  final FirstProofSuccessBetaDecision decision;
  final String message;
  final String recommendation;
  final List<FirstProofSuccessBetaSignal> signals;
  final FirstProofSuccessBetaSignal? earliestConcern;
  final bool proofWorking;
  final bool thresholdsUnchanged;
}

class FirstProofSuccessBetaReport {
  const FirstProofSuccessBetaReport({
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
  final FirstProofSuccessBetaResult result;
}
