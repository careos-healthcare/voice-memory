/// Shared-element tags for archive entry card → detail transitions.
abstract final class ArchiveEntryHeroTags {
  ArchiveEntryHeroTags._();

  static String surface(String entryId) => 'archive-entry-surface-$entryId';

  static String meta(String entryId) => 'archive-entry-meta-$entryId';

  static String preview(String entryId) => 'archive-entry-preview-$entryId';
}
