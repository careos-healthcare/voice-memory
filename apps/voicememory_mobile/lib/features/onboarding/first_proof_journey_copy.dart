/// Compact first-proof journey strip on Record — not homework, not a streak.
abstract final class FirstProofJourneyCopy {
  FirstProofJourneyCopy._();

  static const strip = '1 Save → 2 Compare → 3 First thread';

  static const helper =
      'One moment starts the archive. A few real moments let ArchiveMe compare what returns.';

  static Iterable<String> allVisibleStrings() sync* {
    yield strip;
    yield helper;
  }
}
