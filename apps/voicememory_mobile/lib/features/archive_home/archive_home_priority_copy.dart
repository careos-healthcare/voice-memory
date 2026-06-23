/// User-facing copy for Archive Home smart layout.
abstract final class ArchiveHomePriorityCopy {
  ArchiveHomePriorityCopy._();

  static const moreArchiveToolsTitle = 'More archive tools';
  static const moreArchiveToolsBody =
      'ArchiveMe keeps advanced tools here so your main view stays calm.';

  static Iterable<String> allVisibleCopy() sync* {
    yield moreArchiveToolsTitle;
    yield moreArchiveToolsBody;
  }
}
