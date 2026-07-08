/// Copy for first-run revenue positioning — education only, no Pro CTA.
abstract final class FirstRunPositioningCopy {
  FirstRunPositioningCopy._();

  static const title = 'Build a timeline, not a journal';

  static const body =
      'Save small moments when something stands out. ArchiveMe looks for what returns, changes, fades, or becomes useful.';

  static const footer =
      'Free shows the first proof. Pro keeps the longer timeline.';

  static Iterable<String> allVisibleStrings() sync* {
    yield title;
    yield body;
    yield footer;
  }
}
