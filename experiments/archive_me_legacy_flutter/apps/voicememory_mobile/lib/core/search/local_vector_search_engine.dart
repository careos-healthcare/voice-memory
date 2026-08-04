import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import '../engines/evidence_reference.dart';
import '../graph/graph_node.dart';
import '../graph/personal_knowledge_graph.dart';

/// An exact, excerpt-free link back to evidence in the encrypted journal.
final class KnowledgeGraphEvidenceLink {
  const KnowledgeGraphEvidenceLink({
    required this.entryId,
    required this.observedAt,
  });

  final String entryId;
  final DateTime observedAt;

  @override
  bool operator ==(Object other) =>
      other is KnowledgeGraphEvidenceLink &&
      entryId == other.entryId &&
      observedAt == other.observedAt;

  @override
  int get hashCode => Object.hash(entryId, observedAt);
}

/// Internal search material built only from the already-governed graph.
///
/// [searchableText] can contain private excerpts and must remain in memory.
final class KnowledgeGraphSearchDocument {
  KnowledgeGraphSearchDocument({
    required this.node,
    required this.searchableText,
    required Iterable<KnowledgeGraphEvidenceLink> evidenceLinks,
  }) : evidenceLinks = List.unmodifiable(evidenceLinks);

  final GraphNode node;
  final String searchableText;
  final List<KnowledgeGraphEvidenceLink> evidenceLinks;
}

/// A UI-safe result. The node is copied without its raw evidence excerpts.
final class KnowledgeGraphSearchHit {
  KnowledgeGraphSearchHit({
    required this.node,
    required Iterable<KnowledgeGraphEvidenceLink> evidenceLinks,
    required this.score,
    required this.bestRank,
  }) : evidenceLinks = List.unmodifiable(evidenceLinks);

  final GraphNode node;
  final List<KnowledgeGraphEvidenceLink> evidenceLinks;
  final double score;
  final int bestRank;
}

/// Injectable boundary for a local or quantized embedding implementation.
abstract interface class LocalEmbeddingDriver {
  int get dimensions;

  Float32List embed(String text);
}

/// Deterministic fallback/local embedder based on normalized hashed features.
///
/// This is not a neural model. It hashes word and character-trigram features
/// into a fixed-size vector, allowing a real quantized embedding driver from a
/// semantic module to be injected later without coupling this core to it.
final class HashedLocalEmbeddingDriver implements LocalEmbeddingDriver {
  const HashedLocalEmbeddingDriver({this.dimensions = 384})
    : assert(dimensions > 0);

  @override
  final int dimensions;

  static final RegExp _tokenPattern = RegExp(r"[a-z0-9]+(?:'[a-z0-9]+)?");

  static const Map<String, List<String>> _semanticAliases = {
    'afraid': ['fear', 'worried'],
    'anxious': ['fear', 'worried'],
    'fear': ['afraid', 'worried'],
    'fears': ['fear', 'afraid', 'worried'],
    'worried': ['fear', 'afraid'],
    'worry': ['fear', 'worried'],
    'career': ['job', 'work', 'office', 'deadline'],
    'job': ['career', 'work', 'office'],
    'work': ['career', 'job', 'office', 'deadline'],
    'office': ['career', 'job', 'work'],
    'deadline': ['work', 'overwhelmed', 'burnout'],
    'deadlines': ['work', 'overwhelmed', 'burnout'],
    'burnout': ['burned', 'exhausted', 'drained', 'overwhelmed', 'deadline'],
    'burned': ['burnout', 'exhausted', 'drained'],
    'exhausted': ['burnout', 'drained', 'overwhelmed'],
    'drained': ['burnout', 'exhausted', 'overwhelmed'],
    'overwhelmed': ['burnout', 'exhausted', 'drained'],
    'happy': ['happiness', 'joy', 'joyful', 'content'],
    'happiness': ['happy', 'joy', 'joyful', 'content'],
    'joy': ['happy', 'happiness', 'joyful'],
    'joyful': ['happy', 'happiness', 'joy'],
    'calm': ['peaceful', 'relaxed', 'settled'],
    'calmest': ['calm', 'peaceful', 'relaxed'],
    'peaceful': ['calm', 'relaxed', 'settled'],
    'relaxed': ['calm', 'peaceful', 'settled'],
    'sad': ['sadness', 'unhappy', 'grief', 'down'],
    'saddest': ['sad', 'sadness', 'unhappy', 'grief'],
    'sadness': ['sad', 'unhappy', 'grief'],
    'coworker': ['person', 'work'],
    'friend': ['person'],
    'who': ['person'],
  };

