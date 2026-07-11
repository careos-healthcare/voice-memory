import 'preserved_proof_value_copy.dart';

/// Preserved proof value — sharpen Pro value without fear or scarcity.
abstract final class PreservedProofValue {
  PreservedProofValue._();

  static PreservedProofValueResult resolve(PreservedProofValueInput input) {
    if (!input.userUnderstandsFirstProof) {
      return _result(PreservedProofValueDecision.clarifyFirstProof);
    }
    if (!input.userUnderstandsProKeepsTrail) {
      return _result(PreservedProofValueDecision.clarifyProKeepsTrail);
    }
    if (input.userThinksProMeansMoreAi) {
      return _result(PreservedProofValueDecision.removeMoreAiConfusion);
    }
    if (input.userThinksProMeansStorage) {
      return _result(PreservedProofValueDecision.removeStorageConfusion);
    }
    if (input.userFeelsPressureOrManipulation) {
      return _result(PreservedProofValueDecision.reducePressure);
    }
    if (!input.userUnderstandsPreservedProof) {
      return _result(PreservedProofValueDecision.clarifyPreservedProof);
    }
    if (!input.userUnderstandsWhatWouldBeLost) {
      return _result(PreservedProofValueDecision.clarifyWhatWouldBeLost);
    }
    if (input.userThinksPaymentFeelsOptional && !_paymentPasses(input)) {
      return _result(PreservedProofValueDecision.pricingValidation);
    }
    if (_comprehensionPasses(input) && _paymentPasses(input)) {
      return _result(PreservedProofValueDecision.releaseCandidate);
    }
    return _result(PreservedProofValueDecision.clarifyPreservedProof);
  }

  static PreservedProofValueReport report(PreservedProofValueResult result) =>
      PreservedProofValueReport(
        headline: PreservedProofValueCopy.headline,
        body: PreservedProofValueCopy.body,
        freeLine: PreservedProofValueCopy.freeLine,
        proLine: PreservedProofValueCopy.proLine,
        whyPayLine: PreservedProofValueCopy.whyPayLine,
        lossLine: PreservedProofValueCopy.lossLine,
        valueLine: PreservedProofValueCopy.valueLine,
        repeatLine: PreservedProofValueCopy.repeatLine,
        guardrail: PreservedProofValueCopy.guardrail,
        result: result,
      );

  static bool _comprehensionPasses(PreservedProofValueInput input) =>
      input.userUnderstandsFirstProof &&
      input.userUnderstandsProKeepsTrail &&
      input.userUnderstandsPreservedProof &&
      input.userUnderstandsWhatWouldBeLost &&
      !input.userThinksProMeansMoreAi &&
      !input.userThinksProMeansStorage &&
      !input.userFeelsPressureOrManipulation;

  static bool _paymentPasses(PreservedProofValueInput input) =>
      input.wouldPayYes || input.wouldPayMaybe;

  static PreservedProofValueResult _result(
    PreservedProofValueDecision decision,
  ) =>
      PreservedProofValueResult(
        decision: decision,
        message: _messageFor(decision),
      );

  static String _messageFor(PreservedProofValueDecision decision) =>
      switch (decision) {
        PreservedProofValueDecision.clarifyFirstProof =>
          PreservedProofValueCopy.freeLine,
        PreservedProofValueDecision.clarifyProKeepsTrail =>
          PreservedProofValueCopy.proLine,
        PreservedProofValueDecision.clarifyPreservedProof =>
          PreservedProofValueCopy.body,
        PreservedProofValueDecision.clarifyWhatWouldBeLost =>
          PreservedProofValueCopy.lossLine,
        PreservedProofValueDecision.removeMoreAiConfusion =>
          PreservedProofValueCopy.whyPayLine,
        PreservedProofValueDecision.removeStorageConfusion =>
          PreservedProofValueCopy.valueLine,
        PreservedProofValueDecision.reducePressure =>
          PreservedProofValueCopy.whyPayLine,
        PreservedProofValueDecision.pricingValidation =>
          PreservedProofValueCopy.whyPayLine,
        PreservedProofValueDecision.releaseCandidate =>
          PreservedProofValueCopy.headline,
      };
}

enum PreservedProofValueDecision {
  clarifyFirstProof,
  clarifyProKeepsTrail,
  clarifyPreservedProof,
  clarifyWhatWouldBeLost,
  removeMoreAiConfusion,
  removeStorageConfusion,
  reducePressure,
  pricingValidation,
  releaseCandidate,
}

class PreservedProofValueInput {
  const PreservedProofValueInput({
    required this.userUnderstandsFirstProof,
    required this.userUnderstandsProKeepsTrail,
    required this.userUnderstandsPreservedProof,
    required this.userUnderstandsWhatWouldBeLost,
    required this.userThinksProMeansMoreAi,
    required this.userThinksProMeansStorage,
    required this.userThinksPaymentFeelsOptional,
    required this.userFeelsPressureOrManipulation,
    required this.wouldPayYes,
    required this.wouldPayMaybe,
  });

  final bool userUnderstandsFirstProof;
  final bool userUnderstandsProKeepsTrail;
  final bool userUnderstandsPreservedProof;
  final bool userUnderstandsWhatWouldBeLost;
  final bool userThinksProMeansMoreAi;
  final bool userThinksProMeansStorage;
  final bool userThinksPaymentFeelsOptional;
  final bool userFeelsPressureOrManipulation;
  final bool wouldPayYes;
  final bool wouldPayMaybe;
}

class PreservedProofValueResult {
  const PreservedProofValueResult({
    required this.decision,
    required this.message,
  });

  final PreservedProofValueDecision decision;
  final String message;
}

class PreservedProofValueReport {
  const PreservedProofValueReport({
    required this.headline,
    required this.body,
    required this.freeLine,
    required this.proLine,
    required this.whyPayLine,
    required this.lossLine,
    required this.valueLine,
    required this.repeatLine,
    required this.guardrail,
    required this.result,
  });

  final String headline;
  final String body;
  final String freeLine;
  final String proLine;
  final String whyPayLine;
  final String lossLine;
  final String valueLine;
  final String repeatLine;
  final String guardrail;
  final PreservedProofValueResult result;
}
