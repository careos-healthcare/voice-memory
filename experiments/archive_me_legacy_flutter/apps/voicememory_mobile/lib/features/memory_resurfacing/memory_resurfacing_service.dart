import '../../models/journal_entry.dart';
import '../archive_state_object/archive_state_object.dart';
import '../theme_tracking/theme_tracker_service.dart';
import '../../storage/mobile_prefs_store.dart';
import 'memory_resurfacing_models.dart';
import 'memory_resurfacing_store.dart';

/// Surfaces older reflections that connect to the archive's current themes.
class MemoryResurfacingService {
  MemoryResurfacingService(this._store);

  final MemoryResurfacingStore _store;

  static const Duration minAge = Duration(days: 30);
  static const int defaultHomeLimit = 2;
  static const int defaultArchiveLimit = 4;

  Future<MemoryResurfacingStats> stats() => _store.stats();

  Future<List<MemoryResurfacingCardData>> selectCards({
    required List<JournalEntry> entries,
    String? currentBelief,
    int limit = defaultHomeLimit,
    DateTime? now,
  }) async {
    final clock = now ?? DateTime.now();
    final cutoff = clock.subtract(minAge);
    final resurfaced = await _store.resurfacedEntryIds();
    final themes = _activeArchiveThemes(entries);
    final belief = currentBelief?.trim() ?? '';

    final candidates = <_ScoredCandidate>[];
    for (final entry in entries) {
      if (!_isEligibleRecording(entry)) continue;
      if (!entry.createdAt.isBefore(cutoff)) continue;
      if (resurfaced.contains(entry.id)) continue;
      if (!_relatesToArchiveThemes(entry, themes, belief)) continue;

      final themeScore = _themeOverlapScore(entry, themes, belief);
      final ageDays = clock.difference(entry.createdAt).inDays;
      candidates.add(
        _ScoredCandidate(
          entry: entry,
          themeScore: themeScore,
          ageDays: ageDays,
        ),
      );
    }

    candidates.sort((a, b) {
      final byTheme = b.themeScore.compareTo(a.themeScore);
      if (byTheme != 0) return byTheme;
      return b.ageDays.compareTo(a.ageDays);
    });

    return candidates
        .take(limit)
        .map(
          (c) => _toCard(c.entry, now: clock, themes: themes, belief: belief),
        )
        .toList();
  }

  Future<void> markShown(Iterable<String> entryIds) async {
    await _store.markResurfaced(entryIds);
  }

  Future<void> markOpened(String entryId) async {
    await _store.markOpened(entryId);
  }

  static MemoryResurfacingService fromPrefs(MobilePrefsStore prefs) {
    return MemoryResurfacingService(MemoryResurfacingStore(prefs));
  }
}

class _ScoredCandidate {
  const _ScoredCandidate({
    required this.entry,
    required this.themeScore,
    required this.ageDays,
  });

  final JournalEntry entry;
  final int themeScore;
  final int ageDays;
}

bool _isEligibleRecording(JournalEntry entry) {
  final transcript = entry.transcript.trim();
  if (transcript.isNotEmpty && !transcript.startsWith('[draft]')) {
    return true;
  }
  return entry.reflection.concreteObservation.trim().length >= 12;
}

Set<String> _activeArchiveThemes(List<JournalEntry> entries) {
  final tracked = const ThemeTrackerService().track(entries: entries);
  final themes = <String>{};
  for (final theme in tracked.topThemes) {
    if (theme.frequency < 2) continue;
    final id = ThemeTrackerService.displayNames.entries
        .where((e) => e.value == theme.name)
        .map((e) => e.key)
        .firstOrNull;
    if (id != null) themes.add(id);
  }
  if (themes.isNotEmpty) return themes;

  for (final entry in entries) {
    themes.addAll(ThemeTrackerService.themesForEntry(entry));
    if (themes.length >= 3) break;
  }
  return themes;
}

