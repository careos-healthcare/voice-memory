import 'package:archiveme_mobile/models/journal_entry.dart';

/// Groups earlier moments that share today's month and day.
abstract final class OnThisDayController {
  OnThisDayController._();

  static const emptyCopy =
      "Nothing from this day yet. Record something and it'll be here next year.";

  static const monthAgoLabel = '1 month ago';

  static String labelFor(int yearsAgo) {
    if (yearsAgo == 1) return '1 year ago';
    return '$yearsAgo years ago';
  }

  /// The first sentence, unchanged apart from surrounding space.
  static String firstSentence(String transcript) {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) return '';
    final match = RegExp(r'^.*?[.!?](?=\s|$)').firstMatch(trimmed);
    return match?.group(0)?.trim() ?? trimmed;
  }

  static String spokenDate(DateTime date) {
    const months = [
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
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  /// Most recent past year first. When no year matches, the same day last
  /// month is "1 month ago". Silenced ids and today are left out.
  static Map<String, List<JournalEntry>> group({
    required List<JournalEntry> entries,
    required DateTime today,
    Set<String> silencedIds = const {},
  }) {
    final buckets = <int, List<JournalEntry>>{};
    final monthMatches = <JournalEntry>[];
    final monthAgo = _previousMonthDay(today);
    for (final entry in entries) {
      if (silencedIds.contains(entry.id)) continue;
      final at = entry.createdAt;
      if (at.year == today.year &&
          at.month == today.month &&
          at.day == today.day) {
        continue;
      }
      if (at.month == today.month &&
          at.day == today.day &&
          at.year < today.year) {
        final yearsAgo = today.year - at.year;
        (buckets[yearsAgo] ??= []).add(entry);
        continue;
      }
      if (monthAgo != null &&
          at.year == monthAgo.year &&
          at.month == monthAgo.month &&
          at.day == monthAgo.day) {
        monthMatches.add(entry);
      }
    }
    final years = buckets.keys.toList()..sort();
    if (years.isNotEmpty) {
      return {
        for (final yearsAgo in years) labelFor(yearsAgo): buckets[yearsAgo]!,
      };
    }
    if (monthMatches.isEmpty) return const {};
    return {monthAgoLabel: monthMatches};
  }

  static DateTime? _previousMonthDay(DateTime today) {
    final first = DateTime(today.year, today.month - 1, 1);
    final lastDay = DateTime(first.year, first.month + 1, 0).day;
    if (today.day > lastDay) return null;
    return DateTime(first.year, first.month, today.day);
  }
}
