import 'package:archiveme_mobile/models/journal_entry.dart';

/// Groups earlier moments that share today's month and day.
abstract final class OnThisDayController {
  OnThisDayController._();

  static const emptyCopy =
      "Nothing from this day yet. Record one and it'll appear here next year.";

  static String labelFor(int yearsAgo) {
    if (yearsAgo == 1) return '1 year ago';
    return '$yearsAgo years ago';
  }

  /// Most recent past year first. Silenced ids and the current year are left out.
  static Map<String, List<JournalEntry>> group({
    required List<JournalEntry> entries,
    required DateTime today,
    Set<String> silencedIds = const {},
  }) {
    final buckets = <int, List<JournalEntry>>{};
    for (final entry in entries) {
      if (silencedIds.contains(entry.id)) continue;
      final at = entry.createdAt;
      if (at.month != today.month || at.day != today.day) continue;
      if (at.year >= today.year) continue;
      final yearsAgo = today.year - at.year;
      (buckets[yearsAgo] ??= []).add(entry);
    }
    final years = buckets.keys.toList()..sort();
    return {
      for (final yearsAgo in years) labelFor(yearsAgo): buckets[yearsAgo]!,
    };
  }
}
