import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

/// A saved moment reduced to what weekly synthesis needs.
class JournalSnippet {
  const JournalSnippet({
    required this.id,
    required this.createdAt,
    required this.transcript,
  });

  final String id;
  final DateTime createdAt;
  final String transcript;
}

/// Cached weekly synthesis and one surprise, both tied to source entries.
class WeeklyInsightSnapshot {
  const WeeklyInsightSnapshot({
    required this.generatedAt,
    required this.weeklySynthesis,
    required this.surpriseInsight,
    required this.weeklyEntryIds,
    required this.surpriseEntryIds,
  });

  final DateTime generatedAt;
  final String weeklySynthesis;
  final String surpriseInsight;
  final List<String> weeklyEntryIds;
  final List<String> surpriseEntryIds;

  Map<String, Object?> toJson() => {
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'weeklySynthesis': weeklySynthesis,
    'surpriseInsight': surpriseInsight,
    'weeklyEntryIds': weeklyEntryIds,
    'surpriseEntryIds': surpriseEntryIds,
  };

  factory WeeklyInsightSnapshot.fromJson(Map<String, Object?> json) {
    return WeeklyInsightSnapshot(
      generatedAt:
          DateTime.tryParse(json['generatedAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      weeklySynthesis: json['weeklySynthesis'] as String? ?? '',
      surpriseInsight: json['surpriseInsight'] as String? ?? '',
      weeklyEntryIds: _stringList(json['weeklyEntryIds']),
      surpriseEntryIds: _stringList(json['surpriseEntryIds']),
    );
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is String) item,
    ];
  }
}

/// Reads and writes the one cached insight snapshot.
abstract class InsightCache {
  Future<WeeklyInsightSnapshot?> read();

  Future<void> write(WeeklyInsightSnapshot snapshot);
}

class MemoryInsightCache implements InsightCache {
  WeeklyInsightSnapshot? _snapshot;

  @override
  Future<WeeklyInsightSnapshot?> read() async => _snapshot;

  @override
  Future<void> write(WeeklyInsightSnapshot snapshot) async {
    _snapshot = snapshot;
  }
}

/// SQLite cache so the dashboard can open without recomputing.
class SqliteInsightCache implements InsightCache {
  SqliteInsightCache(this._db);

  final Database _db;
  var _ready = false;

  static const table = 'insight_synthesis_cache';
  static const cacheKey = 'weekly_v1';

