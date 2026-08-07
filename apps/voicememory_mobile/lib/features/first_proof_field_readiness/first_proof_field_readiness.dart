import '../archive_evidence/archive_evidence_quality_gate.dart';
import '../beta_proof_feedback/beta_proof_feedback_model.dart';
import '../first_proof_truth/first_proof_truth_model.dart';
import '../proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'first_proof_field_readiness_copy.dart';

/// First proof field readiness — beta measurement and repair routing only.
abstract final class FirstProofFieldReadiness {
  FirstProofFieldReadiness._();

  static const signalCount = 10;
  static const requiredUsableMoments =
      ArchiveEvidenceQualityGate.minProofEntryCount;

  static FirstProofFieldReadinessResult build(
    FirstProofFieldReadinessInput input,
  ) {
    final signals = _buildSignals(input);
    final decision = _resolveDecision(input, signals);
    return FirstProofFieldReadinessResult(
      decision: decision,
      message: FirstProofFieldReadinessCopy.messageFor(decision),
      recommendation: FirstProofFieldReadinessCopy.recommendationFor(decision),
      signals: signals,
      earliestConcern: _earliestConcern(signals),
      fieldReady: decision == FirstProofFieldReadinessDecision.fieldReady,
      thresholdsUnchanged: _thresholdsUnchanged(),
    );
  }

  static FirstProofFieldReadinessReport report(
    FirstProofFieldReadinessResult result,
  ) => FirstProofFieldReadinessReport(
    headline: FirstProofFieldReadinessCopy.headline,
    body: FirstProofFieldReadinessCopy.body,
    orderLine: FirstProofFieldReadinessCopy.orderLine,
    guardrail: FirstProofFieldReadinessCopy.guardrail,
    result: result,
  );

  static bool detectProofThresholdStillThree(String gateSource) =>
      gateSource.contains('static const minProofEntryCount = 3;');

  static bool detectBetaReadinessStillGuardsThree(String betaReadinessSource) =>
      betaReadinessSource.contains(
        'ArchiveEvidenceQualityGate.minProofEntryCount != 3',
      );

  static FirstProofFieldReadinessInput fromRepoSignals({
    required String archiveEvidenceQualityGateSource,
    required String betaReadinessEngineSource,
    int usableMomentCount = requiredUsableMoments,
    ProofConfidenceLevel? confidenceLevel,
    bool hasSafeAnchor = true,
    BetaProofFeedbackType? feedbackType,
    FirstProofTruthAnswer? truthAnswer,
    bool proofCorrected = false,
    bool? understoodWhyAppeared,
    bool? understoodWhatToSaveNext,
  }) => FirstProofFieldReadinessInput(
    usableMomentCount: usableMomentCount,
    confidenceLevel: confidenceLevel,
    hasSafeAnchor: hasSafeAnchor,
    feedbackType: feedbackType,
    truthAnswer: truthAnswer,
    proofCorrected: proofCorrected,
    understoodWhyAppeared: understoodWhyAppeared,
    understoodWhatToSaveNext: understoodWhatToSaveNext,
    proofThresholdStillThree: detectProofThresholdStillThree(
      archiveEvidenceQualityGateSource,
    ),
    betaReadinessStillGuardsThree: detectBetaReadinessStillGuardsThree(
      betaReadinessEngineSource,
    ),
  );

  static bool _thresholdsUnchanged() => requiredUsableMoments == 3;

  static bool _hasReachedProofAttempt(FirstProofFieldReadinessInput input) =>
      input.usableMomentCount >= requiredUsableMoments;

  static bool _isStrongProof(ProofConfidenceLevel? level) =>
      level == ProofConfidenceLevel.strong ||
      level == ProofConfidenceLevel.useful ||
      level == ProofConfidenceLevel.freshReturn ||
      level == ProofConfidenceLevel.corrected;

  static bool _isWatchOnlyProof(ProofConfidenceLevel? level) =>
      level == ProofConfidenceLevel.watchOnly ||
      level == ProofConfidenceLevel.emerging;

  static bool _proofAccepted({
    required BetaProofFeedbackType? feedbackType,
    required FirstProofTruthAnswer? truthAnswer,
  }) {
    if (feedbackType == BetaProofFeedbackType.useful) return true;
    if (truthAnswer == FirstProofTruthAnswer.yes ||
        truthAnswer == FirstProofTruthAnswer.sortOf) {
      return true;
    }
    if (feedbackType == BetaProofFeedbackType.tooVague ||
        feedbackType == BetaProofFeedbackType.notRelevant ||
        feedbackType == BetaProofFeedbackType.alreadyKnew ||
        truthAnswer == FirstProofTruthAnswer.no) {
      return false;
    }
    return false;
  }

