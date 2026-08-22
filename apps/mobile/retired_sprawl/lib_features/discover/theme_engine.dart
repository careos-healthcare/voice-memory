import 'package:archiveme_mobile/features/discover/discover_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Recurring themes with frequency and trend for Discover Yourself.
class DiscoverThemeEngine {
  const DiscoverThemeEngine();

  static const _displayNames = {
    'career': 'Career',
    'relationship': 'Relationships',
    'relationships': 'Relationships',
    'health': 'Health',
    'family': 'Family',
    'confidence': 'Confidence',
    'money': 'Money',
    'purpose': 'Purpose',
    'stress': 'Stress',
    'work': 'Work',
  };

  List<DiscoverThemeInsight> build({
    required List<JournalEntry> entries,
    Map<String, int>? baselineThemes,
  }) {
    if (entries.length < 2) return const [];

    final current = DiscoverLocalThemeCounts.count(entries);
    final baseline = baselineThemes ?? {};

    final insights = <DiscoverThemeInsight>[];
    for (final entry in current.entries) {
      final key = entry.key;
      final freq = entry.value;
      if (freq < 1) continue;
      final before = baseline[key] ?? 0;
      final trend = before == 0
          ? ThemeTrendDirection.up
          : freq > before
          ? ThemeTrendDirection.up
          : freq < before
          ? ThemeTrendDirection.down
          : ThemeTrendDirection.flat;
      insights.add(
        DiscoverThemeInsight(
          name: _displayNames[key] ?? _titleCase(key),
          themeKey: key,
          frequency: freq,
          trend: trend,
          evidenceEntryIds: _entryIdsForTheme(entries, key),
        ),
      );
    }

    insights.sort((a, b) => b.frequency.compareTo(a.frequency));
    return insights.take(8).toList();
  }

  static String _titleCase(String raw) {
    if (raw.isEmpty) return raw;
    return raw[0].toUpperCase() + raw.substring(1);
  }

  static List<String> _entryIdsForTheme(
    List<JournalEntry> entries,
    String key,
  ) {
    final ids = <String>[];
    for (final e in entries) {
      final themes = e.reflection.recurringThemes
          .map((t) => t.trim().toLowerCase())
          .where((t) => t.isNotEmpty);
      if (themes.contains(key)) ids.add(e.id);
    }
    return ids.reversed.take(6).toList();
  }
}

/// Shared theme counting (also used by discover_local).
class DiscoverLocalThemeCounts {
  static Map<String, int> count(List<JournalEntry> entries) {
    final counts = <String, int>{};
    for (final e in entries) {
      for (final t in e.reflection.recurringThemes) {
        final k = t.trim().toLowerCase();
        if (k.isEmpty) continue;
        counts[k] = (counts[k] ?? 0) + 1;
      }
    }
    return counts;
  }
}