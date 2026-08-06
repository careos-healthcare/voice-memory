import 'pro_single_promise_copy.dart';

/// Pro single-promise — one idea: keep the longer proof trail.
abstract final class ProSinglePromise {
  ProSinglePromise._();

  static ProSinglePromiseResult build(ProSinglePromiseInput input) {
    if (!input.userUnderstandsFirstProof) {
      return _result(
        ProSinglePromiseDecision.clarifyFirstProof,
        ProSinglePromiseCopy.freeLine,
      );
    }
    if (!input.userUnderstandsProKeepsLongerTrail) {
      return _result(
        ProSinglePromiseDecision.clarifyLongerTrail,
        ProSinglePromiseCopy.proLine,
      );
    }
    if (input.userThinksProMeansMoreAi) {
      return _result(
        ProSinglePromiseDecision.removeMoreAiConfusion,
        ProSinglePromiseCopy.notMoreAiLine,
      );
    }
    if (input.userThinksProMeansStorage) {
      return _result(
        ProSinglePromiseDecision.removeStorageConfusion,
        ProSinglePromiseCopy.notStorageLine,
      );
    }
    if (input.userThinksProMeansMoreFeatures) {
      return _result(
        ProSinglePromiseDecision.removeFeatureVolumeConfusion,
        ProSinglePromiseCopy.notFeatureListLine,
      );
    }
    if (input.userThinksProMeansReports) {
      return _result(
        ProSinglePromiseDecision.removeReportsConfusion,
        ProSinglePromiseCopy.notFeatureListLine,
      );
    }
    if (input.userThinksProMeansRanking) {
      return _result(
        ProSinglePromiseDecision.removeRankingConfusion,
        ProSinglePromiseCopy.notFeatureListLine,
      );
    }
    if (input.userFeelsPressureOrManipulation) {
      return _result(
        ProSinglePromiseDecision.reducePressure,
        ProSinglePromiseCopy.valueLine,
      );
    }
    if (!input.userUnderstandsContinuityValue) {
      return _result(
        ProSinglePromiseDecision.clarifyContinuityValue,
        ProSinglePromiseCopy.valueLine,
      );
    }
    if (_comprehensionPasses(input) && !_wouldPay(input)) {
      return _result(
        ProSinglePromiseDecision.pricingValidation,
        ProSinglePromiseCopy.whyPayLine,
      );
    }
    if (_comprehensionPasses(input) && _wouldPay(input)) {
      return _result(
        ProSinglePromiseDecision.releaseCandidate,
        ProSinglePromiseCopy.headline,
      );
    }
    return _result(
      ProSinglePromiseDecision.clarifyLongerTrail,
      ProSinglePromiseCopy.headline,
    );
  }

  static ProSinglePromiseReport report(ProSinglePromiseResult result) =>
      ProSinglePromiseReport(
        headline: ProSinglePromiseCopy.headline,
        body: ProSinglePromiseCopy.body,
        freeLine: ProSinglePromiseCopy.freeLine,
        proLine: ProSinglePromiseCopy.proLine,
        whyPayLine: ProSinglePromiseCopy.whyPayLine,
        notMoreAiLine: ProSinglePromiseCopy.notMoreAiLine,
        notStorageLine: ProSinglePromiseCopy.notStorageLine,
        notFeatureListLine: ProSinglePromiseCopy.notFeatureListLine,
        valueLine: ProSinglePromiseCopy.valueLine,
        guardrail: ProSinglePromiseCopy.guardrail,
        result: result,
      );

  static bool _comprehensionPasses(ProSinglePromiseInput input) =>
      input.userUnderstandsFirstProof &&
      input.userUnderstandsProKeepsLongerTrail &&
      !input.userThinksProMeansMoreAi &&
      !input.userThinksProMeansStorage &&
      !input.userThinksProMeansMoreFeatures &&
      !input.userThinksProMeansReports &&
      !input.userThinksProMeansRanking &&
      input.userUnderstandsContinuityValue &&
      !input.userFeelsPressureOrManipulation;

  static bool _wouldPay(ProSinglePromiseInput input) =>
      input.wouldPayYes || input.wouldPayMaybe;

  static ProSinglePromiseResult _result(
    ProSinglePromiseDecision decision,
    String message,
  ) => ProSinglePromiseResult(decision: decision, message: message);
}

abstract final class ProSinglePromiseGuardrail {
  ProSinglePromiseGuardrail._();

  static bool allowsLongerTrailPromise() => true;

  static bool allowsMoreAiPromise() => false;

  static bool allowsStoragePromise() => false;

  static bool allowsDashboardPromise() => false;

  static bool allowsRankingPromise() => false;

  static bool allowsReportsAsPrimaryPromise() => false;

  static bool allowsFeatureVolumePromise() => false;
}

enum ProSinglePromiseDecision {
  clarifyFirstProof,
  clarifyLongerTrail,
  removeMoreAiConfusion,
  removeStorageConfusion,
  removeFeatureVolumeConfusion,
  removeReportsConfusion,
  removeRankingConfusion,
  clarifyContinuityValue,
  reducePressure,
  pricingValidation,
  releaseCandidate,
}

class ProSinglePromiseInput {
  const ProSinglePromiseInput({
    required this.userUnderstandsFirstProof,
    required this.userUnderstandsProKeepsLongerTrail,
    required this.userThinksProMeansMoreAi,
    required this.userThinksProMeansStorage,
    required this.userThinksProMeansMoreFeatures,
    required this.userThinksProMeansReports,
    required this.userThinksProMeansRanking,
    required this.userUnderstandsContinuityValue,
    required this.userFeelsPressureOrManipulation,
    required this.wouldPayYes,
    required this.wouldPayMaybe,
  });

  final bool userUnderstandsFirstProof;
  final bool userUnderstandsProKeepsLongerTrail;
  final bool userThinksProMeansMoreAi;
  final bool userThinksProMeansStorage;
  final bool userThinksProMeansMoreFeatures;
  final bool userThinksProMeansReports;
  final bool userThinksProMeansRanking;
  final bool userUnderstandsContinuityValue;
  final bool userFeelsPressureOrManipulation;
  final bool wouldPayYes;
  final bool wouldPayMaybe;
}

class ProSinglePromiseResult {
  const ProSinglePromiseResult({required this.decision, required this.message});

  final ProSinglePromiseDecision decision;
  final String message;
}

class ProSinglePromiseReport {
  const ProSinglePromiseReport({
    required this.headline,
    required this.body,
    required this.freeLine,
    required this.proLine,
    required this.whyPayLine,
    required this.notMoreAiLine,
    required this.notStorageLine,
    required this.notFeatureListLine,
    required this.valueLine,
    required this.guardrail,
    required this.result,
  });

  final String headline;
  final String body;
  final String freeLine;
  final String proLine;
  final String whyPayLine;
  final String notMoreAiLine;
  final String notStorageLine;
  final String notFeatureListLine;
  final String valueLine;
  final String guardrail;
  final ProSinglePromiseResult result;
}
