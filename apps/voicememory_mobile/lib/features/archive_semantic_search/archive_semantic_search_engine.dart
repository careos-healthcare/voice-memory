// ignore_for_file: prefer_initializing_formals

import 'dart:math' as math;

import 'package:sqlite3/sqlite3.dart';

import '../../core/search/local_text_embedding.dart';
import '../../models/journal_entry.dart';
import '../../storage/journal_store.dart';
import 'archive_semantic_query_parser.dart';
import 'archive_semantic_search_models.dart';
import 'semantic_index_store.dart';

final class ArchiveSemanticSearchEngine {
  ArchiveSemanticSearchEngine({
    required this.journalStore,
    required this.indexStore,
    LocalEmbeddingDriver embeddingDriver = const HashedLocalEmbeddingDriver(),
    ArchiveSemanticQueryParser parser = const ArchiveSemanticQueryParser(),
  }) : _embeddingDriver = embeddingDriver,
       _parser = parser;

  final JournalStore journalStore;
  final SemanticIndexStore indexStore;
  final LocalEmbeddingDriver _embeddingDriver;
  final ArchiveSemanticQueryParser _parser;
  bool _disposed = false;

  Future<ArchiveSemanticSearchPage> search(
    String input, {
    int offset = 0,
    int limit = 30,
  }) async {
    _checkOpen();
    if (input.length > 500) {
      throw ArgumentError.value(
        input.length,
        'input',
        'Maximum is 500 UTF-16 units.',
      );
    }
    final safeOffset = math.max(0, offset);
    final safeLimit = limit.clamp(1, 200);
    final query = _parser.parse(input);
    if (query.searchText.trim().isEmpty &&
        query.intent == ArchiveSemanticSearchIntent.general) {
      return ArchiveSemanticSearchPage(
        query: query,
        results: const [],
        totalResults: 0,
        hasMore: false,
        insufficientReason: 'Enter a topic or question to search your archive.',
      );
    }

    final current = await journalStore.loadAll();
    await indexStore.reconcile(current);
    final snapshot = await indexStore.loadSnapshot();
    _checkOpen();
    final entries = {
      for (final entry in current)
        if (snapshot.vectors.containsKey(entry.id) &&
            _insideDates(entry.createdAt, query))
          entry.id: entry,
    };

    final ranked = _isMood(query.intent)
        ? _rankMood(entries, query)
        : _rankHybrid(entries, snapshot, query);
    final total = ranked.length;
    final page = ranked
        .skip(safeOffset)
        .take(safeLimit)
        .toList(growable: false);
    return ArchiveSemanticSearchPage(
      query: query,
      results: page,
      totalResults: total,
      hasMore: safeOffset + page.length < total,
      insufficientReason: total == 0
          ? (_isMood(query.intent)
                ? 'There is not enough explicit mood or wording evidence to answer that.'
                : 'No grounded mentions matched this search.')
          : null,
    );
  }

  List<ArchiveSemanticSearchResult> _rankHybrid(
    Map<String, JournalEntry> entries,
    SemanticIndexSnapshot snapshot,
    ArchiveSemanticSearchQuery query,
  ) {
    if (entries.isEmpty) return const [];
    final terms = _expandedQueryTerms(query);
    final lexical = _lexicalRanking(entries, terms);
    final queryVector = _embeddingDriver.embed(query.searchText);
    final dense = entries.keys.toList()
      ..sort((left, right) {
        final byScore =
            LocalVectorMath.cosineSimilarity(
              queryVector,
              snapshot.vectors[right]!,
            ).compareTo(
              LocalVectorMath.cosineSimilarity(
                queryVector,
                snapshot.vectors[left]!,
              ),
            );
        return byScore != 0 ? byScore : left.compareTo(right);
      });
    final densePositive = dense
        .where(
          (id) =>
              LocalVectorMath.cosineSimilarity(
                queryVector,
                snapshot.vectors[id]!,
              ) >
              0,
        )
        .toList(growable: false);
    final ranks = <String, List<int>>{};
    for (final ranking in [densePositive, lexical]) {
      for (var index = 0; index < ranking.length; index++) {
        ranks.putIfAbsent(ranking[index], () => []).add(index + 1);
      }
    }
    final results = <ArchiveSemanticSearchResult>[];
    for (final item in ranks.entries) {
      final entry = entries[item.key];
      if (entry == null) continue;
      final text = SemanticIndexStore.searchableTextFor(entry);
      if (query.intent == ArchiveSemanticSearchIntent.topicEnumeration &&
          !_hasEveryConcept(text, query.concepts)) {
        continue;
      }
      final evidence = _evidenceForEntry(entry, terms);
      if (query.intent == ArchiveSemanticSearchIntent.topicEnumeration &&
          evidence == null) {
        continue;
      }
      results.add(
        _result(
          entry,
          evidence,
          LocalVectorMath.reciprocalRankFusion(item.value),
          lexical.contains(item.key)
              ? 'Exact wording and local semantic match'
              : 'Local semantic match',
        ),
      );
    }
    results.sort(_compareResults);
    return results;
  }

