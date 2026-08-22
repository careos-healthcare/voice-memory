import 'package:archiveme_mobile/core/di/storage_providers.dart'
    show hybridSearchEngineProvider, journalSqliteRepositoryProvider;
import 'package:archiveme_mobile/features/archive/v1/archive_belief_repository.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class JournalStoreHolder {
  JournalStore? value;
}

final journalStoreHolderProvider = Provider<JournalStoreHolder>(
  (ref) => JournalStoreHolder(),
);

final journalStoreProvider = Provider<JournalStore>((ref) {
  final store = ref.watch(journalStoreHolderProvider).value;
  if (store == null) {
    throw StateError('JournalStore has not been bound yet');
  }
  return store;
});

final archiveBeliefRepositoryProvider = Provider<ArchiveBeliefRepository>(
  (ref) => ArchiveBeliefRepository(
    journalStore: ref.watch(journalStoreProvider),
    journalSqlite: ref.watch(journalSqliteRepositoryProvider),
    hybridSearch: ref.watch(hybridSearchEngineProvider),
  ),
);