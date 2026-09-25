import 'package:archiveme_mobile/features/archive_packs/archive_pack.dart';
import 'package:archiveme_mobile/features/archive_search/archive_search_filters.dart';
import 'package:archiveme_mobile/features/archive_search/archive_search_query.dart';
import 'package:archiveme_mobile/features/archive_search/archive_search_result.dart';
import 'package:archiveme_mobile/features/collections/archive_collection.dart';
import 'package:archiveme_mobile/features/fact_ledger/archive_fact.dart';
import 'package:archiveme_mobile/features/memory/archive_retrieval_policy.dart';
import 'package:archiveme_mobile/features/memory/archive_thread.dart';
import 'package:archiveme_mobile/features/memory/curated_memory_marker.dart';
import 'package:archiveme_mobile/features/memory/entry_aboutness.dart';
import 'package:archiveme_mobile/features/memory/memory_authority_framing_engine.dart';
import 'package:archiveme_mobile/features/memory/memory_surfacing_mode.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_context.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Archive Search 2.0 — local, deterministic entry search.
///
/// Pure read path: it matches a keyword over safe local entry text and
/// applies metadata filters (context tag, relative date, memory status,
/// exact evidence, pinned). It never mutates entries, never changes
/// memory state, never overrides Memory Scope Controls, and nothing
/// here logs or transmits query text.
class ArchiveEntrySearchEngine {
  const ArchiveEntrySearchEngine();

  /// Mirrors the authority framing thresholds so the derived status
  /// labels read the same as the memory cards.
  static const int changedLaterGapDays =
      MemoryAuthorityFramingEngine.supersededGapDays;
  static const int staleAfterDays = MemoryAuthorityFramingEngine.staleAfterDays;

