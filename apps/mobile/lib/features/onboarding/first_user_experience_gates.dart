/// Visibility gates for first-run vs returning-user surfaces on Record and shell.
abstract class FirstUserExperienceGates {
  FirstUserExperienceGates._();

  /// True when the local archive has no saved entries yet.
  static bool isEmptyFirstRun({
    required bool loaded,
    required int entryCount,
  }) => loaded && entryCount == 0;

  /// Returning-user prompts (session surveys, streaks, worth-checking lists)
  /// only after the user has saved at least one moment, or an explicit
  /// returning flag was set (e.g. reminder open).
  static bool showReturningUserPrompts({
    required bool loaded,
    required int entryCount,
    bool explicitReturningSession = false,
  }) => loaded && (entryCount > 0 || explicitReturningSession);

  /// Session return survey — never on a blank archive.
  static bool showReturnSessionSurvey({
    required bool loaded,
    required int entryCount,
    bool explicitReturningSession = false,
  }) => showReturningUserPrompts(
    loaded: loaded,
    entryCount: entryCount,
    explicitReturningSession: explicitReturningSession,
  );

  /// Pre-first-recording legal / advanced prompts stay hidden at count 0.
  static bool showPreFirstRecordingLegalPrompts({
    required bool loaded,
    required int entryCount,
  }) => !isEmptyFirstRun(loaded: loaded, entryCount: entryCount);
}