  @override
  Float32List embed(String text) {
    final vector = Float32List(dimensions);
    final tokens = tokenize(text);
    for (final token in tokens) {
      _addFeature(vector, 'w:$token', 2);
      for (final alias in _semanticAliases[token] ?? const <String>[]) {
        _addFeature(vector, 'w:$alias', 0.75);
      }
      final padded = '^$token\$';
      if (padded.length >= 3) {
        for (var index = 0; index <= padded.length - 3; index++) {
          _addFeature(vector, 't:${padded.substring(index, index + 3)}', 1);
        }
      }
    }
    var squaredNorm = 0.0;
    for (final value in vector) {
      squaredNorm += value * value;
    }
    if (squaredNorm == 0) return vector;
    final inverseNorm = 1 / math.sqrt(squaredNorm);
    for (var index = 0; index < vector.length; index++) {
      vector[index] = vector[index] * inverseNorm;
    }
    return vector;
  }

  static List<String> tokenize(String text) => List.unmodifiable(
    _tokenPattern
        .allMatches(text.toLowerCase())
        .map((match) => match.group(0)!)
        .toList(),
  );

  /// Terms considered semantically equivalent by the deterministic driver.
  static Set<String> expandedTerms(String term) => {
    term.toLowerCase(),
    ...?_semanticAliases[term.toLowerCase()],
  };

  void _addFeature(Float32List vector, String feature, double weight) {
    final hash = _fnv1a(feature);
    final index = hash & 0x7fffffff;
    final sign = hash & 0x80000000 == 0 ? 1.0 : -1.0;
    vector[index % dimensions] += sign * weight;
  }

  static int _fnv1a(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash;
  }
}

abstract interface class LexicalIndex {
  void add(KnowledgeGraphSearchDocument document);

  List<String> search(String query, {int limit = 20});

  void dispose();
}

/// Private-text lexical index backed by an in-memory-only SQLite FTS5 table.
final class SqliteFts5LexicalIndex implements LexicalIndex {
  SqliteFts5LexicalIndex() : _database = sqlite3.openInMemory() {
    try {
      _database.execute('PRAGMA temp_store = MEMORY');
      _database.execute(
        'CREATE VIRTUAL TABLE search_documents '
        'USING fts5(node_id UNINDEXED, content)',
      );
    } catch (_) {
      _database.close();
      rethrow;
    }
  }

  final Database _database;
  bool _disposed = false;

  static bool isAvailable() {
    final database = sqlite3.openInMemory();
    try {
      database.execute('CREATE VIRTUAL TABLE fts5_probe USING fts5(value)');
      return true;
    } catch (_) {
      return false;
    } finally {
      database.close();
    }
  }

  @override
  void add(KnowledgeGraphSearchDocument document) {
    _checkOpen();
    _database.execute('DELETE FROM search_documents WHERE node_id = ?', [
      document.node.id,
    ]);
    _database.execute(
      'INSERT INTO search_documents(node_id, content) VALUES (?, ?)',
      [document.node.id, document.searchableText],
    );
  }

  @override
  List<String> search(String query, {int limit = 20}) {
    _checkOpen();
    if (limit <= 0) return const [];
    final matchQuery = _safeMatchQuery(query);
    if (matchQuery.isEmpty) return const [];
    final rows = _database.select(
      'SELECT node_id FROM search_documents '
      'WHERE search_documents MATCH ? '
      'ORDER BY bm25(search_documents), node_id LIMIT ?',
      [matchQuery, limit],
    );
    return List.unmodifiable(rows.map((row) => row['node_id'] as String));
  }