  List<ArchiveEntrySearchResult> search({
    required List<JournalEntry> entries,
    required ArchiveEntrySearchQuery query, List<PressureCheckInRecord> records = const [],
    List<ArchiveCollection> collections = const [],
    List<ArchiveThread> threads = const [],
    List<ArchivePack> packs = const [],
    Set<String> entryIdsWithActionItems = const {},
    Set<String> entryIdsWithSavedDetails = const {},
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final recordsByEntryId = {for (final r in records) r.entryId: r};

    final results = <ArchiveEntrySearchResult>[];
    for (final entry in entries) {
      if (_isUnusable(entry)) continue;
      // Archived entries are hidden by default; the Archived filter
      // shows archived entries only.
      if (entry.isArchived != query.archivedOnly) continue;
      final record = recordsByEntryId[entry.id];

      if (query.hasKeyword && !_matchesKeyword(entry, query.keyword)) {
        continue;
      }
      if (query.contextTagId != null &&
          !(record?.contextIds.contains(query.contextTagId) ?? false)) {
        continue;
      }
      if (query.collectionId != null &&
          !collections.any(
            (c) => c.id == query.collectionId && c.contains(entry.id),
          )) {
        continue;
      }
      if (query.threadId != null && entry.archiveThreadId != query.threadId) {
        continue;
      }
      if (query.packId != null && entry.archivePackId != query.packId) {
        continue;
      }
      if (query.dateFilter != null &&
          !query.dateFilter!.contains(entry.createdAt, clock)) {
        continue;
      }
      final status = memoryStatusFor(entry, record, records, clock);
      if (query.memoryStatus != null && status != query.memoryStatus) {
        continue;
      }
      final isExact =
          entry.keepExactDetails || (record?.keepExactDetails ?? false);
      if (query.exactEvidenceOnly && !isExact) continue;
      if (query.pinnedOnly && !entry.isPinned) continue;
      if (query.actionItemsOnly &&
          !entryIdsWithActionItems.contains(entry.id)) {
        continue;
      }
      if (query.entryAboutnessId != null &&
          entry.entryAboutness != query.entryAboutnessId) {
        continue;
      }
      if (query.memorySurfacingId != null &&
          entry.memorySurfacing != query.memorySurfacingId) {
        continue;
      }
      if (query.preservedOriginalOnly &&
          !CuratedMemoryMarker.matchesPreservedFilter(entry)) {
        continue;
      }
      if (query.savedDetailsOnly &&
          !entryIdsWithSavedDetails.contains(entry.id)) {
        continue;
      }

      final surfacing = MemorySurfacingMode.fromEntry(entry);
      final surfacingChip = surfacing == MemorySurfacingMode.normal
          ? null
          : surfacing.label;

      final preservedChip = CuratedMemoryMarker.showsPreservedChip(entry)
          ? CuratedMemoryCopy.searchChipLabel
          : null;
      final savedDetailChip = entryIdsWithSavedDetails.contains(entry.id)
          ? FactLedgerCopy.searchChipLabel
          : null;

      results.add(
        ArchiveEntrySearchResult(
          entry: entry,
          timeBucket: ArchiveDateFilter.bucketFor(entry.createdAt, clock),
          contextTagLabels: record == null
              ? const []
              : record.contexts.map((c) => c.label).toList(),
          isPinned: entry.displayPresentation.showPinBadge,
          isExactEvidence: isExact,
          memoryStatus: status,
          collectionNames: [
            for (final c in collections)
              if (c.contains(entry.id)) c.name,
          ],
          threadLabel: _threadLabel(entry.archiveThreadId, threads),
          packLabel: _packLabel(entry.archivePackId, packs),
          entryTypeLabel:
              EntryAboutness.fromId(entry.displayPresentation.entryAboutness)
                  .label,
          surfacingLabel: surfacingChip,
          preservedOriginalLabel: preservedChip,
          savedDetailLabel: savedDetailChip,
        ),
      );
    }

    // Deterministic order: pinned first, then newest first.
    results.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.entry.createdAt.compareTo(a.entry.createdAt);
    });
    return results;
  }

  List<PressureContext> availableContextTags(
    List<PressureCheckInRecord> records,
  ) {
    final ids = <String>{};
    for (final record in records) {
      ids.addAll(record.contextIds);
    }
    return PressureContext.values.where((c) => ids.contains(c.id)).toList();
  }

  /// Archive threads referenced by [entries] — caller passes [allThreads].
  List<ArchiveThread> availableThreads(
    List<JournalEntry> entries,
    List<ArchiveThread> allThreads,
  ) {
    final ids = entries
        .map((e) => e.archiveThreadId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    return allThreads.where((t) => ids.contains(t.id)).toList();
  }

  List<ArchivePack> availablePacks(
    List<JournalEntry> entries,
    List<ArchivePack> allPacks,
  ) {
    final ids = entries
        .map((e) => e.archivePackId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    return allPacks.where((p) => ids.contains(p.id)).toList();
  }

  String? _threadLabel(String? threadId, List<ArchiveThread> threads) {
    if (threadId == null) return null;
    for (final thread in threads) {
      if (thread.id == threadId) return thread.name;
    }
    return null;
  }

  String? _packLabel(String? packId, List<ArchivePack> packs) {
    if (packId == null) return null;
    for (final pack in packs) {
      if (pack.id == packId) return pack.name;
    }
    return null;
  }

  bool _isUnusable(JournalEntry entry) {
    final text = entry.transcript.trim();
    return text.isEmpty || text.toLowerCase().startsWith('[draft]');
  }

  bool _matchesKeyword(JournalEntry entry, String keyword) {
    final term = keyword.trim().toLowerCase();
    if (term.isEmpty) return true;
    final haystack = [
      entry.transcript,
      entry.reflection.exactLanguagePattern,
      entry.reflection.concreteObservation,
      entry.reflection.repeatedSignal,
    ].join(' ').toLowerCase();
    return haystack.contains(term);
  }

  /// Read-only memory status derived from saved metadata, mirroring the
  /// evidence framing language. Cautious by design: user choices first
  /// (fresh, confirmed), then mixed/changed/stale signals, then current.
  /// Also used by selected-entry export so labels read the same.
  ArchiveMemoryStatus memoryStatusFor(
    JournalEntry entry,
    PressureCheckInRecord? record,
    List<PressureCheckInRecord> allRecords,
    DateTime now,
  ) {
    if (entry.treatAsNew ||
        entry.keepSeparate ||
        (record?.treatAsNew ?? false) ||
        (record?.keepSeparate ?? false)) {
      return ArchiveMemoryStatus.freshEntry;
    }
    if (entry.connectionApproved || (record?.connectionApproved ?? false)) {
      return ArchiveMemoryStatus.userConfirmed;
    }
    if (ArchiveRetrievalPolicy.isRecordNotQuite(entry.id)) {
      return ArchiveMemoryStatus.mixedEvidence;
    }
    if (record != null && _changedLater(record, allRecords)) {
      return ArchiveMemoryStatus.changedLater;
    }
    if (now.difference(entry.createdAt).inDays > staleAfterDays) {
      return ArchiveMemoryStatus.mayBeStale;
    }
    return ArchiveMemoryStatus.stillCurrent;
  }

  /// The archive moved on: a much newer record shares one of this
  /// record's explicit context tags.
  bool _changedLater(
    PressureCheckInRecord record,
    List<PressureCheckInRecord> allRecords,
  ) {
    for (final other in allRecords) {
      if (other.entryId == record.entryId) continue;
      if (!other.contextIds.any(record.contextIds.contains)) continue;
      if (other.createdAt.difference(record.createdAt).inDays >=
          changedLaterGapDays) {
        return true;
      }
    }
    return false;
  }
}