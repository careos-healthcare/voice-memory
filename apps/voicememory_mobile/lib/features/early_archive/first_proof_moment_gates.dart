import 'first_proof_moment_model.dart';

/// Visibility gates for the first proof moment on Record post-save.
abstract final class FirstProofMomentGates {
  FirstProofMomentGates._();

  static bool shouldShow({
    required bool isPostSaveDone,
    required int entryCount,
    required bool isDegradedPostSave,
    FirstProofMoment? moment,
  }) =>
      isPostSaveDone &&
      !isDegradedPostSave &&
      entryCount == 3 &&
      moment != null;
}
