import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/api/api_exceptions.dart';
import 'package:archiveme_mobile/features/archive/v1/archive_belief_load_state.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/features/insight_engine/hybrid_search_engine.dart';
import 'package:archiveme_mobile/features/insight_engine/hybrid_search_models.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/sqlite/journal_sqlite_repository.dart';

/// Loads and sorts archive entries for the V1 Archive tab.
class ArchiveBeliefRepository {
  ArchiveBeliefRepository({
    required this.journalStore,
    required this.journalSqlite,
    HybridSearchEngine? hybridSearch,
  }) : _hybridSearch = hybridSearch;

  final JournalStore journalStore;
  final JournalSqliteRepository journalSqlite;
  final HybridSearchEngine? _hybridSearch;

  static const pageSize = JournalSqliteRepository.defaultPageSize;

  Future<void> syncJournalMirror() async {
    try {
      final entries = await journalStore.loadAllIncludingTombstones();
      await journalSqlite.mirrorEntireRemoteState(entries);
    } on SocketException {
      rethrow;
    } on NetworkOfflineException {
      rethrow;
    } on TimeoutException {
      rethrow;
    }
  }

  Future<int> countActive({String? searchQuery}) {
    return journalSqlite.countActive(searchQuery: searchQuery);
  }

  Future<List<JournalEntry>> fetchPage({
    required int offset,
    int limit = pageSize,
    String? searchQuery,
  }) {
    return journalSqlite.fetchPage(
      offset: offset,
      limit: limit,
      searchQuery: searchQuery,
    );
  }

  Future<List<JournalEntry>> fetchPageAfter({
    JournalFeedCursor? after,
    int limit = pageSize,
    String? searchQuery,
  }) {
    return journalSqlite.fetchPageAfter(
      limit: limit,
      afterCreatedAt: after?.createdAt,
      afterId: after?.id,
      searchQuery: searchQuery,
    );
  }

  Future<List<JournalEntry>> fetchProofContextStubs() {
    return journalSqlite.fetchProofContextStubs();
  }

  Future<List<JournalEntry>> fetchVerifiedProofEntries() {
    return journalSqlite.fetchVerifiedProofEntries();
  }

  /// Hybrid FTS5 + vector retrieval over the local journal mirror.
  ///
  /// Requires [HybridSearchEngine] to be injected; returns an empty list when
  /// hybrid search is not configured.
  Future<List<HybridSearchHit>> searchHybrid({
    String? keywordQuery,
    List<double>? queryEmbedding,
    int limit = 20,
  }) async {
    final engine = _hybridSearch;
    if (engine == null) return const [];
    await syncJournalMirror();
    return engine.search(
      keywordQuery: keywordQuery,
      queryEmbedding: queryEmbedding,
      limit: limit,
    );
  }

  /// Legacy eager load — kept for unit tests that assert sort order.
  Future<ArchiveBeliefLoadResult> loadSortedEntries() async {
    try {
      await syncJournalMirror();
      final entries = await fetchPage(offset: 0, limit: 1 << 20);
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