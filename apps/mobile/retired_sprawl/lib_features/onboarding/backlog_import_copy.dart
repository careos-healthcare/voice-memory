/// Copy for optional historical notes import during onboarding.
abstract final class BacklogImportCopy {
  BacklogImportCopy._();

  static const title = 'Bring your old notes';
  static const subtitle =
      'Import Apple Notes exports or voice memos (.txt, .csv, .m4a, .mp3). '
      'We split them into entries and add them to your archive.';
  static const pickCta = 'Choose files';
  static const skipCta = 'Skip for now';
  static const continueCta = 'Continue';
  static const retryCta = 'Try again';
  static const progressLabel = 'Import progress';
  static const idleHint =
      'Optional — you can always add more later from Settings.';
}