  Future<void> _ensure() async {
    if (_ready) return;
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        cache_key TEXT PRIMARY KEY,
        payload_json TEXT NOT NULL,
        generated_at TEXT NOT NULL
      )
    ''');
    _ready = true;
  }

  @override
  Future<WeeklyInsightSnapshot?> read() async {
    await _ensure();
    final rows = await _db.query(
      table,
      where: 'cache_key = ?',
      whereArgs: [cacheKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final payload = rows.first['payload_json'];
    if (payload is! String || payload.isEmpty) return null;
    final decoded = jsonDecode(payload);
    if (decoded is! Map) return null;
    return WeeklyInsightSnapshot.fromJson(decoded.cast<String, Object?>());
  }

  @override
  Future<void> write(WeeklyInsightSnapshot snapshot) async {
    await _ensure();
    await _db.insert(table, {
      'cache_key': cacheKey,
      'payload_json': jsonEncode(snapshot.toJson()),
      'generated_at': snapshot.generatedAt.toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

/// Aggregates the last 7 days on device and stores the result.
///
/// This never watches a text field and never opens a dialog. Callers run it
/// from a refresh button or a timer, off the journaling save path.
class InsightSynthesisService {
  InsightSynthesisService({InsightCache? cache})
    : _cache = cache ?? MemoryInsightCache();

  final InsightCache _cache;

  Future<WeeklyInsightSnapshot?> readCache() => _cache.read();

  Future<WeeklyInsightSnapshot> refresh(
    List<JournalSnippet> entries, {
    DateTime? now,
  }) async {
    final snapshot = synthesize(entries, now: now ?? DateTime.now());
    await _cache.write(snapshot);
    return snapshot;
  }

  WeeklyInsightSnapshot synthesize(
    List<JournalSnippet> entries, {
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final weekStart = clock.subtract(const Duration(days: 7));
    final priorStart = weekStart.subtract(const Duration(days: 7));
    final historyStart = clock.subtract(const Duration(days: 60));

    final thisWeek = entries.where((entry) {
      return !entry.createdAt.isBefore(weekStart) &&
          !entry.createdAt.isAfter(clock);
    }).toList();
    final previousWeek = entries.where((entry) {
      return !entry.createdAt.isBefore(priorStart) &&
          entry.createdAt.isBefore(weekStart);
    }).toList();
    final older = entries.where((entry) {
      return !entry.createdAt.isBefore(historyStart) &&
          entry.createdAt.isBefore(weekStart);
    }).toList();

    final weeklyThemes = _themes(thisWeek);
    final olderThemes = _themes(older);
    final forgotten =
        olderThemes.entries
            .where((theme) => (weeklyThemes[theme.key] ?? 0) == 0)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    final weeklySentiment = _meanSentiment(thisWeek);
    final previousSentiment = _meanSentiment(previousWeek);
    final topTheme = _top(weeklyThemes);

    final weeklyText = topTheme == null
        ? 'No repeating theme showed up in the last 7 days.'
        : 'This week, "$topTheme" showed up in ${weeklyThemes[topTheme]} '
              'saved moments.';
    final surprise = _surprise(
      forgotten: forgotten,
      older: older,
      weeklySentiment: weeklySentiment,
      previousSentiment: previousSentiment,
      thisWeek: thisWeek,
    );

    return WeeklyInsightSnapshot(
      generatedAt: clock.toUtc(),
      weeklySynthesis: weeklyText,
      surpriseInsight: surprise.text,
      weeklyEntryIds: topTheme == null
          ? const []
          : _idsContaining(thisWeek, topTheme),
      surpriseEntryIds: surprise.entryIds,
    );
  }

  String? _top(Map<String, int> themes) {
    if (themes.isEmpty) return null;
    final ranked = themes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ranked.first.key;
  }

  _Surprise _surprise({
    required List<MapEntry<String, int>> forgotten,
    required List<JournalSnippet> older,
    required double weeklySentiment,
    required double previousSentiment,
    required List<JournalSnippet> thisWeek,
  }) {
    if (forgotten.isNotEmpty) {
      final theme = forgotten.first.key;
      return _Surprise(
        text: 'A pattern that went quiet this week: "$theme".',
        entryIds: _idsContaining(older, theme),
      );
    }
    if (weeklySentiment > previousSentiment + 0.05 && thisWeek.isNotEmpty) {
      return _Surprise(
        text: 'A positive shift: this week reads warmer than the week before.',
        entryIds: [for (final entry in thisWeek) entry.id],
      );
    }
    return const _Surprise(
      text: "Nothing surprising stood out beyond this week's themes.",
      entryIds: [],
    );
  }

  List<String> _idsContaining(List<JournalSnippet> entries, String theme) {
    return [
      for (final entry in entries)
        if (_tokens(entry.transcript).contains(theme)) entry.id,
    ];
  }

  Map<String, int> _themes(List<JournalSnippet> entries) {
    final counts = <String, Set<String>>{};
    for (final entry in entries) {
      for (final token in _tokens(entry.transcript).toSet()) {
        counts.putIfAbsent(token, () => {}).add(entry.id);
      }
    }
    return {
      for (final entry in counts.entries)
        if (entry.value.length >= 2) entry.key: entry.value.length,
    };
  }

  double _meanSentiment(List<JournalSnippet> entries) {
    if (entries.isEmpty) return 0;
    var total = 0.0;
    for (final entry in entries) {
      total += _sentiment(entry.transcript);
    }
    return total / entries.length;
  }

  double _sentiment(String text) {
    final tokens = _tokens(text).toList();
    if (tokens.isEmpty) return 0;
    var score = 0;
    for (final token in tokens) {
      if (_positive.contains(token)) score += 1;
      if (_negative.contains(token)) score -= 1;
    }
    return score / tokens.length;
  }

  static const _positive = {
    'grateful',
    'calm',
    'hopeful',
    'proud',
    'relieved',
    'glad',
    'better',
    'peace',
  };

  static const _negative = {
    'anxious',
    'stressed',
    'angry',
    'worried',
    'overwhelmed',
    'stuck',
  };

  static const _stop = {
    'about',
    'after',
    'again',
    'before',
    'because',
    'could',
    'there',
    'their',
    'today',
    'would',
    'which',
    'while',
    'other',
    'these',
    'those',
  };

  Iterable<String> _tokens(String text) {
    return text
        .toLowerCase()
        .split(RegExp('[^a-z]+'))
        .where((token) => token.length >= 5 && !_stop.contains(token));
  }
}

class _Surprise {
  const _Surprise({required this.text, required this.entryIds});

  final String text;
  final List<String> entryIds;
}

/// Optional timer. It does not start unless a screen asks it to.
class PassiveInsightScheduler {
  Timer? _timer;

  void start({
    required Duration interval,
    required Future<void> Function() onTick,
  }) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) {
      unawaited(onTick());
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}

final insightSynthesisServiceProvider = Provider<InsightSynthesisService>(
  (ref) => InsightSynthesisService(),
);