  static String _safeMatchQuery(String query) =>
      HashedLocalEmbeddingDriver.tokenize(
        query,
      ).map((token) => '"${token.replaceAll('"', '""')}"').join(' OR ');

  void _checkOpen() {
    if (_disposed) throw StateError('Lexical index has been disposed.');
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _database.close();
  }
}

/// Pure-Dart fallback for platforms or low-spec tests without FTS5.
final class InMemoryLexicalIndex implements LexicalIndex {
  final Map<String, String> _documents = {};
  bool _disposed = false;

  @override
  void add(KnowledgeGraphSearchDocument document) {
    _checkOpen();
    _documents[document.node.id] = document.searchableText;
  }

  @override
  List<String> search(String query, {int limit = 20}) {
    _checkOpen();
    if (limit <= 0) return const [];
    final queryTokens = HashedLocalEmbeddingDriver.tokenize(query).toSet();
    if (queryTokens.isEmpty) return const [];
    final scored = <({String id, double score})>[];
    for (final entry in _documents.entries) {
      final documentTokens = HashedLocalEmbeddingDriver.tokenize(entry.value);
      var score = 0.0;
      for (final token in documentTokens) {
        if (queryTokens.contains(token)) score += 1;
      }
      if (score > 0) scored.add((id: entry.key, score: score));
    }
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.id.compareTo(b.id);
    });
    return List.unmodifiable(scored.take(limit).map((item) => item.id));
  }

  void _checkOpen() {
    if (_disposed) throw StateError('Lexical index has been disposed.');
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _documents.clear();
  }
}

final class LocalVectorSearchEngine {
  LocalVectorSearchEngine({
    required PersonalKnowledgeGraph graph,
    LocalEmbeddingDriver? embeddingDriver,
    LexicalIndex? lexicalIndex,
    this.maxEvidenceCharacters = 1200,
  }) : assert(maxEvidenceCharacters >= 0),
       _embeddingDriver = embeddingDriver ?? const HashedLocalEmbeddingDriver(),
       _lexicalIndex = lexicalIndex ?? _createDefaultLexicalIndex() {
    _build(graph);
  }

  final LocalEmbeddingDriver _embeddingDriver;
  final LexicalIndex _lexicalIndex;
  final int maxEvidenceCharacters;
  final Map<String, KnowledgeGraphSearchDocument> _documents = {};
  final Map<String, Float32List> _embeddings = {};
  bool _disposed = false;

  List<KnowledgeGraphSearchHit> search(
    String query, {
    int limit = 20,
    int retrievalLimit = 50,
    int rrfK = 60,
  }) {
    _checkOpen();
    if (limit <= 0 || retrievalLimit <= 0 || query.trim().isEmpty) {
      return const [];
    }
    final queryEmbedding = _embeddingDriver.embed(query);
    final dense = _documents.keys.toList();
    dense.sort((a, b) {
      final byScore = cosineSimilarity(
        queryEmbedding,
        _embeddings[b]!,
      ).compareTo(cosineSimilarity(queryEmbedding, _embeddings[a]!));
      return byScore != 0 ? byScore : _compareDocumentIds(a, b, _documents);
    });
    final denseRanking = dense
        .where((id) => cosineSimilarity(queryEmbedding, _embeddings[id]!) > 0)
        .take(retrievalLimit)
        .toList();
    final lexicalRanking = _lexicalIndex.search(query, limit: retrievalLimit);
    return fuseRankings(
      documents: _documents,
      denseRanking: denseRanking,
      lexicalRanking: lexicalRanking,
      limit: limit,
      k: rrfK,
    );
  }

  static double cosineSimilarity(List<num> left, List<num> right) {
    if (left.length != right.length) {
      throw ArgumentError('Cosine vectors must have equal dimensions.');
    }
    var dot = 0.0;
    var leftNorm = 0.0;
    var rightNorm = 0.0;
    for (var index = 0; index < left.length; index++) {
      final leftValue = left[index].toDouble();
      final rightValue = right[index].toDouble();
      dot += leftValue * rightValue;
      leftNorm += leftValue * leftValue;
      rightNorm += rightValue * rightValue;
    }
    if (leftNorm == 0 || rightNorm == 0) return 0;
    return dot / (math.sqrt(leftNorm) * math.sqrt(rightNorm));
  }

