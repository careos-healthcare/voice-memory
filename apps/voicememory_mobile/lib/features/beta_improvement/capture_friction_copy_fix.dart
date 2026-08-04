import '../first_session_proof_repair/first_session_proof_repair_model.dart';

/// Capture friction copy when users understand but do not record.
abstract final class CaptureFrictionCopyFix {
  CaptureFrictionCopyFix._();

  static const typedCapturePrompt =
      'Write one sentence about what just happened.';

  static const typeInsteadLabel = 'Type instead';
  static const typeFirstPrimaryCta = 'Type one sentence';
  static const typeFirstSecondaryCta = 'Use voice instead';

  static const chipWorkPressure = 'Work pressure';
  static const chipSaidYes = 'Said yes';
  static const chipAvoidedSomething = 'Avoided something';
  static const chipSameFeelingAgain = 'Same feeling again';

  static const compactChipOrder = <String>[
    chipWorkPressure,
    chipSaidYes,
    chipAvoidedSomething,
    chipSameFeelingAgain,
  ];

  static List<FirstSessionProofRepairChip> compactChips() => [
    FirstSessionProofRepairChip(
      id: FirstSessionProofRepairChipId.feltFamiliar,
      text: chipWorkPressure,
    ),
    FirstSessionProofRepairChip(
      id: FirstSessionProofRepairChipId.avoidedReplying,
      text: chipSaidYes,
    ),
    FirstSessionProofRepairChip(
      id: FirstSessionProofRepairChipId.wantedControl,
      text: chipAvoidedSomething,
    ),
    FirstSessionProofRepairChip(
      id: FirstSessionProofRepairChipId.keptCheckingAgain,
      text: chipSameFeelingAgain,
    ),
  ];

  static Iterable<String> allVisibleStrings() sync* {
    yield typedCapturePrompt;
    yield typeInsteadLabel;
    yield typeFirstPrimaryCta;
    yield typeFirstSecondaryCta;
    yield* compactChipOrder;
  }
}
