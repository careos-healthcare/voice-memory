import '../../models/journal_entry.dart';
import '../timeline/timeline_models.dart';
import 'discover_models.dart';

/// Month-by-month growth summaries for Discover Yourself.
class DiscoverGrowthTimelineEngine {
  const DiscoverGrowthTimelineEngine();

  List<DiscoverGrowthMonth> build(List<JournalEntry> entries) {
    if (entries.isEmpty) return const [];

    final byMonth = <String, List<JournalEntry>>{};
    for (final e in entries) {
      final local = e.createdAt.toLocal();
      final key = '${local.year}-${local.month}';
      byMonth.putIfAbsent(key, () => []).add(e);
    }

    final keys = byMonth.keys.toList()..sort();
    final months = <DiscoverGrowthMonth>[];

    for (final key in keys) {
      final parts = key.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final group = byMonth[key]!;
      months.add(
        DiscoverGrowthMonth(
          month: month,
          year: year,
          label: timelineMonthLabel(month),
          summary: _summarizeMonth(group),
        ),
      );
    }

    return months.reversed.take(6).toList().reversed.toList();
  }

  String _summarizeMonth(List<JournalEntry> entries) {
    final moods = <String, int>{};
    var uncertain = 0;
    var positive = 0;
    for (final e in entries) {
      final mood = e.reflection.mood.trim().toLowerCase();
      if (mood.isNotEmpty) moods[mood] = (moods[mood] ?? 0) + 1;
      final t = e.transcript.toLowerCase();
      if (t.contains('uncertain') || t.contains("don't know") || t.contains('unsure')) {
        uncertain++;
      }
      if (t.contains('confident') || t.contains('clear') || t.contains('excited')) {
        positive++;
      }
    }
    if (positive > uncertain && positive >= 2) return 'More confidence';
    if (uncertain >= 2) return 'Mostly uncertainty';
    if (positive >= 1) return 'Clearer priorities';
    if (entries.length >= 3) return 'Taking action';
    final topMood = moods.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (topMood.isNotEmpty) {
      return 'Focused on ${topMood.first.key}';
    }
    return 'Reflecting steadily';
  }
}
