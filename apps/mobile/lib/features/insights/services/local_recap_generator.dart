import 'package:archiveme_mobile/core/database/database_provider.dart';
import 'package:archiveme_mobile/features/insights/recurring_themes_view.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';

/// One repeated theme and a single line from the entry that named it.
class RecapThemeCitation {
  const RecapThemeCitation({
    required this.label,
    required this.quote,
    required this.entryId,
    this.audioPath,
  });

  final String label;
  final String quote;
  final String entryId;
  final String? audioPath;
}

/// A line from this week beside a similar line from more than seven days ago.
class ThenVsNow {
  const ThenVsNow({
    required this.thisWeekQuote,
    required this.thisWeekEntryId,
    required this.earlierQuote,
    required this.earlierEntryId,
  });

  final String thisWeekQuote;
  final String thisWeekEntryId;
  final String earlierQuote;
  final String earlierEntryId;
}

/// A short recording from the week.
class ListenBackClip {
  const ListenBackClip({
    required this.entryId,
    required this.quote,
    required this.audioPath,
    required this.durationSeconds,
  });

  final String entryId;
  final String quote;
  final String audioPath;
  final int durationSeconds;
}

/// Local counts and citations for one seven-day window.
class LocalWeeklyRecap {
  const LocalWeeklyRecap({
    required this.weekEnding,
    required this.daysRecorded,
    required this.totalMinutes,
    required this.themes,
    required this.moods,
    required this.places,
    required this.listenBack,
    required this.entries,
    this.thenVsNow,
  });

  final DateTime weekEnding;
  final int daysRecorded;
  final int totalMinutes;
  final List<RecapThemeCitation> themes;
  final List<String> moods;
  final List<String> places;
  final ThenVsNow? thenVsNow;
  final List<ListenBackClip> listenBack;
  final List<JournalEntry> entries;

  LocalWeeklyRecap copyWith({ThenVsNow? thenVsNow}) {
    return LocalWeeklyRecap(
      weekEnding: weekEnding,
      daysRecorded: daysRecorded,
      totalMinutes: totalMinutes,
      themes: themes,
      moods: moods,
      places: places,
      listenBack: listenBack,
      entries: entries,
      thenVsNow: thenVsNow ?? this.thenVsNow,
    );
  }
}

/// Builds a week recap from saved journal entries. No streaks and no scores.
class LocalRecapGenerator {
  const LocalRecapGenerator();

  static DateTime weekEndingFor(DateTime moment) {
    final day = DateTime(moment.year, moment.month, moment.day);
    final untilSunday = (DateTime.sunday - day.weekday) % 7;
    return day.add(Duration(days: untilSunday));
  }

