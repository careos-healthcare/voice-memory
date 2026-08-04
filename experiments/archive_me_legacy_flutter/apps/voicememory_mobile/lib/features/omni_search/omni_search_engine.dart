import 'dart:math' as math;

import 'package:sqlite3/sqlite3.dart';

import '../../core/graph/graph_node.dart';
import '../../core/graph/personal_knowledge_graph.dart';
import '../../core/search/local_vector_search_engine.dart';
import '../../features/ai_engines/models/ai_explainability.dart';
import '../../features/ai_engines/models/hypothesis_evolution.dart';
import '../../features/archive_semantic_search/semantic_index_store.dart';
import '../../models/journal_entry.dart';
import '../../storage/journal_store.dart';
import '../../services/ai/local_semantic_store.dart';
import 'search_intent.dart';

enum OmniSearchResultKind { graphNode, audioMemory, activeTheory }

class OmniSearchCandidate {
  const OmniSearchCandidate({
    required this.kind,
    required this.id,
    required this.title,
    required this.snippet,
    required this.createdAt,
    required this.matchedTerms,
    this.node,
    this.entry,
    this.theory,
    this.exactQuote,
    this.audioTimestampMs,
  });

  final OmniSearchResultKind kind;
  final String id;
  final String title;
  final String snippet;
  final DateTime createdAt;
  final List<String> matchedTerms;
  final GraphNode? node;
  final JournalEntry? entry;
  final HypothesisEvolution? theory;
  final String? exactQuote;
  final int? audioTimestampMs;

  String get dedupeKey => '${kind.name}:$id';

  VerifiableCitation? get citation {
    final quote = exactQuote?.trim();
    if (entry == null || quote == null || quote.isEmpty) return null;
    return VerifiableCitation(
      sourceEntryId: entry!.id,
      exactQuote: quote,
      audioTimestampMs: audioTimestampMs,
      confidenceScore: 1,
    );
  }
}

class OmniSearchResult {
  const OmniSearchResult({
    required this.candidate,
    required this.score,
    required this.matchReasons,
  });

  final OmniSearchCandidate candidate;
  final double score;
  final List<String> matchReasons;
}

class OmniSearchResults {
  const OmniSearchResults({
    required this.intent,
    required this.graphNodes,
    required this.audioMemories,
    required this.activeTheories,
  });

  final SearchIntent intent;
  final List<OmniSearchResult> graphNodes;
  final List<OmniSearchResult> audioMemories;
  final List<OmniSearchResult> activeTheories;

  bool get isEmpty =>
      graphNodes.isEmpty && audioMemories.isEmpty && activeTheories.isEmpty;
}

abstract interface class OmniSearchSource {
  String get sourceName;
  Future<List<OmniSearchCandidate>> search(
    SearchIntent intent, {
    int limit = 50,
  });
}

