import '../../models/journal_entry.dart';
import '../../storage/journal_entry_decoder.dart';

/// Hardened journal pull pagination with cursor cycle detection.
class JournalPullPaginator {
  JournalPullPaginator({this.maxPages = 50, this.maxEntries = 10000});

  final int maxPages;
  final int maxEntries;

  final Set<String> _seenCursors = {};
  final Set<String> _seenIds = {};
  var _pageCount = 0;
  var _entryCount = 0;

  JournalPullPageResult ingestPage({
    required List<dynamic> rawEntries,
    String? nextCursor,
    String? currentCursor,
  }) {
    _pageCount++;
    if (_pageCount > maxPages) {
      return JournalPullPageAborted('max_pages_exceeded');
    }

    if (currentCursor != null && currentCursor.isNotEmpty) {
      if (_seenCursors.contains(currentCursor)) {
        return JournalPullPageAborted('cyclic_cursor');
      }
      _seenCursors.add(currentCursor);
    }

    if (nextCursor != null &&
        nextCursor.isNotEmpty &&
        nextCursor == currentCursor) {
      return JournalPullPageAborted('repeated_cursor');
    }

    final quarantined = <JournalDecodeQuarantined>[];
    final accepted = JournalEntryDecoder.decodeList(
      rawEntries,
      quarantineOut: quarantined,
    );

    final deduped = <JournalEntry>[];
    for (final entry in accepted) {
      if (_seenIds.contains(entry.id)) continue;
      _seenIds.add(entry.id);
      deduped.add(entry);
      _entryCount++;
      if (_entryCount > maxEntries) {
        return JournalPullPageAborted('max_entries_exceeded');
      }
    }

    return JournalPullPageAccepted(
      entries: deduped,
      quarantined: quarantined,
      nextCursor: nextCursor,
    );
  }
}

sealed class JournalPullPageResult {
  const JournalPullPageResult();
}

final class JournalPullPageAccepted extends JournalPullPageResult {
  JournalPullPageAccepted({
    required this.entries,
    required this.quarantined,
    this.nextCursor,
  });
  final List<JournalEntry> entries;
  final List<JournalDecodeQuarantined> quarantined;
  final String? nextCursor;
}

final class JournalPullPageAborted extends JournalPullPageResult {
  JournalPullPageAborted(this.reason);
  final String reason;
}
