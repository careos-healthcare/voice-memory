import 'dart:async';
import 'dart:io';

import '../../../api/api_exceptions.dart';
import '../../../models/journal_entry.dart';
import '../../../storage/journal_store.dart';
import 'archive_belief_load_state.dart';

/// Loads and sorts archive entries for the V1 Archive tab.
class ArchiveBeliefRepository {
  ArchiveBeliefRepository({required this.journalStore});

  final JournalStore journalStore;

  Future<ArchiveBeliefLoadResult> loadSortedEntries() async {
    try {
      final entries = (await journalStore.loadAll()).toList();
      entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return ArchiveBeliefLoadSuccess(entries);
    } on SocketException {
      return const ArchiveBeliefLoadOffline();
    } on NetworkOfflineException {
      return const ArchiveBeliefLoadOffline();
    } on TimeoutException {
      return const ArchiveBeliefLoadOffline();
    } on Object {
      return const ArchiveBeliefLoadFailure();
    }
  }
}
