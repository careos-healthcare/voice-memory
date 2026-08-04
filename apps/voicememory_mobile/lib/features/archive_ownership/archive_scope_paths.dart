import 'local_archive_identity.dart';

/// The one place that maps an archive identity to on-device file locations.
///
/// Archives are partitioned physically. Two archives never share a journal
/// file, so an isolation mistake in one layer cannot expose another account's
/// saved moments through a different layer.
abstract final class ArchiveScopePaths {
  static String sanitize(String archiveId) =>
      archiveId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

  /// Directory holding every derived store for [identity].
  static String scopeDirectory({
    required String basePath,
    required LocalArchiveIdentity identity,
  }) => '$basePath/archives/${sanitize(identity.archiveId)}';

  /// Journal file for [identity].
  ///
  /// A legacy unclaimed archive keeps the pre-partition location so existing
  /// content stays readable until the user decides what happens to it.
  static String journalPath({
    required String basePath,
    required LocalArchiveIdentity identity,
  }) {
    if (identity.ownerKind == LocalArchiveOwnerKind.legacyUnclaimed) {
      return legacyJournalPath(basePath);
    }
    return '${scopeDirectory(basePath: basePath, identity: identity)}/journal_entries.json';
  }

  static String legacyJournalPath(String basePath) =>
      '$basePath/journal_entries.json';
}
