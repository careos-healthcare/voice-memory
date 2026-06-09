import '../../models/journal_entry.dart';
import 'timeline_models.dart';

/// Builds a flat, newest-first index for efficient timeline scrolling.
List<TimelineRow> buildTimelineRows(List<JournalEntry> entries) {
  if (entries.isEmpty) return const [];

  final byYear = <int, Map<int, List<JournalEntry>>>{};
  for (final entry in entries) {
    final local = entry.createdAt.toLocal();
    final year = local.year;
    final month = local.month;
    byYear.putIfAbsent(year, () => {});
    byYear[year]!.putIfAbsent(month, () => []).add(entry);
  }

  final rows = <TimelineRow>[];
  final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));

  for (final year in years) {
    rows.add(TimelineYearRow(year));
    final months = byYear[year]!.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final month in months) {
      final monthEntries = byYear[year]![month]!;
      rows.add(
        TimelineMonthRow(
          year: year,
          month: month,
          recordingCount: monthEntries.length,
        ),
      );
      for (final entry in monthEntries) {
        rows.add(TimelineEntryRow(entry));
      }
    }
  }

  return rows;
}
