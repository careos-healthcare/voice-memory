import 'package:archiveme_mobile/features/memory/entry_embedding_store.dart';
import 'package:archiveme_mobile/features/memory/related_entries_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// One quoted sentence from a saved entry.
class WeeklyQuote {
  const WeeklyQuote({
    required this.entryId,
    required this.sentence,
    required this.date,
    this.audioPath,
    this.startSeconds,
  });

  final String entryId;
  final String sentence;
  final DateTime date;
  final String? audioPath;
  final int? startSeconds;
}

/// A line from this week beside a similar line from at least three weeks ago.
class ThenAndNow {
  const ThenAndNow({required this.now, required this.then});

  final WeeklyQuote now;
  final WeeklyQuote then;
}

/// A clip in the listen-back playlist.
class ListenClip {
  const ListenClip({
    required this.entryId,
    required this.sentence,
    required this.audioPath,
    required this.startSeconds,
    required this.clipSeconds,
  });

  final String entryId;
  final String sentence;
  final String audioPath;
  final int startSeconds;

  /// How long to play. Fifteen seconds when the sentence has no timestamp.
  final int clipSeconds;
}

/// One week, computed from saved entries. No scores and no network.
class BuiltWeeklyRecap {
  const BuiltWeeklyRecap({
    required this.rangeStart,
    required this.rangeEnd,
    required this.daysRecorded,
    required this.totalMinutes,
    required this.themes,
    required this.moods,
    required this.places,
    required this.listenBack,
    required this.entries,
    this.thenAndNow,
  });

  final DateTime rangeStart;
  final DateTime rangeEnd;
  final int daysRecorded;
  final int totalMinutes;
  final List<WeeklyQuote> themes;
  final ThenAndNow? thenAndNow;
  final List<String> moods;
  final List<String> places;
  final List<ListenClip> listenBack;
  final List<JournalEntry> entries;

  bool get hasEntries => entries.isNotEmpty;
}

/// Remembers a built week so opening it again does not recompute.
class WeeklyRecapCache {
  WeeklyRecapCache._();

  static final Map<String, BuiltWeeklyRecap> _stored = {};

  static BuiltWeeklyRecap put(BuiltWeeklyRecap recap) {
    _stored[_key(recap.rangeEnd)] = recap;
    return recap;
  }

  static BuiltWeeklyRecap? read(DateTime rangeEnd) => _stored[_key(rangeEnd)];

  static void clear() => _stored.clear();

  static String _key(DateTime day) =>
      '${day.year}-${day.month}-${day.day}';
}

/// Pure week builder. [now] selects the week that ends on the latest Sunday.
abstract final class WeeklyRecapBuilder {
  WeeklyRecapBuilder._();

  static const listenClipSeconds = 15;