  static double rrfScore(Iterable<int> ranks, {int k = 60}) {
    if (k < 0) throw ArgumentError.value(k, 'k', 'Must be non-negative.');
    var score = 0.0;
    for (final rank in ranks) {
      if (rank < 1) {
        throw ArgumentError.value(rank, 'ranks', 'Ranks are 1-based.');
      }
      score += 1 / (k + rank);
    }
    return score;
  }

  static List<KnowledgeGraphSearchHit> fuseRankings({
    required Map<String, KnowledgeGraphSearchDocument> documents,
    required List<String> denseRanking,
    required List<String> lexicalRanking,
    int limit = 20,
    int k = 60,
  }) {
    if (limit <= 0) return const [];
    final ranks = <String, List<int>>{};
    for (final ranking in [denseRanking, lexicalRanking]) {
      final seen = <String>{};
      for (var index = 0; index < ranking.length; index++) {
        final id = ranking[index];
        if (documents.containsKey(id) && seen.add(id)) {
          ranks.putIfAbsent(id, () => []).add(index + 1);
        }
      }
    }
    final hits = <KnowledgeGraphSearchHit>[];
    for (final entry in ranks.entries) {
      final document = documents[entry.key]!;
      final source = document.node;
      hits.add(
        KnowledgeGraphSearchHit(
          node: GraphNode(
            id: source.id,
            type: source.type,
            label: source.label,
            confidence: source.confidence,
          ),
          evidenceLinks: document.evidenceLinks,
          score: rrfScore(entry.value, k: k),
          bestRank: entry.value.reduce(
            (left, right) => left < right ? left : right,
          ),
        ),
      );
    }
    hits.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      final byRank = a.bestRank.compareTo(b.bestRank);
      if (byRank != 0) return byRank;
      final byLabel = a.node.label.toLowerCase().compareTo(
        b.node.label.toLowerCase(),
      );
      return byLabel != 0 ? byLabel : a.node.id.compareTo(b.node.id);
    });
    return List.unmodifiable(hits.take(limit));
  }

  void _build(PersonalKnowledgeGraph graph) {
    for (final node in graph.nodes) {
      final references = referencesForNode(graph, node);
      final evidenceLinks = LinkedHashSet<KnowledgeGraphEvidenceLink>.from(
        references.map(
          (item) => KnowledgeGraphEvidenceLink(
            entryId: item.entryId,
            observedAt: item.observedAt,
          ),
        ),
      ).toList();
      final evidenceText = _cappedEvidenceText(
        references.map((item) => item.excerpt),
        maxEvidenceCharacters,
      );
      final searchableText = [
        node.label,
        node.type.name,
        if (evidenceText.isNotEmpty) evidenceText,
      ].join(' ');
      final document = KnowledgeGraphSearchDocument(
        node: node,
        searchableText: searchableText,
        evidenceLinks: evidenceLinks,
      );
      _documents[node.id] = document;
      _embeddings[node.id] = _embeddingDriver.embed(searchableText);
      _lexicalIndex.add(document);
    }
  }

  static String _cappedEvidenceText(Iterable<String> excerpts, int cap) {
    if (cap == 0) return '';
    final joined = excerpts
        .map((value) => value.trim().replaceAll(RegExp(r'\s+'), ' '))
        .where((value) => value.isNotEmpty)
        .join(' ');
    return joined.length <= cap ? joined : joined.substring(0, cap);
  }

  static LexicalIndex _createDefaultLexicalIndex() {
    try {
      return SqliteFts5LexicalIndex();
    } catch (_) {
      return InMemoryLexicalIndex();
    }
  }

  static int _compareDocumentIds(
    String left,
    String right,
    Map<String, KnowledgeGraphSearchDocument> documents,
  ) {
    final byLabel = documents[left]!.node.label.toLowerCase().compareTo(
      documents[right]!.node.label.toLowerCase(),
    );
    return byLabel != 0 ? byLabel : left.compareTo(right);
  }

  void _checkOpen() {
    if (_disposed) throw StateError('Search engine has been disposed.');
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _lexicalIndex.dispose();
    _documents.clear();
    _embeddings.clear();
  }
}
