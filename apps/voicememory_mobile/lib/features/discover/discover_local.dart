import '../../models/journal_entry.dart';

class DiscoverChangeItem {
  const DiscoverChangeItem({
    required this.title,
    required this.detail,
    required this.kind,
  });

  final String title;
  final String detail;
  final String kind;
}

class DiscoverLocalFeed {
  const DiscoverLocalFeed({
    required this.hasBaseline,
    required this.totalChanges,
    required this.strengthened,
    required this.weakened,
    required this.newItems,
    required this.evidenceMovements,
  });

  final bool hasBaseline;
  final int totalChanges;
  final List<DiscoverChangeItem> strengthened;
  final List<DiscoverChangeItem> weakened;
  final List<DiscoverChangeItem> newItems;
  final List<DiscoverChangeItem> evidenceMovements;
}

class DiscoverLocalEngine {
  static Map<String, int> themeCounts(List<JournalEntry> entries) {
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

  static DiscoverLocalFeed build({
    required List<JournalEntry> entries,
    Map<String, int>? baselineThemes,
  }) {
    final current = themeCounts(entries);
    if (baselineThemes == null || baselineThemes.isEmpty) {
      return DiscoverLocalFeed(
        hasBaseline: false,
        totalChanges: 0,
        strengthened: const [],
        weakened: const [],
        newItems: const [],
        evidenceMovements: const [],
      );
    }

    final strengthened = <DiscoverChangeItem>[];
    final weakened = <DiscoverChangeItem>[];
    final newItems = <DiscoverChangeItem>[];
    final evidence = <DiscoverChangeItem>[];

    for (final entry in current.entries) {
      final before = baselineThemes[entry.key] ?? 0;
      final after = entry.value;
      if (before == 0 && after >= 2) {
        newItems.add(
          DiscoverChangeItem(
            title: entry.key,
            detail: 'May be emerging across recent reflections.',
            kind: 'new',
          ),
        );
      } else if (after > before) {
        strengthened.add(
          DiscoverChangeItem(
            title: entry.key,
            detail: 'May be showing up more often since your last visit.',
            kind: 'strengthened',
          ),
        );
      } else if (after < before && before >= 2) {
        weakened.add(
          DiscoverChangeItem(
            title: entry.key,
            detail: 'May be appearing less in recent reflections.',
            kind: 'weakened',
          ),
        );
      }
    }

    if (entries.length > (baselineThemes['__count'] ?? 0)) {
      evidence.add(
        DiscoverChangeItem(
          title: 'New reflections',
          detail:
              '${entries.length - (baselineThemes['__count'] ?? 0)} new reflection(s) since last visit.',
          kind: 'evidence',
        ),
      );
    }

    final total = strengthened.length + weakened.length + newItems.length;
    return DiscoverLocalFeed(
      hasBaseline: true,
      totalChanges: total,
      strengthened: strengthened,
      weakened: weakened,
      newItems: newItems,
      evidenceMovements: evidence,
    );
  }

  static Map<String, int> baselineFromEntries(List<JournalEntry> entries) {
    final themes = themeCounts(entries);
    themes['__count'] = entries.length;
    return themes;
  }
}
