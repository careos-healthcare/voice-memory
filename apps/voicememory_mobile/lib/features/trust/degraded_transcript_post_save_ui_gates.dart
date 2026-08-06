/// Presentation-only gates for degraded voice / transcript-pending post-save.
abstract final class DegradedTranscriptPostSaveUiGates {
  DegradedTranscriptPostSaveUiGates._();

  /// One focused recovery card instead of the full post-save stack.
  static bool showFocusedRecoverySurface({required bool isDegradedPostSave}) =>
      isDegradedPostSave;

  /// Hide evidence, thought map, add-more-moment, and done-for-today essay cards.
  static bool suppressCompetingPostSaveCards({
    required bool showFocusedRecoverySurface,
  }) => showFocusedRecoverySurface;

  /// Card owns primary/secondary actions; bottom bar stays minimal.
  static bool suppressBottomPolicyCtas({
    required bool showFocusedRecoverySurface,
  }) => showFocusedRecoverySurface;
}
