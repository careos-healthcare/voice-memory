import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/archive_watchlist/archive_watchlist_copy.dart';
import 'package:archiveme_mobile/features/archive_watchlist/archive_watchlist_gates.dart';
import 'package:archiveme_mobile/features/archive_watchlist/archive_watchlist_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Deterministic local matching — counts only, no raw entry exposure.
class ArchiveWatchlistEngine {
  const ArchiveWatchlistEngine();

  static const _presetKeywords = <String, List<String>>{
    'unclear_decisions': [
      'decision',
      'decide',
      'unclear',
      'unsure',
      'stuck',
      'choice',
      'choose',
      'undecided',
    ],
    'work_patterns': [
      'work',
      'office',
      'meeting',
      'deadline',
      'colleague',
      'manager',
      'job',
      'project',
    ],
    'repeated_thoughts': [
      'again',
      'same thought',
      'keep thinking',
      'recurring',
      'repeat',
      'over and over',
      'same worry',
    ],
    'lighter_after_writing': [
      'lighter',
      'relief',
      'clearer',
      'calmer',
      'after writing',
      'felt better',
      'less heavy',
    ],
    'avoided_tasks': [
      'avoid',
      'procrastinat',
      'put off',
      'delay',
      'skipped',
      "didn't start",
      'postpone',
      'kept putting',
    ],
  };

  ArchiveWatchlistCardResult build({
    required List<JournalEntry> entries,
    required List<ArchiveWatchlistItem> items,
    required int entryCount,
  }) {
    final saved = _realEntries(entries);
    final itemResults = items
        .map((item) => evaluateItem(item: item, entries: saved))
        .toList();

    return ArchiveWatchlistCardResult(
      items: items,
      itemResults: itemResults,
      showProLine: ArchiveWatchlistGates.showProLine(
        watchThemeCount: items.length,
        entryCount: entryCount,
      ),
      atThemeLimit: items.length >= ArchiveWatchlistCopy.maxThemes,
    );
  }

  ArchiveWatchlistItemResult evaluateItem({
    required ArchiveWatchlistItem item,
    required List<JournalEntry> entries,
  }) {
    final label = item.resolveLabel(ArchiveWatchlistCopy.presets);
    final keywords = _keywordsForItem(item);
    var count = 0;
    for (final entry in entries) {
      if (_entryMatches(entry, keywords)) count++;
    }
    return ArchiveWatchlistItemResult(
      item: item,
      label: label,
      matchCount: count,
    );
  }

  static List<String> _keywordsForItem(ArchiveWatchlistItem item) {
    if (item.presetId == ArchiveWatchlistItem.customPresetId) {
      return _tokenizeCustomLabel(item.customLabel ?? '');
    }
    return _presetKeywords[item.presetId] ?? const [];
  }

  static List<String> _tokenizeCustomLabel(String label) {
    return label
        .toLowerCase()
        .split(RegExp('[^a-z0-9]+'))
        .where((token) => token.length >= 3)
        .toList();
  }

  static bool _entryMatches(JournalEntry entry, List<String> keywords) {
    if (keywords.isEmpty) return false;
    final haystack = _entrySearchText(entry);
    if (haystack.isEmpty) return false;
    return keywords.any(haystack.contains);
  }

  static String _entrySearchText(JournalEntry entry) {
    final parts = <String>[
      entry.transcript,
      entry.reflection.concreteObservation,
      entry.reflection.repeatedSignal,
      entry.reflection.exactLanguagePattern,
      ...entry.reflection.recurringThemes,
    ];
    return parts.join(' ').toLowerCase();
  }

  static List<JournalEntry> _realEntries(List<JournalEntry> entries) {
    final saved = entries
        .where(
          (e) =>
              e.transcript.trim().isNotEmpty &&
              !e.transcript.startsWith('[draft]'),
        )
        .toList();
    return ArchiveEvidenceGuard.eligibleEntries(saved);
  }
}