bool _relatesToArchiveThemes(
  JournalEntry entry,
  Set<String> themes,
  String belief,
) {
  final entryThemes = {
    ...ThemeTrackerService.themesForEntry(entry),
    ...entry.reflection.recurringThemes
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty),
  };

  if (themes.isNotEmpty) {
    for (final t in entryThemes) {
      if (themes.contains(t)) return true;
      for (final active in themes) {
        if (t.contains(active) || active.contains(t)) return true;
      }
    }
  }

  if (belief.length < 12) return false;
  final beliefLower = belief.toLowerCase();
  for (final t in entryThemes) {
    if (beliefLower.contains(t)) return true;
  }

  final blob = _entryTextBlob(entry).toLowerCase();
  for (final word in beliefLower.split(RegExp(r'[^a-z0-9]+'))) {
    if (word.length >= 5 && blob.contains(word)) return true;
  }
  return false;
}

int _themeOverlapScore(JournalEntry entry, Set<String> themes, String belief) {
  var score = 0;
  final entryThemes = {
    ...ThemeTrackerService.themesForEntry(entry),
    ...entry.reflection.recurringThemes
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty),
  };

  for (final t in entryThemes) {
    if (themes.contains(t)) score += 3;
    if (belief.toLowerCase().contains(t)) score += 2;
    for (final active in themes) {
      if (t.contains(active) || active.contains(t)) score += 2;
    }
  }
  return score;
}

String _entryTextBlob(JournalEntry entry) {
  return [
    entry.transcript,
    entry.reflection.exactLanguagePattern,
    entry.reflection.concreteObservation,
    entry.reflection.repeatedSignal,
  ].join(' ');
}

MemoryResurfacingCardData _toCard(
  JournalEntry entry, {
  required DateTime now,
  required Set<String> themes,
  required String belief,
}) {
  final local = entry.createdAt.toLocal();
  final quote = _quoteSnippet(entry);
  return MemoryResurfacingCardData(
    entry: entry,
    headline: resurfacingHeadline(entry.createdAt, now),
    quoteSnippet: quote,
    originalDateLabel: _formatOriginalDate(local),
    beliefRelation: _beliefRelationLine(entry, themes, belief),
  );
}

String resurfacingHeadline(DateTime createdAt, DateTime now) {
  final days = now.difference(createdAt).inDays;
  if (days >= 365) {
    final years = (days / 365).floor();
    return years <= 1
        ? 'You said this 1 year ago.'
        : 'You said this $years years ago.';
  }
  final months = (days / 30).round().clamp(1, 11);
  if (months <= 1) return 'You said this about a month ago.';
  return 'You said this $months months ago.';
}

String _quoteSnippet(JournalEntry entry) {
  final exact = entry.reflection.exactLanguagePattern.trim();
  if (exact.length >= 12) {
    return exact.length <= 160 ? exact : '${exact.substring(0, 160).trim()}…';
  }
  final transcript = entry.transcript.trim();
  if (transcript.isNotEmpty) {
    final line = transcript.split('\n').first.trim();
    return line.length <= 160 ? line : '${line.substring(0, 160).trim()}…';
  }
  final obs = entry.reflection.concreteObservation.trim();
  return obs.isEmpty ? 'Saved voice moment' : obs;
}

String _formatOriginalDate(DateTime local) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
}

String _beliefRelationLine(
  JournalEntry entry,
  Set<String> themes,
  String belief,
) {
  final matched = <String>{};
  for (final id in ThemeTrackerService.themesForEntry(entry)) {
    if (themes.contains(id)) {
      matched.add(ThemeTrackerService.displayNames[id] ?? id);
    }
  }
  for (final raw in entry.reflection.recurringThemes) {
    final t = raw.trim();
    if (t.isEmpty) continue;
    final lower = t.toLowerCase();
    if (themes.contains(lower)) matched.add(t);
  }

  if (matched.isNotEmpty) {
    final label = matched.take(3).join(', ');
    return belief.isNotEmpty
        ? 'Relates to your current archive belief — themes: $label.'
        : 'Connects to active archive themes: $label.';
  }

  if (belief.isNotEmpty) {
    return 'Echoes themes in your current archive belief.';
  }

  return 'Part of the thread your archive is tracking now.';
}

/// Convenience: belief from entries using archive v3 rules.
Future<List<MemoryResurfacingCardData>> selectResurfacingForJournal({
  required MemoryResurfacingService service,
  required Future<List<JournalEntry>> Function() loadEntries,
  int limit = MemoryResurfacingService.defaultHomeLimit,
}) async {
  final entries = await loadEntries();
  final state = buildArchiveStateObjectV3(entries: entries);
  return service.selectCards(
    entries: entries,
    currentBelief: state?.belief,
    limit: limit,
  );
}
