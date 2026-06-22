/// Visibility gates for the first-three-session product loop.
abstract class FirstThreeSessionGates {
  FirstThreeSessionGates._();

  static const int minEntriesForRepeatSurface = 2;
  static const int minEntriesForUsefulArchive = 3;

  /// Hide noisy post-save cards while the first-save confirmation is showing.
  static bool suppressNoisyPostSaveCards({
    required bool justSavedFirst,
    required int entryCount,
  }) =>
      justSavedFirst && entryCount == 1;

  /// Hide "possible repeat" / hypothesis cards after the second save unless
  /// the overlap is grounded in the user's own words.
  static bool suppressEarlyPatternClaimCards({
    required int entryCount,
    required bool hasGroundedRepeatMatch,
  }) =>
      entryCount == minEntriesForRepeatSurface && !hasGroundedRepeatMatch;

  static bool showSession2RepeatSurface(int entryCount) =>
      entryCount >= minEntriesForRepeatSurface;

  static bool showSession3ArchiveSurface(int entryCount) =>
      entryCount >= minEntriesForUsefulArchive;

  /// Pro bridge only after repeat / archive value — never on first save.
  static bool showSoftProBridge({
    required int entryCount,
    required bool resolved,
    required bool isPro,
  }) =>
      entryCount >= minEntriesForRepeatSurface && !resolved && !isPro;
}
