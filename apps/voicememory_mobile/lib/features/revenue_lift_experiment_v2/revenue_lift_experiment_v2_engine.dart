import '../beta/archive_beta_mission_gate.dart';
import '../proof_confidence_calibration/proof_confidence_calibration_model.dart';
import '../revenue_readiness/revenue_readiness_dashboard_v2_model.dart';
import 'revenue_lift_experiment_v2_copy.dart';
import 'revenue_lift_experiment_v2_model.dart';

abstract final class RevenueLiftExperimentV2Engine {
  RevenueLiftExperimentV2Engine._();

  static const firstSaveTarget = 0.60;
  static const usefulProofTarget = 0.30;
  static const returnAfterProofTarget = 0.25;
  static const paywallSeenTarget = 0.35;
  static const paywallCtaTarget = 0.05;

  static bool get isEnabled => ArchiveBetaMissionGate.isEnabled;

  static bool showReturnReasonLine({required int entryCount}) =>
      isEnabled && (entryCount == 1 || entryCount == 2);

  static RevenueLiftExperimentV2ProofPayoffCopy? proofPayoffCopyFor({
    required ProofConfidenceLevel level,
  }) {
    if (!isEnabled || !level.qualifiesForProofPayoffSharpen) return null;
    return RevenueLiftExperimentV2ProofPayoffCopy.sharpened;
  }

  static RevenueLiftExperimentV2LiftFocus resolveLiftFocus(
    RevenueReadinessDashboardV2Input input,
  ) {
    final rates = RevenueLiftExperimentV2Rates.fromInput(input);

    if (rates.hasPaywallCtaData &&
        rates.paywallCtaRate != null &&
        rates.paywallCtaRate! < paywallCtaTarget) {
      return _focus(RevenueLiftExperimentV2Focus.paywallCta);
    }
    if (rates.hasFirstSaveData &&
        rates.firstSaveRate != null &&
        rates.firstSaveRate! < firstSaveTarget) {
      return _focus(RevenueLiftExperimentV2Focus.firstSave);
    }
    if (rates.hasUsefulProofData &&
        rates.usefulProofRate != null &&
        rates.usefulProofRate! < usefulProofTarget) {
      return _focus(RevenueLiftExperimentV2Focus.usefulProof);
    }
    if (rates.hasPaywallSeenData &&
        rates.paywallSeenRate != null &&
        rates.paywallSeenRate! < paywallSeenTarget) {
      return _focus(RevenueLiftExperimentV2Focus.proVisibility);
    }
    if (rates.hasReturnAfterProofData &&
        rates.returnAfterProofRate != null &&
        rates.returnAfterProofRate! < returnAfterProofTarget) {
      return _focus(RevenueLiftExperimentV2Focus.returnAfterProof);
    }
    return _focus(RevenueLiftExperimentV2Focus.readyForMoreTesters);
  }

  static RevenueLiftExperimentV2LiftFocus _focus(
    RevenueLiftExperimentV2Focus focus,
  ) =>
      RevenueLiftExperimentV2LiftFocus(
        focus: focus,
        label: RevenueLiftExperimentV2Copy.liftFocusLabelFor(focus),
      );
}
