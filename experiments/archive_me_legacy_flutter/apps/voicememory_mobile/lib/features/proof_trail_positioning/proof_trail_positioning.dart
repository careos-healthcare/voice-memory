import 'proof_trail_positioning_copy.dart';

/// Central proof-trail positioning — blocks chat, storage, and dashboard drift.
abstract final class ProofTrailPositioning {
  ProofTrailPositioning._();

  static ProofTrailPositioningResult resolve(ProofTrailPositioningInput input) {
    if (input.userThinksChatBox) {
      return _result(ProofTrailPositioningDecision.clarifyNotChat);
    }
    if (input.userThinksStorageApp) {
      return _result(ProofTrailPositioningDecision.clarifyNotStorage);
    }
    if (input.userThinksSecondBrain) {
      return _result(ProofTrailPositioningDecision.clarifyNotSecondBrain);
    }
    if (input.userThinksDashboardToMaintain) {
      return _result(ProofTrailPositioningDecision.clarifyNotDashboard);
    }
    if (!input.userUnderstandsProofTrail) {
      return _result(ProofTrailPositioningDecision.clarifyProofTrail);
    }
    if (!input.userUnderstandsMeaningfulResurfacing) {
      return _result(
        ProofTrailPositioningDecision.clarifyMeaningfulResurfacing,
      );
    }
    if (!input.userUnderstandsSaveARepeat) {
      return _result(ProofTrailPositioningDecision.clarifySaveARepeat);
    }
    if (!input.userUnderstandsLowEffort) {
      return _result(ProofTrailPositioningDecision.clarifyLowEffort);
    }
    if (!_paymentPasses(input)) {
      return _result(ProofTrailPositioningDecision.pricingValidation);
    }
    if (_comprehensionPasses(input) && _paymentPasses(input)) {
      return _result(ProofTrailPositioningDecision.releaseCandidate);
    }
    return _result(ProofTrailPositioningDecision.clarifyProofTrail);
  }

  static ProofTrailPositioningReport report(
    ProofTrailPositioningResult result,
  ) => ProofTrailPositioningReport(
    headline: ProofTrailPositioningCopy.headline,
    body: ProofTrailPositioningCopy.body,
    notChatLine: ProofTrailPositioningCopy.notChatLine,
    notStorageLine: ProofTrailPositioningCopy.notStorageLine,
    proofTrailLine: ProofTrailPositioningCopy.proofTrailLine,
    resurfacingLine: ProofTrailPositioningCopy.resurfacingLine,
    saveRepeatLine: ProofTrailPositioningCopy.saveRepeatLine,
    lowEffortLine: ProofTrailPositioningCopy.lowEffortLine,
    proLine: ProofTrailPositioningCopy.proLine,
    guardrail: ProofTrailPositioningCopy.guardrail,
    result: result,
  );

  static bool _comprehensionPasses(ProofTrailPositioningInput input) =>
      !input.userThinksChatBox &&
      !input.userThinksStorageApp &&
      !input.userThinksSecondBrain &&
      !input.userThinksDashboardToMaintain &&
      input.userUnderstandsProofTrail &&
      input.userUnderstandsMeaningfulResurfacing &&
      input.userUnderstandsSaveARepeat &&
      input.userUnderstandsLowEffort;

  static bool _paymentPasses(ProofTrailPositioningInput input) =>
      input.wouldPayYes || input.wouldPayMaybe;

  static ProofTrailPositioningResult _result(
    ProofTrailPositioningDecision decision,
  ) => ProofTrailPositioningResult(
    decision: decision,
    message: _messageFor(decision),
  );

  static String _messageFor(ProofTrailPositioningDecision decision) =>
      switch (decision) {
        ProofTrailPositioningDecision.clarifyNotChat =>
          ProofTrailPositioningCopy.notChatLine,
        ProofTrailPositioningDecision.clarifyNotStorage =>
          ProofTrailPositioningCopy.notStorageLine,
        ProofTrailPositioningDecision.clarifyNotSecondBrain =>
          ProofTrailPositioningCopy.resurfacingLine,
        ProofTrailPositioningDecision.clarifyNotDashboard =>
          ProofTrailPositioningCopy.lowEffortLine,
        ProofTrailPositioningDecision.clarifyProofTrail =>
          ProofTrailPositioningCopy.proofTrailLine,
        ProofTrailPositioningDecision.clarifyMeaningfulResurfacing =>
          ProofTrailPositioningCopy.resurfacingLine,
        ProofTrailPositioningDecision.clarifySaveARepeat =>
          ProofTrailPositioningCopy.saveRepeatLine,
        ProofTrailPositioningDecision.clarifyLowEffort =>
          ProofTrailPositioningCopy.lowEffortLine,
        ProofTrailPositioningDecision.pricingValidation =>
          ProofTrailPositioningCopy.proLine,
        ProofTrailPositioningDecision.releaseCandidate =>
          ProofTrailPositioningCopy.headline,
      };
}

/// Positioning guardrails that block chat, storage, and dashboard drift.
abstract final class ProofTrailPositioningGuardrail {
  ProofTrailPositioningGuardrail._();

  static bool allowsChatBoxPositioning() => false;

  static bool allowsStoragePositioning() => false;

  static bool allowsSecondBrainPositioning() => false;

  static bool allowsDashboardMaintenancePositioning() => false;

  static bool allowsProofTrailPositioning() => true;

  static bool allowsMeaningfulResurfacingPositioning() => true;

  static bool allowsSaveARepeatPositioning() => true;
}

enum ProofTrailPositioningDecision {
  clarifyNotChat,
  clarifyNotStorage,
  clarifyNotSecondBrain,
  clarifyNotDashboard,
  clarifyProofTrail,
  clarifyMeaningfulResurfacing,
  clarifySaveARepeat,
  clarifyLowEffort,
  pricingValidation,
  releaseCandidate,
}

class ProofTrailPositioningInput {
  const ProofTrailPositioningInput({
    required this.userThinksChatBox,
    required this.userThinksStorageApp,
    required this.userThinksSecondBrain,
    required this.userThinksDashboardToMaintain,
    required this.userUnderstandsProofTrail,
    required this.userUnderstandsMeaningfulResurfacing,
    required this.userUnderstandsSaveARepeat,
    required this.userUnderstandsLowEffort,
    required this.wouldPayYes,
    required this.wouldPayMaybe,
  });

  final bool userThinksChatBox;
  final bool userThinksStorageApp;
  final bool userThinksSecondBrain;
  final bool userThinksDashboardToMaintain;
  final bool userUnderstandsProofTrail;
  final bool userUnderstandsMeaningfulResurfacing;
  final bool userUnderstandsSaveARepeat;
  final bool userUnderstandsLowEffort;
  final bool wouldPayYes;
  final bool wouldPayMaybe;
}

class ProofTrailPositioningResult {
  const ProofTrailPositioningResult({
    required this.decision,
    required this.message,
  });

  final ProofTrailPositioningDecision decision;
  final String message;
}

class ProofTrailPositioningReport {
  const ProofTrailPositioningReport({
    required this.headline,
    required this.body,
    required this.notChatLine,
    required this.notStorageLine,
    required this.proofTrailLine,
    required this.resurfacingLine,
    required this.saveRepeatLine,
    required this.lowEffortLine,
    required this.proLine,
    required this.guardrail,
    required this.result,
  });

  final String headline;
  final String body;
  final String notChatLine;
  final String notStorageLine;
  final String proofTrailLine;
  final String resurfacingLine;
  final String saveRepeatLine;
  final String lowEffortLine;
  final String proLine;
  final String guardrail;
  final ProofTrailPositioningResult result;
}