class OmniSearchEngine {
  const OmniSearchEngine({
    required this.lexicalSource,
    required this.semanticSource,
    required this.theorySource,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final OmniSearchSource lexicalSource;
  final OmniSearchSource semanticSource;
  final OmniSearchSource theorySource;
  final DateTime Function() _clock;

  Future<OmniSearchResults> search(
    SearchIntent intent, {
    int limitPerSection = 20,
  }) async {
    final sourceRows = await Future.wait([
      lexicalSource.search(intent),
      semanticSource.search(intent),
      theorySource.search(intent),
    ]);
    final sources = [lexicalSource, semanticSource, theorySource];
    final fused = <String, _FusedCandidate>{};
    for (var sourceIndex = 0; sourceIndex < sourceRows.length; sourceIndex++) {
      final rows = sourceRows[sourceIndex];
      for (var rank = 0; rank < rows.length; rank++) {
        final candidate = rows[rank];
        final group = fused.putIfAbsent(
          candidate.dedupeKey,
          () => _FusedCandidate(candidate),
        );
        group.score += 1 / (60 + rank + 1);
        group.reasons.add(sources[sourceIndex].sourceName);
        if (candidate.snippet.length > group.candidate.snippet.length) {
          group.candidate = candidate;
        }
      }
    }
    final now = _clock().toUtc();
    final ranked =
        fused.values.map((group) {
          final ageDays = math.max(
            0,
            now.difference(group.candidate.createdAt.toUtc()).inDays,
          );
          final recencyBoost = .02 * (1 - math.min(ageDays, 3650) / 3650);
          return OmniSearchResult(
            candidate: group.candidate,
            score: group.score + recencyBoost,
            matchReasons: group.reasons.toList()..sort(),
          );
        }).toList()..sort((left, right) {
          final score = right.score.compareTo(left.score);
          if (score != 0) return score;
          final date = right.candidate.createdAt.compareTo(
            left.candidate.createdAt,
          );
          if (date != 0) return date;
          return left.candidate.title.compareTo(right.candidate.title);
        });

    List<OmniSearchResult> section(OmniSearchResultKind kind) => ranked
        .where((result) => result.candidate.kind == kind)
        .take(limitPerSection)
        .toList(growable: false);
    return OmniSearchResults(
      intent: intent,
      graphNodes: section(OmniSearchResultKind.graphNode),
      audioMemories: section(OmniSearchResultKind.audioMemory),
      activeTheories: section(OmniSearchResultKind.activeTheory),
    );
  }
}

class SqliteOmniLexicalSource implements OmniSearchSource {
  const SqliteOmniLexicalSource({
    required this.loadGraph,
    required this.journalStore,
  });

  final Future<PersonalKnowledgeGraph> Function() loadGraph;
  final JournalStore journalStore;

  @override
  String get sourceName => 'Exact or fuzzy text';

  @override
  Future<List<OmniSearchCandidate>> search(
    SearchIntent intent, {
    int limit = 50,
  }) async {
    final graph = await loadGraph();
    final entries = await journalStore.loadEligible();
    final candidates = <String, OmniSearchCandidate>{};
    for (final node in graph.nodes) {
      if (!_nodeAllowed(node, intent) || !_nodeInWindow(node, intent)) {
        continue;
      }
      candidates['node:${node.id}'] = _nodeCandidate(node, intent);
    }
    for (final entry in entries) {
      if (!_entryInWindow(entry, intent)) continue;
      candidates['entry:${entry.id}'] = _entryCandidate(entry, intent);
    }
    final database = sqlite3.openInMemory();
    try {
      database.execute(
        'CREATE VIRTUAL TABLE omni_docs USING fts5(key UNINDEXED, content)',
      );
      final insert = database.prepare(
        'INSERT INTO omni_docs(key, content) VALUES (?, ?)',
      );
      try {
        for (final row in candidates.entries) {
          insert.execute([row.key, _searchableText(row.value)]);
        }
      } finally {
        insert.close();
      }
      final match = _safeFtsQuery(intent);
      if (match.isEmpty) return const [];
      final rows = database.select(
        'SELECT key FROM omni_docs WHERE omni_docs MATCH ? '
        'ORDER BY bm25(omni_docs), key LIMIT ?',
        [match, limit],
      );
      return rows
          .map((row) => candidates[row['key'] as String])
          .whereType<OmniSearchCandidate>()
          .where((candidate) => _containsRequired(candidate, intent))
          .toList(growable: false);
    } on SqliteException {
      return candidates.values
          .where((candidate) => _containsRequired(candidate, intent))
          .where((candidate) => candidate.matchedTerms.isNotEmpty)
          .take(limit)
          .toList(growable: false);
    } finally {
      database.close();
    }
  }
}

class VectorOmniSemanticSource implements OmniSearchSource {
  const VectorOmniSemanticSource({
    required this.loadGraph,
    required this.journalStore,
    required this.semanticIndexStore,
    this.embeddingDriver = const HashedLocalEmbeddingDriver(),
  });

  final Future<PersonalKnowledgeGraph> Function() loadGraph;
  final JournalStore journalStore;
  final SemanticIndexStore semanticIndexStore;
  final LocalEmbeddingDriver embeddingDriver;

  @override
  String get sourceName => 'Semantic similarity';

  @override
  Future<List<OmniSearchCandidate>> search(
    SearchIntent intent, {
    int limit = 50,
  }) async {
    final graph = await loadGraph();
    final graphEngine = LocalVectorSearchEngine(
      graph: graph,
      embeddingDriver: embeddingDriver,
    );
    final graphHits = graphEngine.search(intent.semanticQuery, limit: limit);
    graphEngine.dispose();

    final entries = {
      for (final entry in await journalStore.loadEligible()) entry.id: entry,
    };
    final snapshot = await semanticIndexStore.loadSnapshot();
    final queryVector = embeddingDriver.embed(intent.semanticQuery);
    final entryIds = snapshot.vectors.keys.toList()
      ..sort((left, right) {
        final leftScore = LocalVectorSearchEngine.cosineSimilarity(
          queryVector,
          snapshot.vectors[left]!,
        );
        final rightScore = LocalVectorSearchEngine.cosineSimilarity(
          queryVector,
          snapshot.vectors[right]!,
        );
        return rightScore.compareTo(leftScore);
      });
    return [
      for (final hit in graphHits)
        if (_nodeAllowed(hit.node, intent) && _nodeInWindow(hit.node, intent))
          _nodeCandidate(hit.node, intent),
      for (final id in entryIds.take(limit))
        if (entries[id] case final entry?)
          if (_entryInWindow(entry, intent)) _entryCandidate(entry, intent),
    ].where((candidate) => _containsRequired(candidate, intent)).toList();
  }
}

class ActiveTheoryOmniSource implements OmniSearchSource {
  const ActiveTheoryOmniSource(this.semanticStore);

  final LocalSemanticStore semanticStore;

  @override
  String get sourceName => 'Active confidence theory';

  @override
  Future<List<OmniSearchCandidate>> search(
    SearchIntent intent, {
    int limit = 50,
  }) async {
    final terms = _queryTerms(intent);
    final theories = await semanticStore.activeHypotheses(limit: limit * 2);
    return theories
        .where((theory) {
          final haystack = theory.statement.toLowerCase();
          return terms.any(haystack.contains) &&
              (intent.timeframe == null ||
                  intent.timeframe!.includes(
                    theory.evolutionHistory.last.date,
                  ));
        })
        .map(
          (theory) => OmniSearchCandidate(
            kind: OmniSearchResultKind.activeTheory,
            id: theory.theoryId,
            title: theory.statement,
            snippet:
                '${theory.currentConfidence}% confidence · ${theory.evolutionHistory.last.deltaReasoning}',
            createdAt: theory.evolutionHistory.last.date,
            matchedTerms: _matchedTerms(theory.statement, intent),
            theory: theory,
          ),
        )
        .where((candidate) => _containsRequired(candidate, intent))
        .take(limit)
        .toList(growable: false);
  }
}

class _FusedCandidate {
  _FusedCandidate(this.candidate);

  OmniSearchCandidate candidate;
  double score = 0;
  final Set<String> reasons = {};
}

OmniSearchCandidate _nodeCandidate(GraphNode node, SearchIntent intent) {
  final excerpt = node.evidence.firstOrNull?.excerpt ?? node.label;
  return OmniSearchCandidate(
    kind: OmniSearchResultKind.graphNode,
    id: node.id,
    title: node.label,
    snippet: _snippet(excerpt, intent),
    createdAt: node.evidence.firstOrNull?.observedAt ?? node.createdAt,
    matchedTerms: _matchedTerms('$node.label $excerpt', intent),
    node: node,
  );
}

OmniSearchCandidate _entryCandidate(JournalEntry entry, SearchIntent intent) {
  final quote = _exactQuote(entry.transcript, intent);
  return OmniSearchCandidate(
    kind: OmniSearchResultKind.audioMemory,
    id: entry.id,
    title: entry.reflectionSummary.isEmpty
        ? 'Voice memory'
        : entry.reflectionSummary,
    snippet: quote.replaceAll(RegExp(r'\s+'), ' ').trim(),
    createdAt: entry.createdAt,
    matchedTerms: _matchedTerms(
      SemanticIndexStore.searchableTextFor(entry),
      intent,
    ),
    entry: entry,
    exactQuote: quote,
  );
}

bool _nodeAllowed(GraphNode node, SearchIntent intent) {
  if (intent.nodeTypes.isEmpty) return true;
  final mapped = switch (node.type) {
    NodeType.person => OmniNodeType.person,
    NodeType.emotion || NodeType.fear => OmniNodeType.emotion,
    NodeType.goal || NodeType.decision || NodeType.outcome => OmniNodeType.goal,
    NodeType.habit => OmniNodeType.habit,
    NodeType.project => OmniNodeType.project,
    NodeType.place => OmniNodeType.place,
    NodeType.belief => OmniNodeType.belief,
    _ => null,
  };
  return mapped != null && intent.nodeTypes.contains(mapped);
}

bool _nodeInWindow(GraphNode node, SearchIntent intent) =>
    intent.timeframe == null ||
    node.evidence.any(
      (evidence) => intent.timeframe!.includes(evidence.observedAt),
    );

bool _entryInWindow(JournalEntry entry, SearchIntent intent) =>
    intent.timeframe == null || intent.timeframe!.includes(entry.createdAt);

String _safeFtsQuery(SearchIntent intent) => _queryTerms(
  intent,
).map((term) => '"${term.replaceAll('"', '""')}"').join(' OR ');

List<String> _queryTerms(SearchIntent intent) => {
  ...HashedLocalEmbeddingDriver.tokenize(intent.semanticQuery),
  ...intent.requiredEntities.expand(HashedLocalEmbeddingDriver.tokenize),
}.where((term) => term.length > 1).take(24).toList();

List<String> _matchedTerms(String value, SearchIntent intent) {
  final lower = value.toLowerCase();
  return _queryTerms(intent).where(lower.contains).toSet().toList();
}

bool _containsRequired(OmniSearchCandidate candidate, SearchIntent intent) {
  if (intent.requiredEntities.isEmpty) return true;
  final haystack = _searchableText(candidate).toLowerCase();
  return intent.requiredEntities.every(
    (entity) => haystack.contains(entity.toLowerCase()),
  );
}

String _searchableText(OmniSearchCandidate candidate) =>
    '${candidate.title}\n${candidate.snippet}';

String _snippet(String text, SearchIntent intent) {
  final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.length <= 180) return compact;
  final lower = compact.toLowerCase();
  final first =
      _queryTerms(
        intent,
      ).map(lower.indexOf).where((index) => index >= 0).firstOrNull ??
      0;
  final start = math.max(0, first - 64);
  final end = math.min(compact.length, start + 180);
  return '${start > 0 ? '…' : ''}${compact.substring(start, end)}'
      '${end < compact.length ? '…' : ''}';
}

String _exactQuote(String text, SearchIntent intent) {
  if (text.length <= 180) return text.trim();
  final lower = text.toLowerCase();
  final first =
      _queryTerms(
        intent,
      ).map(lower.indexOf).where((index) => index >= 0).firstOrNull ??
      0;
  final start = math.max(0, first - 64);
  final end = math.min(text.length, start + 180);
  return text.substring(start, end).trim();
}
