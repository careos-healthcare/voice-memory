import 'package:archiveme_mobile/features/first_proof_payoff/first_proof_payoff_model.dart';

/// Visibility gates for the first proof emotional payoff on Record post-save.
abstract final class FirstProofPayoffGates {
  FirstProofPayoffGates._();

  static bool shouldShow({
    required bool isPostSaveDone,
    required int entryCount,
    required bool isDegradedPostSave,
    FirstProofPayoff? payoff,
  }) =>
      isPostSaveDone &&
      !isDegradedPostSave &&
      entryCount == 3 &&
      payoff != null;

  /// Lower-priority surfaces stay hidden while the payoff owns the moment.
  static bool suppressLowerPrioritySurfaces(bool showFirstProofPayoff) =>
      showFirstProofPayoff;
}