  static List<FirstProofFieldReadinessSignal> _buildSignals(
    FirstProofFieldReadinessInput input,
  ) {
    final reachedProof = _hasReachedProofAttempt(input);
    final feedbackGiven =
        input.feedbackType != null || input.truthAnswer != null;

    return [
      _signal(
        id: FirstProofFieldReadinessSignalId.userSavedThreeUsableMoments,
        status: input.usableMomentCount >= requiredUsableMoments
            ? FirstProofFieldReadinessSignalStatus.pass
            : FirstProofFieldReadinessSignalStatus.concern,
      ),
      _signal(
        id: FirstProofFieldReadinessSignalId.strongProofAppeared,
        status: !reachedProof
            ? FirstProofFieldReadinessSignalStatus.notObserved
            : _isStrongProof(input.confidenceLevel)
            ? FirstProofFieldReadinessSignalStatus.pass
            : FirstProofFieldReadinessSignalStatus.concern,
      ),
      _signal(
        id: FirstProofFieldReadinessSignalId.watchOnlyAppearedInstead,
        status: !reachedProof
            ? FirstProofFieldReadinessSignalStatus.notObserved
            : _isWatchOnlyProof(input.confidenceLevel)
            ? FirstProofFieldReadinessSignalStatus.concern
            : FirstProofFieldReadinessSignalStatus.pass,
      ),
      _signal(
        id: FirstProofFieldReadinessSignalId.noSafeAnchor,
        status: !reachedProof
            ? FirstProofFieldReadinessSignalStatus.notObserved
            : input.hasSafeAnchor
            ? FirstProofFieldReadinessSignalStatus.pass
            : FirstProofFieldReadinessSignalStatus.concern,
      ),
      _signal(
        id: FirstProofFieldReadinessSignalId.proofAccepted,
        status: !reachedProof || !feedbackGiven
            ? FirstProofFieldReadinessSignalStatus.notObserved
            : _proofAccepted(
                feedbackType: input.feedbackType,
                truthAnswer: input.truthAnswer,
              )
            ? FirstProofFieldReadinessSignalStatus.pass
            : FirstProofFieldReadinessSignalStatus.concern,
      ),
      _signal(
        id: FirstProofFieldReadinessSignalId.proofCorrected,
        status: !reachedProof
            ? FirstProofFieldReadinessSignalStatus.notObserved
            : input.proofCorrected ||
                  input.confidenceLevel == ProofConfidenceLevel.corrected
            ? FirstProofFieldReadinessSignalStatus.pass
            : FirstProofFieldReadinessSignalStatus.notObserved,
      ),
      _signal(
        id: FirstProofFieldReadinessSignalId.proofTooVague,
        status: !reachedProof || input.feedbackType == null
            ? FirstProofFieldReadinessSignalStatus.notObserved
            : input.feedbackType == BetaProofFeedbackType.tooVague
            ? FirstProofFieldReadinessSignalStatus.concern
            : FirstProofFieldReadinessSignalStatus.pass,
      ),
      _signal(
        id: FirstProofFieldReadinessSignalId.proofNotRelevant,
        status: !reachedProof || input.feedbackType == null
            ? FirstProofFieldReadinessSignalStatus.notObserved
            : input.feedbackType == BetaProofFeedbackType.notRelevant
            ? FirstProofFieldReadinessSignalStatus.concern
            : FirstProofFieldReadinessSignalStatus.pass,
      ),
      _signal(
        id: FirstProofFieldReadinessSignalId.userUnderstoodWhyAppeared,
        status: input.understoodWhyAppeared == null
            ? FirstProofFieldReadinessSignalStatus.notObserved
            : input.understoodWhyAppeared!
            ? FirstProofFieldReadinessSignalStatus.pass
            : FirstProofFieldReadinessSignalStatus.concern,
      ),
      _signal(
        id: FirstProofFieldReadinessSignalId.userUnderstoodWhatToSaveNext,
        status: input.understoodWhatToSaveNext == null
            ? FirstProofFieldReadinessSignalStatus.notObserved
            : input.understoodWhatToSaveNext!
            ? FirstProofFieldReadinessSignalStatus.pass
            : FirstProofFieldReadinessSignalStatus.concern,
      ),
    ];
  }

