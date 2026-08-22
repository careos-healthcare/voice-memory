import 'package:archiveme_mobile/features/memory/archive_retrieval_policy.dart' show ArchiveRetrievalPolicy;
import 'package:archiveme_mobile/features/memory/archive_retrieval_score.dart';
import 'package:archiveme_mobile/features/memory/memory_scope_policy.dart' show MemoryScopePolicy;
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:archiveme_mobile/features/recording/recording_dependencies.dart' show MemoryScopePolicy;

/// Pure, deterministic retrieval scoring over already-eligible archive
/// records. No AI calls, no backend search — only decay-aware recency,
/// real overlap between the user's own records, session usage signals,
/// and existing safe metadata.
///
/// Scope rules (memory off, treat-as-new, ask approvals, thread-only)
/// are NOT applied here — [ArchiveRetrievalPolicy] filters through
/// [MemoryScopePolicy] first. This engine only ranks what it is given.
class ArchiveRetrievalEngine {
  const ArchiveRetrievalEngine();

  /// Top relevant records only — connection claims never need more.
  static const int defaultMaxRecords = 5;

  // Component weights. Totals land on the band thresholds below.
  static const int _sameDayRecency = 40;
  static const int _withinWeekRecency = 32;
  static const int _withinMonthRecency = 20;
  static const int _staleRecency = 6;

  static const int _sharedContextPoints = 25;
  static const int _sharedWordPoints = 15;
  static const int _sharedOptionPoints = 5;

  static const int _usefulFeedbackPoints = 10;
  static const int _notQuitePenalty = 15;

  static const int _choseToStopImportance = 5;

  /// Band thresholds on the component total.
  static const int _weakThreshold = 20;
  static const int _possibleThreshold = 45;

  /// Relevance at or above this keeps a 31+ day old record retrievable;
  /// anything less makes it stale (capped at weak).
  static const int _strongRelevanceFloor = 25;

  /// Filler plus generic app words — overlap on these is not relevance.
  static const Set<String> _ignoredWords = {
    'the',
    'and',
    'for',
    'that',
    'this',
    'with',
    'was',
    'were',
    'will',
    'would',
    'wont',
    "won't",
    'its',
    "it's",
    'not',
    'but',
    'had',
    'have',
    'has',
    'did',
    'does',
    'about',
    'from',
    'they',
    'them',
    'when',
    'then',
    'than',
    'what',
    'how',
    'why',
    'who',
    'all',
    'too',
    'very',
    'just',
    'like',
    'get',
    'got',
    'gets',
    'into',
    'out',
    'off',
    'might',
    'maybe',
    'could',
    'should',
    'because',
    'being',
    'been',
    'still',
    'even',
    'more',
    'again',
    'myself',
    'dont',
    "don't",
    'cant',
    "can't",
    'ill',
    "i'll",
    'pressure',
    'moment',
    'moments',
    'pattern',
    'patterns',
    'archive',
    'entry',
    'entries',
    'check',
    'checkin',
    'app',
    'archiveme',
    'feel',
    'feels',
    'felt',
    'feeling',
    'same',
  };

  /// Scores [records] and returns the top [maxRecords], strongest first.
  ///
  /// [now] anchors recency decay; when null the newest record's timestamp
  /// is used so scoring stays deterministic for engines without a clock.
  /// [usefulEntryIds] / [notQuiteEntryIds] are the session usage signals
  /// supplied by the policy — ids only, never content.
  ArchiveRetrievalResult score(
    List<PressureCheckInRecord> records, {
    DateTime? now,
    int maxRecords = defaultMaxRecords,
    Set<String> usefulEntryIds = const {},
    Set<String> notQuiteEntryIds = const {},
  }) {
    if (records.isEmpty) return const ArchiveRetrievalResult.empty();

    final anchor =
        now ??
        records.map((r) => r.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);
    final wordsByRecord = {
      for (final record in records) record.entryId: _entryWords(record),
    };

    final scores = <ArchiveRetrievalScore>[];
    for (final record in records) {
      final others = records.where((r) => r.entryId != record.entryId);
      final daysSince = _daysSince(record.createdAt, anchor);

      final recency = _recencyPoints(daysSince);
      final relevance = _relevancePoints(record, others, wordsByRecord);
      final usage = _usagePoints(
        record.entryId,
        usefulEntryIds: usefulEntryIds,
        notQuiteEntryIds: notQuiteEntryIds,
      );
      final importance = record.choseToStop ? _choseToStopImportance : 0;

      scores.add(
        ArchiveRetrievalScore(
          record: record,
          recencyPoints: recency,
          relevancePoints: relevance,
          usagePoints: usage,
          importancePoints: importance,
          band: _band(
            total: recency + relevance + usage + importance,
            daysSince: daysSince,
            relevance: relevance,
          ),
        ),
      );
    }

    scores.sort((a, b) {
      final byTotal = b.total.compareTo(a.total);
      if (byTotal != 0) return byTotal;
      return b.record.createdAt.compareTo(a.record.createdAt);
    });

    // Records with no signal at all are never retrieved; the rest are
    // capped to the top relevant few.
    final retrievable = scores
        .where((s) => s.band != ArchiveRetrievalBand.none)
        .take(maxRecords)
        .toList();
    if (retrievable.isEmpty) return const ArchiveRetrievalResult.empty();

    final best = retrievable
        .map((s) => s.band)
        .reduce((a, b) => a.index >= b.index ? a : b);
    return ArchiveRetrievalResult(scores: retrievable, band: best);
  }

