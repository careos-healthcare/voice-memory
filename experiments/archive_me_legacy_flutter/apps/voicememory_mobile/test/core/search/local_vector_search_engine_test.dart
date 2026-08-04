import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/core/search/local_vector_search_engine.dart';

void main() {
  group('HashedLocalEmbeddingDriver', () {
    test('produces deterministic normalized Float32 embeddings', () {
      const driver = HashedLocalEmbeddingDriver(dimensions: 128);

      final first = driver.embed('Career planning with Sarah');
      final second = driver.embed('Career planning with Sarah');

      expect(first, isA<Float32List>());
      expect(first, orderedEquals(second));
      expect(first.length, 128);
      final norm = first.fold<double>(0, (sum, value) => sum + value * value);
      expect(norm, closeTo(1, 0.000001));
      expect(driver.embed(''), everyElement(0));
    });
  });

  group('cosine similarity', () {
    test('handles equal, orthogonal, and zero vectors', () {
      expect(
        LocalVectorSearchEngine.cosineSimilarity([1, 0], [1, 0]),
        closeTo(1, 0.000001),
      );
      expect(LocalVectorSearchEngine.cosineSimilarity([1, 0], [0, 1]), 0);
      expect(LocalVectorSearchEngine.cosineSimilarity([0, 0], [1, 2]), 0);
      expect(
        () => LocalVectorSearchEngine.cosineSimilarity([1], [1, 2]),
        throwsArgumentError,
      );
    });
  });

  group('lexical indexes', () {
    test('FTS5 ranks matching documents when compiled in', () {
      if (!SqliteFts5LexicalIndex.isAvailable()) return;
      final index = SqliteFts5LexicalIndex();
      addTearDown(index.dispose);
      index
        ..add(_document('career', 'Career change', 'software career promotion'))
        ..add(_document('garden', 'Garden', 'tomatoes and basil'));

      expect(index.search('software career').first, 'career');
    });

    test('FTS5 query construction is injection-safe', () {
      if (!SqliteFts5LexicalIndex.isAvailable()) return;
      final index = SqliteFts5LexicalIndex();
      addTearDown(index.dispose);
      index
        ..add(_document('safe', 'Sarah', 'Sarah is a trusted friend'))
        ..add(_document('other', 'Other', 'unrelated'));

      expect(
        () => index.search('Sarah" OR *; DROP TABLE search_documents; --'),
        returnsNormally,
      );
      expect(index.search('Sarah').first, 'safe');
    });

    test('in-memory fallback ranks and disposes', () {
      final index = InMemoryLexicalIndex()
        ..add(_document('b', 'B', 'career career'))
        ..add(_document('a', 'A', 'career'));

      expect(index.search('career'), ['b', 'a']);
      index.dispose();
      index.dispose();
      expect(() => index.search('career'), throwsStateError);
    });
  });

  test('dense retrieval ranks matching graph nodes', () {
    final graph = PersonalKnowledgeGraph(
      nodes: [
        _node('person', NodeType.person, 'Sarah', 'close friend and mentor'),
        _node(
          'career',
          NodeType.goal,
          'Software career growth',
          'promotion and meaningful work',
        ),
        _node('garden', NodeType.habit, 'Water plants', 'garden tomatoes'),
      ],
    );
    final engine = LocalVectorSearchEngine(
      graph: graph,
      lexicalIndex: _EmptyLexicalIndex(),
    );
    addTearDown(engine.dispose);

    expect(engine.search('career promotion').first.node.id, 'career');
  });

  group('RRF', () {
    test('uses exact standard score sum', () {
      expect(
        LocalVectorSearchEngine.rrfScore([1, 3]),
        closeTo(1 / 61 + 1 / 63, 0.000000000001),
      );
      expect(() => LocalVectorSearchEngine.rrfScore([0]), throwsArgumentError);
    });

    test('applies fused score, best rank, label, and id tie breaks', () {
      final documents = {
        'z': _document('z', 'Zulu', 'zulu'),
        'a2': _document('a2', 'Alpha', 'alpha'),
        'a1': _document('a1', 'Alpha', 'alpha'),
        'best': _document('best', 'Best', 'best'),
      };

      final hits = LocalVectorSearchEngine.fuseRankings(
        documents: documents,
        denseRanking: ['best', 'z', 'a2', 'a1'],
        lexicalRanking: ['z', 'best', 'a1', 'a2'],
      );

      expect(hits.take(2).map((hit) => hit.node.id), ['best', 'z']);
      expect(hits.skip(2).map((hit) => hit.node.id), ['a1', 'a2']);
      expect(hits.first.bestRank, 1);
    });
  });

  test('returns exact deduplicated evidence links without excerpts', () {
    final firstDate = DateTime.utc(2026, 1, 2);
    final secondDate = DateTime.utc(2026, 2, 3);
    final node = GraphNode(
      id: 'sarah',
      type: NodeType.person,
      label: 'Sarah',
      confidence: 0.9,
      evidence: [
        GraphNodeEvidence(
          entryId: 'journal/exact-a',
          observedAt: firstDate,
          confidence: 1,
          excerpt: 'private raw phrase one',
          startUtf16: 0,
          endUtf16: 'private raw phrase one'.length,
        ),
        GraphNodeEvidence(
          entryId: 'journal/exact-a',
          observedAt: firstDate,
          confidence: 0.8,
          excerpt: 'duplicate private wording',
          startUtf16: 0,
          endUtf16: 'duplicate private wording'.length,
        ),
        GraphNodeEvidence(
          entryId: 'journal/exact-b',
          observedAt: secondDate,
          confidence: 1,
          excerpt: 'private raw phrase two',
          startUtf16: 0,
          endUtf16: 'private raw phrase two'.length,
        ),
      ],
    );
    final connected = GraphNode(
      id: 'career',
      type: NodeType.goal,
      label: 'Career growth',
      confidence: 0.8,
    );
    final engine = LocalVectorSearchEngine(
      graph: PersonalKnowledgeGraph(
        nodes: [node, connected],
        edges: [
          GraphEdge(
            sourceNodeId: node.id,
            targetNodeId: connected.id,
            type: EdgeType.influences,
            isDirected: true,
            weight: 0.8,
            evidence: [
              GraphEdgeEvidence(
                entryId: 'journal/exact-edge',
                observedAt: DateTime.utc(2026, 3, 4),
                confidence: 0.8,
                excerpt: 'private connected wording',
                startUtf16: 0,
                endUtf16: 'private connected wording'.length,
              ),
            ],
          ),
        ],
      ),
      lexicalIndex: InMemoryLexicalIndex(),
    );
    addTearDown(engine.dispose);

    final hit = engine
        .search('Sarah')
        .singleWhere((candidate) => candidate.node.id == 'sarah');
    expect(hit.node.evidence, isEmpty);
    expect(hit.evidenceLinks, [
      KnowledgeGraphEvidenceLink(
        entryId: 'journal/exact-a',
        observedAt: firstDate,
      ),
      KnowledgeGraphEvidenceLink(
        entryId: 'journal/exact-b',
        observedAt: secondDate,
      ),
      KnowledgeGraphEvidenceLink(
        entryId: 'journal/exact-edge',
        observedAt: DateTime.utc(2026, 3, 4),
      ),
    ]);
  });

  test('natural-language Sarah, career, and fear queries rank sensibly', () {
    final graph = PersonalKnowledgeGraph(
      nodes: [
        _node('sarah', NodeType.person, 'Sarah Chen', 'close friend from work'),
        _node(
          'career',
          NodeType.goal,
          'Build a fulfilling career',
          'software job promotion and meaningful work',
        ),
        _node(
          'fear',
          NodeType.fear,
          'Public speaking',
          'worried about presenting to a large audience',
        ),
      ],
    );
    final engine = LocalVectorSearchEngine(
      graph: graph,
      lexicalIndex: InMemoryLexicalIndex(),
    );
    addTearDown(engine.dispose);

    expect(engine.search('Who is Sarah?').first.node.id, 'sarah');
    expect(engine.search('How is my career going?').first.node.id, 'career');
    expect(engine.search('What am I afraid of?').first.node.id, 'fear');
  });

  test('engine disposal releases lexical index and is idempotent', () {
    final lexical = _TrackingLexicalIndex();
    final engine = LocalVectorSearchEngine(
      graph: PersonalKnowledgeGraph(),
      lexicalIndex: lexical,
    );

    engine.dispose();
    engine.dispose();

    expect(lexical.disposed, isTrue);
    expect(() => engine.search('anything'), throwsStateError);
  });
}

KnowledgeGraphSearchDocument _document(
  String id,
  String label,
  String searchableText,
) => KnowledgeGraphSearchDocument(
  node: GraphNode(id: id, type: NodeType.memory, label: label, confidence: 1),
  searchableText: searchableText,
  evidenceLinks: const [],
);

GraphNode _node(String id, NodeType type, String label, String excerpt) =>
    GraphNode(
      id: id,
      type: type,
      label: label,
      confidence: 1,
      evidence: [
        GraphNodeEvidence(
          entryId: 'entry-$id',
          observedAt: DateTime.utc(2026, 1, 1),
          confidence: 1,
          excerpt: excerpt,
        ),
      ],
    );

class _EmptyLexicalIndex implements LexicalIndex {
  @override
  void add(KnowledgeGraphSearchDocument document) {}

  @override
  List<String> search(String query, {int limit = 20}) => const [];

  @override
  void dispose() {}
}

final class _TrackingLexicalIndex extends _EmptyLexicalIndex {
  bool disposed = false;

  @override
  void dispose() => disposed = true;
}
