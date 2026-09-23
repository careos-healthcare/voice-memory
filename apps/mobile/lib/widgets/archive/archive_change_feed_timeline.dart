import 'package:archiveme_mobile/models/journal_entry.dart';

/// One month of archive moments, newest first inside the month.
class ArchiveChangeFeedSection {
  const ArchiveChangeFeedSection({
    required this.year,
    required this.month,
    required this.entries,
  });

  static const monthNames = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  final int year;
  final int month;
  final List<JournalEntry> entries;

  String get storageKey => '$year-$month';

  String get label => '${monthNames[month - 1]} $year';

  int get voiceCount =>
      entries.where(ArchiveChangeFeedTimeline.isVoiceMemory).length;

  int get textCount => entries.length - voiceCount;
}

/// Groups saved moments the way a notes timeline does: newest month first.
abstract final class ArchiveChangeFeedTimeline {
  static bool isVoiceMemory(JournalEntry entry) {
    final path = entry.localAudioPath?.trim();
    if (path != null && path.isNotEmpty) return true;
    return entry.durationSeconds > 0;
  }

  static String formatDuration(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    final minutes = safe ~/ 60;
    final remainder = safe % 60;
    return '$minutes:${remainder.toString().padLeft(2, '0')}';
  }

  static List<int> years(List<JournalEntry> entries) {
    final values = entries
        .map((entry) => entry.createdAt.toLocal().year)
        .toSet();
    final sorted = values.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  static List<int> months({
    required List<JournalEntry> entries,
    required int year,
  }) {
    final values = entries
        .where((entry) => entry.createdAt.toLocal().year == year)
        .map((entry) => entry.createdAt.toLocal().month)
        .toSet();
    final sorted = values.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  static List<ArchiveChangeFeedSection> sections({
    required List<JournalEntry> entries,
    int? year,
    int? month,
  }) {
    final filtered = entries.where((entry) {
      final local = entry.createdAt.toLocal();
      if (year != null && local.year != year) return false;
      if (month != null && local.month != month) return false;
      return true;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final grouped = <String, List<JournalEntry>>{};
    final order = <String>[];
    for (final entry in filtered) {
      final local = entry.createdAt.toLocal();
      final key = '${local.year}-${local.month}';
      final bucket = grouped[key];
      if (bucket == null) {
        grouped[key] = [entry];
        order.add(key);
      } else {
        bucket.add(entry);
      }
    }

    return [
      for (final key in order)
        ArchiveChangeFeedSection(
          year: int.parse(key.split('-').first),
          month: int.parse(key.split('-').last),
          entries: grouped[key]!,
        ),
    ];
  }
}