  /// Simple deterministic decay: same day strongest, 1–7 days still
  /// useful, 8–30 days weaker, 31+ stale. Old entries are never
  /// impossible — just weaker.
  int _recencyPoints(int daysSince) {
    if (daysSince <= 0) return _sameDayRecency;
    if (daysSince <= 7) return _withinWeekRecency;
    if (daysSince <= 30) return _withinMonthRecency;
    return _staleRecency;
  }

  int _relevancePoints(
    PressureCheckInRecord record,
    Iterable<PressureCheckInRecord> others,
    Map<String, Set<String>> wordsByRecord,
  ) {
    var points = 0;

    // Shared explicit context tag — the strongest safe relevance marker.
    final contexts = record.contextIds.toSet();
    if (contexts.isNotEmpty &&
        others.any((o) => o.contextIds.any(contexts.contains))) {
      points += _sharedContextPoints;
    }

    // A meaningful word repeated in another record's notes.
    final words = wordsByRecord[record.entryId] ?? const <String>{};
    if (words.isNotEmpty &&
        others.any(
          (o) => (wordsByRecord[o.entryId] ?? const <String>{}).any(
            words.contains,
          ),
        )) {
      points += _sharedWordPoints;
    }

    // Same pressure option theme as another record.
    if (record.optionId.isNotEmpty &&
        others.any((o) => o.optionId == record.optionId)) {
      points += _sharedOptionPoints;
    }

    return points;
  }

  int _usagePoints(
    String entryId, {
    required Set<String> usefulEntryIds,
    required Set<String> notQuiteEntryIds,
  }) {
    var points = 0;
    if (usefulEntryIds.contains(entryId)) points += _usefulFeedbackPoints;
    if (notQuiteEntryIds.contains(entryId)) points -= _notQuitePenalty;
    return points;
  }

  ArchiveRetrievalBand _band({
    required int total,
    required int daysSince,
    required int relevance,
  }) {
    if (total < _weakThreshold) return ArchiveRetrievalBand.none;
    // Stale unless relevance/context is strong: a 31+ day old record can
    // not reach "possible" on recency-adjacent points alone.
    if (daysSince > 30 && relevance < _strongRelevanceFloor) {
      return ArchiveRetrievalBand.weak;
    }
    if (total >= _possibleThreshold) return ArchiveRetrievalBand.possible;
    return ArchiveRetrievalBand.weak;
  }

  int _daysSince(DateTime createdAt, DateTime anchor) {
    final days = anchor.difference(createdAt).inDays;
    return days < 0 ? 0 : days;
  }

  /// Distinct meaningful note words, counted once per entry — mirrors the
  /// existing evidence engines so retrieval and claims agree on overlap.
  Set<String> _entryWords(PressureCheckInRecord record) {
    final text = '${record.fear ?? ''} ${record.stopCostNote ?? ''}';
    final words = <String>{};
    for (final raw in text.toLowerCase().split(RegExp("[^a-z']+"))) {
      final word = raw.trim();
      if (word.length < 3 || _ignoredWords.contains(word)) continue;
      words.add(word);
    }
    return words;
  }
}