  static FirstProofFieldReadinessDecision _resolveDecision(
    FirstProofFieldReadinessInput input,
    List<FirstProofFieldReadinessSignal> signals,
  ) {
    if (!input.proofThresholdStillThree ||
        !input.betaReadinessStillGuardsThree) {
      return FirstProofFieldReadinessDecision.needsManualReview;
    }

    if (input.usableMomentCount < requiredUsableMoments) {
      return FirstProofFieldReadinessDecision.insufficientCapture;
    }

    if (!input.hasSafeAnchor) {
      return FirstProofFieldReadinessDecision.repairAnchorSafety;
    }

    if (input.feedbackType == BetaProofFeedbackType.tooVague) {
      return FirstProofFieldReadinessDecision.repairProofClarity;
    }

    if (input.feedbackType == BetaProofFeedbackType.notRelevant) {
      return FirstProofFieldReadinessDecision.repairProofRelevance;
    }

    if (_isWatchOnlyProof(input.confidenceLevel)) {
      return FirstProofFieldReadinessDecision.repairProofStrength;
    }

    if (input.understoodWhatToSaveNext == false) {
      return FirstProofFieldReadinessDecision.repairSaveNextGuidance;
    }

    if (input.understoodWhyAppeared == false) {
      return FirstProofFieldReadinessDecision.repairWhyAppeared;
    }

    if (_fieldReady(input, signals)) {
      return FirstProofFieldReadinessDecision.fieldReady;
    }

    return FirstProofFieldReadinessDecision.needsManualReview;
  }

  static bool _fieldReady(
    FirstProofFieldReadinessInput input,
    List<FirstProofFieldReadinessSignal> signals,
  ) {
    if (!_isStrongProof(input.confidenceLevel)) return false;
    if (!input.hasSafeAnchor) return false;
    if (!_proofAccepted(
      feedbackType: input.feedbackType,
      truthAnswer: input.truthAnswer,
    )) {
      return false;
    }
    if (input.feedbackType == BetaProofFeedbackType.tooVague ||
        input.feedbackType == BetaProofFeedbackType.notRelevant) {
      return false;
    }
    if (input.understoodWhyAppeared != true ||
        input.understoodWhatToSaveNext != true) {
      return false;
    }

    return signals
        .where(
          (signal) =>
              signal.id != FirstProofFieldReadinessSignalId.proofCorrected,
        )
        .every(
          (signal) =>
              signal.status == FirstProofFieldReadinessSignalStatus.pass ||
              signal.status == FirstProofFieldReadinessSignalStatus.notObserved,
        );
  }

  static FirstProofFieldReadinessSignal? _earliestConcern(
    List<FirstProofFieldReadinessSignal> signals,
  ) {
    for (final signal in signals) {
      if (signal.status == FirstProofFieldReadinessSignalStatus.concern) {
        return signal;
      }
    }
    return null;
  }

  static FirstProofFieldReadinessSignal _signal({
    required FirstProofFieldReadinessSignalId id,
    required FirstProofFieldReadinessSignalStatus status,
  }) => FirstProofFieldReadinessSignal(
    id: id,
    label: FirstProofFieldReadinessCopy.labelFor(id),
    status: status,
    detailLabel: switch (status) {
      FirstProofFieldReadinessSignalStatus.pass =>
        FirstProofFieldReadinessCopy.detailPass,
      FirstProofFieldReadinessSignalStatus.concern =>
        FirstProofFieldReadinessCopy.detailConcern,
      FirstProofFieldReadinessSignalStatus.notObserved =>
        FirstProofFieldReadinessCopy.detailNotObserved,
    },
  );
}

class FirstProofFieldReadinessInput {
  const FirstProofFieldReadinessInput({
    required this.usableMomentCount,
    this.confidenceLevel,
    this.hasSafeAnchor = false,
    this.feedbackType,
    this.truthAnswer,
    this.proofCorrected = false,
    this.understoodWhyAppeared,
    this.understoodWhatToSaveNext,
    this.proofThresholdStillThree = true,
    this.betaReadinessStillGuardsThree = true,
  });

  final int usableMomentCount;
  final ProofConfidenceLevel? confidenceLevel;
  final bool hasSafeAnchor;
  final BetaProofFeedbackType? feedbackType;
  final FirstProofTruthAnswer? truthAnswer;
  final bool proofCorrected;
  final bool? understoodWhyAppeared;
  final bool? understoodWhatToSaveNext;
  final bool proofThresholdStillThree;
  final bool betaReadinessStillGuardsThree;
}

class FirstProofFieldReadinessSignal {
  const FirstProofFieldReadinessSignal({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final FirstProofFieldReadinessSignalId id;
  final String label;
  final FirstProofFieldReadinessSignalStatus status;
  final String detailLabel;
}

class FirstProofFieldReadinessResult {
  const FirstProofFieldReadinessResult({
    required this.decision,
    required this.message,
    required this.recommendation,
    required this.signals,
    required this.earliestConcern,
    required this.fieldReady,
    required this.thresholdsUnchanged,
  });

  final FirstProofFieldReadinessDecision decision;
  final String message;
  final String recommendation;
  final List<FirstProofFieldReadinessSignal> signals;
  final FirstProofFieldReadinessSignal? earliestConcern;
  final bool fieldReady;
  final bool thresholdsUnchanged;
}

class FirstProofFieldReadinessReport {
  const FirstProofFieldReadinessReport({
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
  final FirstProofFieldReadinessResult result;
}
