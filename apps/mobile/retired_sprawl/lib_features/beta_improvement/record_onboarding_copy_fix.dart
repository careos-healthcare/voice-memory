/// Record/onboarding copy when users misunderstand the promise.
abstract final class RecordOnboardingCopyFix {
  RecordOnboardingCopyFix._();

  static const title = 'Save one real moment.';

  static const body =
      'When something like it happens again, ArchiveMe will show what returned, '
      'changed, faded, or corrected.';

  static const notADiaryLine =
      'This is not a diary to fill every day. It is a place to save moments that might come back.';

  static const lowEvidenceClarifier =
      'Use it when something repeats, feels familiar, or might matter later.';

  static Iterable<String> allVisibleStrings() sync* {
    yield title;
    yield body;
    yield notADiaryLine;
    yield lowEvidenceClarifier;
  }
}