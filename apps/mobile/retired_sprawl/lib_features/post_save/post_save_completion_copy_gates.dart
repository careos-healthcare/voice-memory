/// Visibility rules for post-save completion microcopy on Record.
abstract final class PostSaveCompletionCopyGates {
  PostSaveCompletionCopyGates._();

  /// Done-for-today already acknowledges the save; hide the proof counter row.
  static bool showArchiveProofCounter({
    required bool counterHasProof,
    required bool doneReceiptVisible,
    required bool suppressNoisyFirstSaveCards,
  }) => counterHasProof && !suppressNoisyFirstSaveCards && !doneReceiptVisible;
}