import '../proof_confidence_calibration/proof_confidence_calibration_model.dart';
import '../revenue_readiness/revenue_readiness_dashboard_v2_model.dart';
import 'revenue_lift_experiment_v2_copy.dart';

class RevenueLiftExperimentV2LiftFocus {
  const RevenueLiftExperimentV2LiftFocus({
    required this.focus,
    required this.label,
  });

  final RevenueLiftExperimentV2Focus focus;
  final String label;
}

class RevenueLiftExperimentV2SeenContext {
  const RevenueLiftExperimentV2SeenContext({
    required this.source,
    required this.surface,
    required this.entryCount,
    required this.area,
  });

  final String source;
  final String surface;
  final int entryCount;
  final RevenueLiftExperimentV2Area area;
}

class RevenueLiftExperimentV2CtaContext
    extends RevenueLiftExperimentV2SeenContext {
  const RevenueLiftExperimentV2CtaContext({
    required super.source,
    required super.surface,
    required super.entryCount,
    required super.area,
  });
}

class RevenueLiftExperimentV2PaywallSeenContext {
  const RevenueLiftExperimentV2PaywallSeenContext({
    required this.source,
    required this.surface,
    required this.entryCount,
  });

  final String source;
  final String surface;
  final int entryCount;
}

class RevenueLiftExperimentV2ProofPayoffCopy {
  const RevenueLiftExperimentV2ProofPayoffCopy({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  static const sharpened = RevenueLiftExperimentV2ProofPayoffCopy(
    title: RevenueLiftExperimentV2Copy.proofPayoffTitle,
    body: RevenueLiftExperimentV2Copy.proofPayoffBody,
  );
}

class RevenueLiftExperimentV2Rates {
  const RevenueLiftExperimentV2Rates({
    required this.firstSaveRate,
    required this.usefulProofRate,
    required this.returnAfterProofRate,
    required this.paywallSeenRate,
    required this.paywallCtaRate,
    required this.hasPaywallCtaData,
    required this.hasFirstSaveData,
    required this.hasUsefulProofData,
    required this.hasPaywallSeenData,
    required this.hasReturnAfterProofData,
  });

  final double? firstSaveRate;
  final double? usefulProofRate;
  final double? returnAfterProofRate;
  final double? paywallSeenRate;
  final double? paywallCtaRate;
  final bool hasPaywallCtaData;
  final bool hasFirstSaveData;
  final bool hasUsefulProofData;
  final bool hasPaywallSeenData;
  final bool hasReturnAfterProofData;

  factory RevenueLiftExperimentV2Rates.fromInput(
    RevenueReadinessDashboardV2Input input,
  ) {
    double? rate(int numerator, int denominator) =>
        denominator > 0 ? numerator / denominator : null;

    return RevenueLiftExperimentV2Rates(
      firstSaveRate: rate(input.firstMomentSaved, input.recordScreenSeen),
      usefulProofRate: rate(input.usefulCount, input.totalFeedbackCount),
      returnAfterProofRate: rate(
        input.returnedAfterFirstProof,
        input.confirmedRepeatSeen,
      ),
      paywallSeenRate: rate(input.paywallSeen, input.confirmedRepeatSeen),
      paywallCtaRate: rate(input.paywallCtaTapped, input.paywallSeen),
      hasPaywallCtaData: input.paywallSeen > 0,
      hasFirstSaveData: input.recordScreenSeen > 0,
      hasUsefulProofData: input.totalFeedbackCount > 0,
      hasPaywallSeenData: input.confirmedRepeatSeen > 0,
      hasReturnAfterProofData: input.confirmedRepeatSeen > 0,
    );
  }
}

extension RevenueLiftExperimentV2ProofConfidence on ProofConfidenceLevel {
  bool get qualifiesForProofPayoffSharpen =>
      this == ProofConfidenceLevel.useful ||
      this == ProofConfidenceLevel.strong ||
      this == ProofConfidenceLevel.freshReturn;
}
