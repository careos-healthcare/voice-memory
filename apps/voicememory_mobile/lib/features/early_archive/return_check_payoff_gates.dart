import 'return_check_payoff_model.dart';

/// Visibility gates for the return-check payoff on Record post-save.
abstract final class ReturnCheckPayoffGates {
  ReturnCheckPayoffGates._();

  static bool shouldShow({
    required bool isPostSaveDone,
    required int entryCount,
    required bool isDegradedPostSave,
    required bool showFirstProofMoment,
    ReturnCheckPayoff? payoff,
  }) =>
      isPostSaveDone &&
      !isDegradedPostSave &&
      entryCount >= 4 &&
      !showFirstProofMoment &&
      payoff != null;
}
