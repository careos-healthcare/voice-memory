/// Visible strings for the first-session evidence surfaces.
///
/// Kept free of the banned terms in
/// `docs/sharing/NO_MEDICAL_CLAIMS_COPY_RULES.md`.
abstract final class FirstSessionEvidenceCopy {
  FirstSessionEvidenceCopy._();

  static const importCardTitle = 'A few of your notes use similar words.';
  static const quoteTitle = "Here's what you said";
  static const playChip = 'Play';
  static const remindQuestion =
      'Want to be reminded to check on this in a week?';
  static const remindYes = 'Yes';
  static const remindNotNow = 'Not now';

  static const List<String> allVisibleStrings = [
    importCardTitle,
    quoteTitle,
    playChip,
    remindQuestion,
    remindYes,
    remindNotNow,
  ];
}
