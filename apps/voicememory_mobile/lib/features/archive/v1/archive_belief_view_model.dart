import '../../../models/journal_entry.dart';
import 'archive_belief_load_state.dart';
import 'archive_belief_repository.dart';
import 'archive_belief_search_state.dart';

/// Flow-scoped archive tab state — load, search, and filtered entry access.
class ArchiveBeliefViewModel {
  ArchiveBeliefViewModel({
    required this.repository,
    ArchiveBeliefSearchState? search,
  }) : search = search ?? ArchiveBeliefSearchState();

  final ArchiveBeliefRepository repository;
  final ArchiveBeliefSearchState search;

  ArchiveBeliefLoadState loadState = ArchiveBeliefLoadState.loading;
  List<JournalEntry>? entries;

  bool get showSearchField => (entries?.length ?? 0) > 1;

  List<JournalEntry> get visibleEntries {
    final loaded = entries;
    if (loaded == null) return const [];
    return search.filter(loaded);
  }

  bool get showsNoSearchResults =>
      entries != null && entries!.isNotEmpty && visibleEntries.isEmpty;

  Future<void> reload() async {
    if (entries == null) {
      loadState = ArchiveBeliefLoadState.loading;
    }
    final result = await repository.loadSortedEntries();
    switch (result) {
      case ArchiveBeliefLoadSuccess(:final entries):
        this.entries = entries;
        loadState = ArchiveBeliefLoadState.loaded;
      case ArchiveBeliefLoadOffline():
        loadState = ArchiveBeliefLoadState.offline;
      case ArchiveBeliefLoadFailure():
        loadState = ArchiveBeliefLoadState.error;
    }
  }
}
