/// Copy for the compact archive-watching status line.
abstract final class ArchiveWatchingCopy {
  ArchiveWatchingCopy._();

  static const prefix = 'ArchiveMe is watching:';

  static const missingTriggerFocus = 'what happens before this repeat';
  static const missingChangeFocus = 'whether it gets softer';
  static const missingPositiveFocus = 'what helps';

  static const allKnownLine = 'ArchiveMe is watching how this changes next.';

  static String gapLine(String focus) => '$prefix $focus';
}
