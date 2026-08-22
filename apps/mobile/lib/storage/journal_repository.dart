import 'package:archiveme_mobile/models/journal_entry.dart';

/// Repository abstraction over durable journal storage.
///
/// Production still defaults to JSON-file backing; Drift implementation is
/// guarded behind [JournalRepositoryConfig.useDriftByDefault].
abstract class JournalRepository {
  Future<List<JournalEntry>> loadAllIncludingTombstones();
  Future<List<JournalEntry>> loadAll();
  Future<void> save(JournalEntry entry);
  Future<void> mergeRemoteBatch(List<JournalEntry> remote);
  Future<void> markSyncedBatch(Set<String> ids);
  Future<int> compactTombstonesBatch({Duration retention});
}

/// Feature flag for encrypted SQLite rollout.
abstract final class JournalRepositoryConfig {
  JournalRepositoryConfig._();

  /// Remains false until Drift migration equivalence tests pass.
  static const bool useDriftByDefault = false;
}