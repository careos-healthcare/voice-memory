import '../../models/journal_entry.dart';

/// Isolated sample-archive mode — in-memory demo entries only, never persisted.
abstract final class SampleArchiveMode {
  SampleArchiveMode._();

  static const entryIdPrefix = 'sample_archive_';

  static bool isSampleEntry(JournalEntry entry) =>
      entry.id.startsWith(entryIdPrefix);

  static bool isSampleEntryId(String id) => id.startsWith(entryIdPrefix);

  /// Strips demo entries so real archive engines and exports stay untouched.
  static List<JournalEntry> excludeSampleEntries(List<JournalEntry> entries) =>
      entries.where((entry) => !isSampleEntry(entry)).toList();
}
