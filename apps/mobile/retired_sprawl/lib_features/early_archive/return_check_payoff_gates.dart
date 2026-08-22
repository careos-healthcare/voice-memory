import 'package:archiveme_mobile/features/early_archive/return_check_payoff_model.dart';

/// Visibility gates for the return-check payoff on Record post-save.
abstract final class ReturnCheckPayoffGates {
  ReturnCheckPayoffGates._();

  static bool shouldShow({
    required bool isPostSaveDone,
    required int entryCount,
    required bool isDegradedPostSave,
    required bool showFirstProofMoment,
    required bool showPostSaveReturnCheckAnswer,
    ReturnCheckPayoff? payoff,
  }) =>
      isPostSaveDone &&
      !isDegradedPostSave &&
      entryCount >= 4 &&
      !showFirstProofMoment &&
      payoff != null &&
      !(showPostSaveReturnCheckAnswer &&
          payoff.state == ReturnCheckPayoffComparisonState.unknown);
}