  static BuiltWeeklyRecap build(
    List<JournalEntry> entries, {
    required DateTime now,
    DateTime? weekEnding,
    List<({String word, int startSeconds})>? Function(JournalEntry entry)?
    wordTimestamps,
  }) {
    final ending = _date(weekEnding ?? recapSunday(now));
    final start = ending.subtract(const Duration(days: 6));
    final week = [
      for (final entry in entries)
        if (!entry.isDeleted && _inWeek(entry, start, ending)) entry,
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final days = <DateTime>{
      for (final entry in week) _date(entry.createdAt.toLocal()),
    };
    final seconds = week.fold<int>(
      0,
      (sum, entry) => sum + entry.durationSeconds,
    );
    final themes = _themes(week, wordTimestamps);
    return BuiltWeeklyRecap(
      rangeStart: start,
      rangeEnd: ending,
      daysRecorded: days.length,
      totalMinutes: (seconds / 60).round(),
      themes: themes,
      thenAndNow: _thenAndNow(week, entries, now, wordTimestamps),
      moods: _labels(week.map((entry) => entry.reflection.mood)),
      places: _labels(week.map((entry) => entry.display.locationLabel ?? '')),
      listenBack: [
        for (final theme in themes)
          if (theme.audioPath != null)
            ListenClip(
              entryId: theme.entryId,
              sentence: theme.sentence,
              audioPath: theme.audioPath!,
              startSeconds: theme.startSeconds ?? 0,
              clipSeconds: listenClipSeconds,
            ),
      ].take(3).toList(growable: false),
      entries: week,
    );
  }

  /// Sunday, Monday, and Tuesday. Tuesday includes the whole day.
  static bool bannerWindow(DateTime now) {
    return now.weekday == DateTime.sunday ||
        now.weekday == DateTime.monday ||
        now.weekday == DateTime.tuesday;
  }

  /// The Sunday that closes the week being recapped.
  static DateTime recapSunday(DateTime now) {
    final day = _date(now.toLocal());
    final back = day.weekday == DateTime.sunday ? 0 : day.weekday;
    return day.subtract(Duration(days: back));
  }

  /// Completed weeks, newest first. The week on the banner is left off
  /// while that banner is showing.
  static List<DateTime> pastWeekEndings(
    List<JournalEntry> entries, {
    required DateTime now,
  }) {
    final current = recapSunday(now);
    final includeCurrent = !bannerWindow(now);
    final endings = <DateTime>{};
    for (final entry in entries) {
      if (entry.isDeleted) continue;
      final ending = _comingSunday(entry.createdAt.toLocal());
      if (ending.isAfter(current)) continue;
      if (!includeCurrent && _sameDay(ending, current)) continue;
      endings.add(ending);
    }
    final sorted = endings.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  static DateTime _comingSunday(DateTime moment) {
    final day = _date(moment);
    final untilSunday = (DateTime.sunday - day.weekday) % 7;
    return day.add(Duration(days: untilSunday));
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Drops summary sentences that do not cite a real entry.
  static List<String> citedSentences({
    required String summary,
    required List<({String text, String entryId})> citations,
    required Set<String> validEntryIds,
  }) {
    final sentences = verbatimSentences(summary);
    return [
      for (final sentence in sentences)
        if (_sentenceCites(sentence, citations, validEntryIds)) sentence,
    ];
  }

  static bool _sentenceCites(
    String sentence,
    List<({String text, String entryId})> citations,
    Set<String> validEntryIds,
  ) {
    for (final citation in citations) {
      if (!validEntryIds.contains(citation.entryId)) continue;
      if (citation.entryId.isNotEmpty && sentence.contains(citation.entryId)) {
        return true;
      }
      final quote = citation.text.trim();
      if (quote.isNotEmpty &&
          (sentence.contains(quote) || quote.contains(sentence))) {
        return true;
      }
    }
    return false;
  }

  static List<WeeklyQuote> _themes(
    List<JournalEntry> week,
    List<({String word, int startSeconds})>? Function(JournalEntry entry)?
    wordTimestamps,
  ) {
    final pending = [
      for (final entry in week)
        if (entry.transcript.trim().isNotEmpty) entry,
    ];
    final themes = <WeeklyQuote>[];
    while (pending.isNotEmpty && themes.length < 3) {
      final seed = pending.removeAt(0);
      final seedVector = EntryEmbeddingStore.localNgramEmbedding(
        seed.transcript,
      );
      final group = <JournalEntry>[seed];
      pending.removeWhere((other) {
        final score = cosineSimilarity(
          seedVector,
          EntryEmbeddingStore.localNgramEmbedding(other.transcript),
        );
        if (score < RelatedEntriesService.similarityThreshold) return false;
        group.add(other);
        return true;
      });
      final source = group.last;
      themes.add(_quote(source, seedVector, wordTimestamps?.call(source)));
    }
    return themes;
  }

  static ThenAndNow? _thenAndNow(
    List<JournalEntry> week,
    List<JournalEntry> all,
    DateTime now,
    List<({String word, int startSeconds})>? Function(JournalEntry entry)?
    wordTimestamps,
  ) {
    if (week.isEmpty) return null;
    final current = week.last;
    final query = EntryEmbeddingStore.localNgramEmbedding(current.transcript);
    JournalEntry? best;
    var bestScore = RelatedEntriesService.similarityThreshold;
    for (final entry in all) {
      if (entry.id == current.id || entry.isDeleted) continue;
      if (now.difference(entry.createdAt) < const Duration(days: 21)) {
        continue;
      }
      final transcript = entry.transcript.trim();
      if (transcript.isEmpty) continue;
      final score = cosineSimilarity(
        query,
        EntryEmbeddingStore.localNgramEmbedding(transcript),
      );
      if (score < bestScore) continue;
      bestScore = score;
      best = entry;
    }
    if (best == null) return null;
    return ThenAndNow(
      now: _quote(current, query, wordTimestamps?.call(current)),
      then: _quote(best, query, wordTimestamps?.call(best)),
    );
  }

  static WeeklyQuote _quote(
    JournalEntry entry,
    List<double> query,
    List<({String word, int startSeconds})>? words,
  ) {
    final sentence = bestVerbatimSentence(
      entry.transcript,
      query,
      EntryEmbeddingStore.localNgramEmbedding,
    );
    return WeeklyQuote(
      entryId: entry.id,
      sentence: sentence,
      date: entry.createdAt,
      audioPath: entry.localAudioPath,
      startSeconds: sentenceStartSeconds(sentence, words),
    );
  }

  static List<String> _labels(Iterable<String> values) {
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

  static bool _inWeek(JournalEntry entry, DateTime start, DateTime end) {
    final day = _date(entry.createdAt.toLocal());
    return !day.isBefore(start) && !day.isAfter(end);
  }

  static DateTime _date(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
