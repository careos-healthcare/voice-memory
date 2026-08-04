import '../../models/journal_entry.dart';

/// Flat list row for [ListView.builder] — year → month → entry previews.
sealed class TimelineRow {
  const TimelineRow();
}

class TimelineYearRow extends TimelineRow {
  const TimelineYearRow(this.year);

  final int year;
}

class TimelineMonthRow extends TimelineRow {
  const TimelineMonthRow({
    required this.year,
    required this.month,
    required this.recordingCount,
  });

  final int year;
  final int month;
  final int recordingCount;
}

class TimelineEntryRow extends TimelineRow {
  const TimelineEntryRow(this.entry);

  final JournalEntry entry;
}

const List<String> timelineMonthNames = [
  '',
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

String timelineMonthLabel(int month) {
  if (month < 1 || month > 12) return 'Unknown';
  return timelineMonthNames[month];
}

String timelineRecordingCountLabel(int count) {
  if (count == 1) return '1 recording';
  return '$count recordings';
}