  static List<DateTime> weekEndings(List<JournalEntry> entries) {
    final endings = <DateTime>{};
    for (final entry in entries) {
      endings.add(weekEndingFor(entry.createdAt.toLocal()));
    }
    final sorted = endings.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  LocalWeeklyRecap build(
    List<JournalEntry> entries, {
    DateTime? now,
    DateTime? weekEnding,
  }) {
    final ending = _date(
      weekEnding ?? weekEndingFor((now ?? DateTime.now()).toLocal()),
    );
    final start = ending.subtract(const Duration(days: 6));
    final week = [
      for (final entry in entries)
        if (_inWindow(entry, start, ending)) entry,
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final days = <DateTime>{
      for (final entry in week) _date(entry.createdAt.toLocal()),
    };
    final seconds = week.fold<int>(
      0,
      (sum, entry) => sum + entry.durationSeconds,
    );
    return LocalWeeklyRecap(
      weekEnding: ending,
      daysRecorded: days.length,
      totalMinutes: (seconds / 60).round(),
      themes: _themes(week),
      moods: _unique(week.map((entry) => entry.reflection.mood)),
      places: _unique(week.map((entry) => entry.display.locationLabel ?? '')),
      listenBack: _listenBack(week),
      entries: week,
    );
  }

  /// Pairs this week's longest line with one older similar line, when a
  /// searcher is available.
  Future<LocalWeeklyRecap> withEarlierMatch(
    LocalWeeklyRecap recap, {
    Future<SimilarEntry?> Function(JournalEntry prominent)? earlierMatch,
  }) async {
    final prominent = _prominent(recap.entries);
    if (prominent == null) return recap;
    final finder = earlierMatch ?? _storedEarlierMatch;
    final earlier = await finder(prominent);
    if (earlier == null || earlier.id == prominent.id) return recap;
    final earlierQuote = shortVerbatimQuote(earlier.transcript);
    final currentQuote = shortVerbatimQuote(prominent.transcript);
    if (earlierQuote.isEmpty || currentQuote.isEmpty) return recap;
    return recap.copyWith(
      thenVsNow: ThenVsNow(
        thisWeekQuote: currentQuote,
        thisWeekEntryId: prominent.id,
        earlierQuote: earlierQuote,
        earlierEntryId: earlier.id,
      ),
    );
  }

  static bool _inWindow(JournalEntry entry, DateTime start, DateTime end) {
    final day = _date(entry.createdAt.toLocal());
    return !day.isBefore(start) && !day.isAfter(end);
  }

  static DateTime _date(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static List<String> _unique(Iterable<String> values) {
    final seen = <String>[];
    for (final raw in values) {
      final label = raw.trim();
      if (label.isEmpty) continue;
      if (seen.any((item) => item.toLowerCase() == label.toLowerCase())) {
        continue;
      }
      seen.add(label);
    }
    return seen;
  }

  static List<RecapThemeCitation> _themes(List<JournalEntry> week) {
    final grouped = <String, List<JournalEntry>>{};
    final labels = <String, String>{};
    for (final entry in week) {
      for (final raw in entry.reflection.recurringThemes) {
        final label = plainThemeLabel(raw);
        if (label.isEmpty) continue;
        final key = label.toLowerCase();
        labels[key] = label;
        final bucket = grouped.putIfAbsent(key, () => []);
        if (bucket.every((saved) => saved.id != entry.id)) bucket.add(entry);
      }
    }
    final ranked = grouped.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.length.compareTo(a.value.length);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });
    return [
      for (final entry in ranked.take(3))
        if (_themeCitation(labels[entry.key]!, entry.value)
            case final citation?)
          citation,
    ];
  }

  static RecapThemeCitation? _themeCitation(
    String label,
    List<JournalEntry> entries,
  ) {
    final source = _prominent(entries);
    if (source == null) return null;
    final quote = shortVerbatimQuote(source.transcript);
    if (quote.isEmpty) return null;
    final audio = source.localAudioPath?.trim();
    return RecapThemeCitation(
      label: label,
      quote: quote,
      entryId: source.id,
      audioPath: audio == null || audio.isEmpty ? null : audio,
    );
  }

  static JournalEntry? _prominent(List<JournalEntry> entries) {
    JournalEntry? best;
    for (final entry in entries) {
      if (entry.transcript.trim().isEmpty) continue;
      if (best == null || entry.transcript.length > best.transcript.length) {
        best = entry;
      }
    }
    return best;
  }

  static List<ListenBackClip> _listenBack(List<JournalEntry> week) {
    final clips = [
      for (final entry in week)
        if ((entry.localAudioPath?.trim().isNotEmpty ?? false) &&
            entry.transcript.trim().isNotEmpty)
          ListenBackClip(
            entryId: entry.id,
            quote: shortVerbatimQuote(entry.transcript),
            audioPath: entry.localAudioPath!.trim(),
            durationSeconds: entry.durationSeconds,
          ),
    ]..sort((a, b) => a.durationSeconds.compareTo(b.durationSeconds));
    return clips.take(3).toList(growable: false);
  }

  static Future<SimilarEntry?> _storedEarlierMatch(
    JournalEntry prominent,
  ) async {
    if (!AppServices.isInitialized) return null;
    final database = DatabaseProvider(
      AppServices.instance.sqliteDatabase.database,
    );
    final vector = await database.readEmbedding(prominent.id);
    if (vector == null) return null;
    final matches = await database.findSimilarEntries(
      vector,
      excludeWithinDays: 7,
      limit: 1,
    );
    if (matches.isEmpty) return null;
    return matches.first;
  }
}
