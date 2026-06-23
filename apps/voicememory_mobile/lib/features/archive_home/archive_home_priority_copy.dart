/// User-facing copy for Archive Home smart layout.
abstract final class ArchiveHomePriorityCopy {
  ArchiveHomePriorityCopy._();

  static const moreArchiveToolsTitle = 'More archive tools';
  static const moreArchiveToolsBody =
      'ArchiveMe keeps comparison, watchlist, and review history here so your sticky loop stays calm.';

  static Iterable<String> allVisibleCopy() sync* {
    yield moreArchiveToolsTitle;
    yield moreArchiveToolsBody;
  }
}
