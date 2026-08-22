/// User-facing copy for helped tracking — user-reported evidence only.
abstract final class HelpedTrackingCopy {
  HelpedTrackingCopy._();

  static const question = 'Did anything help this time?';

  static const sheetTitle = 'What helped?';
  static const sheetFieldLabel = 'What helped, if anything?';
  static const saveCta = 'Save';
  static const cancelCta = 'Cancel';

  static const savedMessage =
      'Saved. ArchiveMe will watch whether that helps again.';

  static String singleReported(String actionLabel) =>
      'You marked that you $actionLabel this time.';

  static String strongerWithSofter(String actionLabel) =>
      'The last time you $actionLabel, the pressure felt softer.';

  static String archiveHistoryNote(String actionLabel) =>
      'Marked: $actionLabel';
}