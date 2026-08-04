/// Beta-only today summary copy — optional recording, no daily pressure.
abstract final class BetaTodaySummaryCopy {
  BetaTodaySummaryCopy._();

  static const corePositioning =
      'You do not need to record today. Record only if something stands out.';

  static const title = 'Today in your archive';

  static const primaryBody =
      'You do not need to record today. Here is what ArchiveMe is currently watching.';

  static const fallbackBody =
      'Save a small moment when something stands out. It does not need to be daily.';

  static const activePatternRow = 'One pattern is still active';

  static const fadingRow = 'One signal is fading';

  static const correctionRow =
      'One correction changed how ArchiveMe treats a pattern';

  static const needsFreshProofRow =
      'ArchiveMe needs fresh proof before treating this as current';

  static const noStrongPatternRow = 'No strong pattern yet';

  static const nothingUrgentRow = 'Nothing urgent today';

  static const closingLine = 'Record if something stands out.';

  static List<String> allVisibleStrings() => [
    corePositioning,
    title,
    primaryBody,
    fallbackBody,
    activePatternRow,
    fadingRow,
    correctionRow,
    needsFreshProofRow,
    noStrongPatternRow,
    nothingUrgentRow,
    closingLine,
  ];
}