  List<ArchiveSemanticSearchResult> _rankMood(
    Map<String, JournalEntry> entries,
    ArchiveSemanticSearchQuery query,
  ) {
    final terms = _moodTerms(query.intent);
    final results = <ArchiveSemanticSearchResult>[];
    for (final entry in entries.values) {
      final mood = entry.reflection.mood.trim().toLowerCase();
      final text = SemanticIndexStore.searchableTextFor(entry);
      final groundedMatches = _matchingTerms(text, terms);
      final explicitMood = terms.any(
        (term) => HashedLocalEmbeddingDriver.expandedTerms(term).contains(mood),
      );
      if (!explicitMood && groundedMatches.isEmpty) continue;
      final intensity = entry.reflection.emotionalIntensity.clamp(0, 10);
      final score =
          (explicitMood ? 3.0 : 0.0) + groundedMatches.length + intensity / 10;
      results.add(
        _result(
          entry,
          _evidenceForEntry(entry, terms),
          score,
          explicitMood
              ? 'Explicit “${entry.reflection.mood}” mood with intensity $intensity'
              : 'Grounded ${terms.first} wording with intensity $intensity',
        ),
      );
    }
    results.sort(_compareResults);
    return results;
  }

  List<String> _lexicalRanking(
    Map<String, JournalEntry> entries,
    Set<String> terms,
  ) {
    if (terms.isEmpty) return const [];
    Database? database;
    try {
      database = sqlite3.openInMemory();
      database.execute('PRAGMA temp_store = MEMORY');
      database.execute(
        'CREATE VIRTUAL TABLE docs USING fts5(entry_id UNINDEXED, content)',
      );
      final insert = database.prepare(
        'INSERT INTO docs(entry_id, content) VALUES (?, ?)',
      );
      try {
        for (final entry in entries.values) {
          insert.execute([
            entry.id,
            SemanticIndexStore.searchableTextFor(entry),
          ]);
        }
      } finally {
        insert.close();
      }
      final match = terms
          .map((term) => '"${term.replaceAll('"', '""')}"')
          .join(' OR ');
      return database
          .select(
            'SELECT entry_id FROM docs WHERE docs MATCH ? '
            'ORDER BY bm25(docs), entry_id',
            [match],
          )
          .map((row) => row['entry_id'] as String)
          .toList(growable: false);
    } on Object {
      final scored = <({String id, int score})>[];
      for (final entry in entries.values) {
        final tokens = HashedLocalEmbeddingDriver.tokenize(
          SemanticIndexStore.searchableTextFor(entry),
        );
        final score = tokens.where(terms.contains).length;
        if (score > 0) scored.add((id: entry.id, score: score));
      }
      scored.sort((a, b) {
        final score = b.score.compareTo(a.score);
        return score != 0 ? score : a.id.compareTo(b.id);
      });
      return scored.map((item) => item.id).toList(growable: false);
    } finally {
      database?.close();
    }
  }

  ArchiveSemanticSearchResult _result(
    JournalEntry entry,
    _Evidence? evidence,
    double score,
    String reason,
  ) {
    final resolved = evidence ?? _fallbackEvidence(entry.transcript);
    return ArchiveSemanticSearchResult(
      entryId: entry.id,
      date: entry.createdAt,
      score: score,
      reason: reason,
      snippet: resolved.snippet,
      snippetStartUtf16: resolved.snippetStart,
      snippetEndUtf16: resolved.snippetEnd,
      evidenceStartUtf16: resolved.evidenceStart,
      evidenceEndUtf16: resolved.evidenceEnd,
      evidenceSource: resolved.source,
      mood: entry.reflection.mood.trim().isEmpty
          ? null
          : entry.reflection.mood.trim(),
    );
  }

  static _Evidence? _evidenceForEntry(
    JournalEntry entry,
    Iterable<String> terms,
  ) {
    final transcript = _evidenceIn(entry.transcript, terms, 'transcript');
    if (transcript != null) return transcript;
    final reflection = [
      entry.reflection.mood,
      ...entry.reflection.recurringThemes,
      entry.reflection.exactLanguagePattern,
      entry.reflection.concreteObservation,
      entry.reflection.repeatedSignal,
      ...entry.reflection.patternObservations,
    ].where((value) => value.trim().isNotEmpty).join(' · ');
    return _evidenceIn(reflection, terms, 'reflection');
  }

  static _Evidence? _evidenceIn(
    String source,
    Iterable<String> terms,
    String sourceName,
  ) {
    RegExpMatch? best;
    for (final term in terms) {
      final match = RegExp(
        '\\b${RegExp.escape(term)}\\b',
        caseSensitive: false,
      ).firstMatch(source);
      if (match != null && (best == null || match.start < best.start)) {
        best = match;
      }
    }
    if (best == null) return null;
    var start = math.max(0, best.start - 64);
    var end = math.min(source.length, best.end + 96);
    start = _safeStart(source, start);
    end = _safeEnd(source, end);
    return _Evidence(
      snippet: source.substring(start, end),
      snippetStart: start,
      snippetEnd: end,
      evidenceStart: best.start,
      evidenceEnd: best.end,
      source: sourceName,
    );
  }

  static _Evidence _fallbackEvidence(String source) {
    var start = source.indexOf(RegExp(r'\S'));
    if (start < 0) start = 0;
    final end = _safeEnd(source, math.min(source.length, start + 160));
    return _Evidence(
      snippet: source.substring(start, end),
      snippetStart: start,
      snippetEnd: end,
      evidenceStart: start,
      evidenceEnd: start,
      source: 'transcript',
    );
  }

  static Set<String> _expandedQueryTerms(ArchiveSemanticSearchQuery query) => {
    for (final concept in query.concepts)
      ...HashedLocalEmbeddingDriver.expandedTerms(concept),
  };

  static bool _hasEveryConcept(String text, List<String> concepts) {
    final tokens = HashedLocalEmbeddingDriver.tokenize(text).toSet();
    return concepts.every(
      (concept) => HashedLocalEmbeddingDriver.expandedTerms(
        concept,
      ).any(tokens.contains),
    );
  }

  static Set<String> _matchingTerms(String text, Set<String> terms) {
    final tokens = HashedLocalEmbeddingDriver.tokenize(text).toSet();
    return terms.where(tokens.contains).toSet();
  }

  static Set<String> _moodTerms(ArchiveSemanticSearchIntent intent) =>
      switch (intent) {
        ArchiveSemanticSearchIntent.happiest => {
          'happy',
          'happiness',
          'joy',
          'joyful',
          'content',
          'delighted',
        },
        ArchiveSemanticSearchIntent.saddest => {
          'sad',
          'sadness',
          'unhappy',
          'grief',
          'down',
          'heartbroken',
        },
        ArchiveSemanticSearchIntent.mostAnxious => {
          'anxious',
          'anxiety',
          'worried',
          'worry',
          'fear',
          'afraid',
          'panicked',
        },
        ArchiveSemanticSearchIntent.calmest => {
          'calm',
          'peaceful',
          'relaxed',
          'settled',
          'grounded',
        },
        _ => const <String>{},
      };

  static bool _isMood(ArchiveSemanticSearchIntent intent) =>
      intent == ArchiveSemanticSearchIntent.happiest ||
      intent == ArchiveSemanticSearchIntent.saddest ||
      intent == ArchiveSemanticSearchIntent.mostAnxious ||
      intent == ArchiveSemanticSearchIntent.calmest;

  static bool _insideDates(DateTime date, ArchiveSemanticSearchQuery query) {
    final utc = date.toUtc();
    if (query.after != null && utc.isBefore(query.after!)) return false;
    if (query.before != null && !utc.isBefore(query.before!)) return false;
    return true;
  }

  static int _compareResults(
    ArchiveSemanticSearchResult left,
    ArchiveSemanticSearchResult right,
  ) {
    final score = right.score.compareTo(left.score);
    if (score != 0) return score;
    final date = right.date.compareTo(left.date);
    return date != 0 ? date : left.entryId.compareTo(right.entryId);
  }

  static int _safeStart(String text, int index) {
    if (index > 0 &&
        index < text.length &&
        _isLowSurrogate(text.codeUnitAt(index)) &&
        _isHighSurrogate(text.codeUnitAt(index - 1))) {
      return index - 1;
    }
    return index;
  }

  static int _safeEnd(String text, int index) {
    if (index > 0 &&
        index < text.length &&
        _isHighSurrogate(text.codeUnitAt(index - 1)) &&
        _isLowSurrogate(text.codeUnitAt(index))) {
      return index + 1;
    }
    return index;
  }

  static bool _isHighSurrogate(int value) => value >= 0xd800 && value <= 0xdbff;
  static bool _isLowSurrogate(int value) => value >= 0xdc00 && value <= 0xdfff;

  void _checkOpen() {
    if (_disposed) throw StateError('Search engine is disposed.');
  }

  void dispose() => _disposed = true;
}

final class _Evidence {
  const _Evidence({
    required this.snippet,
    required this.snippetStart,
    required this.snippetEnd,
    required this.evidenceStart,
    required this.evidenceEnd,
    required this.source,
  });

  final String snippet;
  final int snippetStart;
  final int snippetEnd;
  final int evidenceStart;
  final int evidenceEnd;
  final String source;
}
