import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/api/api_exceptions.dart';
import 'package:archiveme_mobile/core/di/archive_feed_providers.dart';
import 'package:archiveme_mobile/features/archive/v1/archive_belief_load_state.dart';
import 'package:archiveme_mobile/features/archive/v1/archive_belief_repository.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/storage/sqlite/journal_sqlite_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Paginated Archive Home feed backed by SQLite journal mirror queries.
class ArchiveFeedState {
  const ArchiveFeedState({
    this.loadState = ArchiveBeliefLoadState.loading,
    this.entries = const [],
    this.proofContextEntries = const [],
    this.verifiedProofEntries = const [],
    this.totalCount = 0,
    this.archiveTotalCount = 0,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.searchQuery = '',
  });

  const ArchiveFeedState.initial() : this();

  final ArchiveBeliefLoadState loadState;
  final List<JournalEntry> entries;
  final List<JournalEntry> proofContextEntries;
  final List<JournalEntry> verifiedProofEntries;
  final int totalCount;
  /// Active entries in the archive before the current search filter.
  final int archiveTotalCount;
  final bool hasMore;
  final bool isLoadingMore;
  final String searchQuery;

  bool get showSearchField => archiveTotalCount > 1;

  bool get showsNoSearchResults =>
      loadState == ArchiveBeliefLoadState.loaded &&
      archiveTotalCount > 0 &&
      searchQuery.isNotEmpty &&
      entries.isEmpty;

  ArchiveFeedState copyWith({
    ArchiveBeliefLoadState? loadState,
    List<JournalEntry>? entries,
    List<JournalEntry>? proofContextEntries,
    List<JournalEntry>? verifiedProofEntries,
    int? totalCount,
    int? archiveTotalCount,
    bool? hasMore,
    bool? isLoadingMore,
    String? searchQuery,
  }) {
    return ArchiveFeedState(
      loadState: loadState ?? this.loadState,
      entries: entries ?? this.entries,
      proofContextEntries: proofContextEntries ?? this.proofContextEntries,
      verifiedProofEntries: verifiedProofEntries ?? this.verifiedProofEntries,
      totalCount: totalCount ?? this.totalCount,
      archiveTotalCount: archiveTotalCount ?? this.archiveTotalCount,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class ArchiveFeedPaginationNotifier extends Notifier<ArchiveFeedState> {
  ArchiveBeliefRepository get _repository =>
      ref.read(archiveBeliefRepositoryProvider);

  @override
  ArchiveFeedState build() => const ArchiveFeedState.initial();

  Future<void> refresh() async {
    final isInitialLoad = state.loadState == ArchiveBeliefLoadState.loading &&
        state.entries.isEmpty;
    if (isInitialLoad) {
      state = state.copyWith(loadState: ArchiveBeliefLoadState.loading);
    }

    try {
      await _repository.syncJournalMirror();
      final query = state.searchQuery;
      final totalCount = await _repository.countActive(searchQuery: query);
      final archiveTotalCount = query.isEmpty
          ? totalCount
          : await _repository.countActive();
      final firstPage = await _repository.fetchPageAfter(
        searchQuery: state.searchQuery,
      );
      final proofContext = await _repository.fetchProofContextStubs();
      final verifiedProofEntries = await _repository.fetchVerifiedProofEntries();

      state = ArchiveFeedState(
        loadState: ArchiveBeliefLoadState.loaded,
        entries: firstPage,
        proofContextEntries: proofContext,
        verifiedProofEntries: verifiedProofEntries,
        totalCount: totalCount,
        archiveTotalCount: archiveTotalCount,
        hasMore: firstPage.length < totalCount,
        searchQuery: state.searchQuery,
      );
    } on SocketException {
      state = state.copyWith(loadState: ArchiveBeliefLoadState.offline);
    } on NetworkOfflineException {
      state = state.copyWith(loadState: ArchiveBeliefLoadState.offline);
    } on TimeoutException {
      state = state.copyWith(loadState: ArchiveBeliefLoadState.offline);
    } on Object {
      state = state.copyWith(loadState: ArchiveBeliefLoadState.error);
    }
  }

  Future<void> loadNextPage() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);
    try {
      final lastEntry = state.entries.last;
      final nextPage = await _repository.fetchPageAfter(
        after: JournalFeedCursor(
          createdAt: lastEntry.createdAt,
          id: lastEntry.id,
        ),
        searchQuery: state.searchQuery,
      );
      final merged = [...state.entries, ...nextPage];
      state = state.copyWith(
        entries: merged,
        hasMore: merged.length < state.totalCount,
        isLoadingMore: false,
      );
    } on Object {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> updateSearchQuery(String query) async {
    if (query == state.searchQuery) return;
    state = state.copyWith(
      searchQuery: query,
      loadState: ArchiveBeliefLoadState.loading,
      entries: const [],
      hasMore: false,
      isLoadingMore: false,
    );
    await refresh();
  }
}

final archiveFeedPaginationProvider =
    NotifierProvider<ArchiveFeedPaginationNotifier, ArchiveFeedState>(
  ArchiveFeedPaginationNotifier.new,
);