import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph_store.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/local_capture_context.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  group('graph values', () {
    test('uses stable IDs, clamps scores, and round-trips JSON', () {
      final evidence = GraphNodeEvidence(
        entryId: 'entry-exact',
        observedAt: DateTime.utc(2026, 1, 2),
        confidence: 4,
        excerpt: List.filled(200, 'x').join(),
        startUtf16: 0,
        endUtf16: 200,
      );
      final first = GraphNode(
        type: NodeType.goal,
        label: ' Run a marathon ',
        confidence: -2,
        evidence: [evidence],
      );
      final second = GraphNode(
        type: NodeType.goal,
        label: 'run   a marathon',
        confidence: 0.5,
      );

      expect(first.id, second.id);
      expect(first.confidence, 0);
      expect(first.evidence.single.confidence, 1);
      expect(first.evidence.single.excerpt.length, 200);
      final decoded = GraphNode.fromJson(first.toJson());
      expect(decoded.id, first.id);
      expect(decoded.evidence.single.entryId, 'entry-exact');
      expect(decoded.evidence.single.startUtf16, 0);
      expect(decoded.evidence.single.endUtf16, 200);
      final edgeEvidence = GraphEdgeEvidence(
        entryId: 'edge-entry',
        observedAt: DateTime.utc(2026, 1, 2),
        confidence: 0.7,
        excerpt: '🙂 exact edge',
        startUtf16: 4,
        endUtf16: 17,
      );
      final decodedEdge = GraphEdgeEvidence.fromJson(edgeEvidence.toJson());
      expect(decodedEdge.toJson(), edgeEvidence.toJson());
      expect(
        GraphNodeEvidence.fromJson({
          'entryId': 'legacy',
          'excerpt': 'quote',
        }).hasStructurallyValidCitation,
        isFalse,
      );
    });
  });

  group('PersonalKnowledgeGraphEngine', () {
    test('merges entities and preserves exact evidence citations', () {
      final engine = PersonalKnowledgeGraphEngine(
        extractor: _FixtureExtractor(),
      );
      final graph = engine.ingestAll([
        _entry('journal/A', DateTime.utc(2026, 1, 1), 'first private wording'),
        _entry('journal/B', DateTime.utc(2026, 1, 2), 'second private wording'),
      ]);

      final alice = graph.nodes.singleWhere(
        (node) => node.type == NodeType.person,
      );
      expect(alice.evidence.map((item) => item.entryId), [
        'journal/A',
        'journal/B',
      ]);
      expect(alice.evidence.map((item) => item.observedAt), [
        DateTime.utc(2026, 1, 1),
        DateTime.utc(2026, 1, 2),
      ]);
      expect(
        graph.edges.any((edge) => edge.type == EdgeType.mentionedWith),
        isTrue,
      );
      final influence = graph.edges.singleWhere(
        (edge) => edge.type == EdgeType.influences,
      );
      expect(influence.isDirected, isTrue);
      expect(influence.evidence.map((item) => item.entryId), [
        'journal/A',
        'journal/B',
      ]);
      expect(influence.evidence.first.excerpt, 'first private wording');
    });

    test('incremental ingestion is idempotent per source entry', () {
      final engine = PersonalKnowledgeGraphEngine(
        extractor: _FixtureExtractor(),
      );
      final entry = _entry(
        'journal/A',
        DateTime.utc(2026, 1, 1),
        'first private wording',
      );

      final initial = engine.ingest(entry);
      final repeated = engine.ingest(entry, into: initial);

      expect(
        repeated.nodes.expand((node) => node.evidence),
        hasLength(initial.nodes.length),
      );
      expect(
        repeated.edges.expand((edge) => edge.evidence),
        hasLength(initial.edges.length),
      );
    });

    test('excludes governed entries', () {
      final engine = PersonalKnowledgeGraphEngine(
        extractor: _FixtureExtractor(),
      );
      final graph = engine.ingestAll([
        _entry('ok', DateTime.utc(2026, 1, 1), 'usable'),
        _entry(
          'archived',
          DateTime.utc(2026, 1, 2),
          'hidden',
          isArchived: true,
        ),
        _entry(
          'separate',
          DateTime.utc(2026, 1, 3),
          'separate',
          keepSeparate: true,
        ),
        _entry('new', DateTime.utc(2026, 1, 4), 'fresh', treatAsNew: true),
        _entry(
          'no-surface',
          DateTime.utc(2026, 1, 5),
          'private',
          memorySurfacing: 'do_not_surface',
        ),
      ]);

      for (final node in graph.nodes) {
        expect(node.evidence.map((item) => item.entryId).toSet(), {'ok'});
      }
    });

    test(
      'default extractor rejects context labels without transcript spans',
      () {
        final graph = PersonalKnowledgeGraphEngine().ingest(
          _entry(
            'context',
            DateTime.utc(2026, 2, 1),
            'I want to finish the book. I remember summer camp.',
            localCaptureContext: LocalCaptureContext(
              capturedAt: DateTime.utc(2026, 2, 1),
              locationLabel: 'Central Library',
              calendarEventName: 'Writing Circle',
            ),
          ),
        );

        expect(graph.nodes.any((node) => node.type == NodeType.goal), isTrue);
        expect(graph.nodes.any((node) => node.type == NodeType.memory), isTrue);
        expect(
          graph.nodes.any(
            (node) =>
                node.type == NodeType.place && node.label == 'Central Library',
          ),
          isFalse,
        );
        expect(
          graph.nodes.any(
            (node) =>
                node.type == NodeType.event && node.label == 'Writing Circle',
          ),
          isFalse,
        );
      },
    );

    test('drops mentions and relations with non-exact evidence', () {
      final graph = PersonalKnowledgeGraphEngine(
        extractor: _InvalidEvidenceExtractor(),
      ).ingest(_entry('invalid', DateTime.utc(2026, 1, 1), 'Exact transcript'));

      expect(graph.nodes, isEmpty);
      expect(graph.edges, isEmpty);
    });

    test('async rebuild is deterministic and sync-equivalent', () async {
      final asyncExtractor = _AsyncFixtureExtractor();
      final engine = PersonalKnowledgeGraphEngine(extractor: asyncExtractor);
      final later = _entry(
        'journal/B',
        DateTime.utc(2026, 1, 2),
        'second private wording',
      );
      final earlier = _entry(
        'journal/A',
        DateTime.utc(2026, 1, 1),
        'first private wording',
      );

      final asyncGraph = await engine.rebuildAsync([later, earlier]);
      final syncGraph = engine.rebuild([earlier, later]);

      expect(asyncExtractor.asyncEntryOrder, [
        'first private wording',
        'second private wording',
      ]);
      expect(asyncGraph.toJson(), syncGraph.toJson());
    });

    test('async ingestion preserves governance and idempotency', () async {
      final engine = PersonalKnowledgeGraphEngine(
        extractor: _AsyncFixtureExtractor(),
      );
      final eligible = _entry('ok', DateTime.utc(2026, 1, 1), 'usable');
      final initial = await engine.ingestAllAsync([
        _entry(
          'archived',
          DateTime.utc(2026, 1, 2),
          'hidden',
          isArchived: true,
        ),
        eligible,
      ]);
      final repeated = await engine.ingestTranscriptionAsync(
        eligible,
        into: initial,
      );

      expect(
        repeated.nodes.expand((node) => node.evidence),
        hasLength(initial.nodes.length),
      );
      expect(
        repeated.edges.expand((edge) => edge.evidence),
        hasLength(initial.edges.length),
      );
      for (final node in repeated.nodes) {
        expect(node.evidence.map((item) => item.entryId).toSet(), {'ok'});
      }
    });
  });

  group('PersonalKnowledgeGraph queries', () {
    test('ranks frequency in a deterministic timeframe', () {
      final engine = PersonalKnowledgeGraphEngine(
        extractor: _FrequencyExtractor(),
        clock: () => DateTime.utc(2026, 1, 10),
      );
      final graph = engine.ingestAll([
        _entry('old', DateTime.utc(2026, 1, 1), 'Alice'),
        _entry('recent-a', DateTime.utc(2026, 1, 9), 'Alice'),
        _entry('recent-b', DateTime.utc(2026, 1, 10), 'Bob'),
      ]);

      expect(
        graph
            .getEntitiesByFrequency(
              type: NodeType.person,
              timeframe: const Duration(days: 2),
            )
            .map((node) => node.label),
        ['Alice', 'Bob'],
      );
      expect(
        graph.getEntitiesByFrequency(type: NodeType.person).first.label,
        'Alice',
      );
    });

    test('finds shortest directed path including endpoints', () {
      final a = GraphNode(type: NodeType.person, label: 'A', confidence: 1);
      final b = GraphNode(type: NodeType.place, label: 'B', confidence: 1);
      final c = GraphNode(type: NodeType.goal, label: 'C', confidence: 1);
      final graph = PersonalKnowledgeGraph(
        nodes: [a, b, c],
        edges: [
          GraphEdge(
            sourceNodeId: a.id,
            targetNodeId: b.id,
            type: EdgeType.influences,
            isDirected: true,
            weight: 1,
          ),
          GraphEdge(
            sourceNodeId: b.id,
            targetNodeId: c.id,
            type: EdgeType.associatedWith,
            isDirected: false,
            weight: 1,
          ),
        ],
      );

      expect(graph.findPath(a.id, c.id).map((node) => node.id), [
        a.id,
        b.id,
        c.id,
      ]);
      expect(graph.findPath(c.id, a.id), isEmpty);
      expect(
        graph.getConnectedNodes(b.id, type: EdgeType.influences).single.id,
        a.id,
      );
      expect(graph.findPath('missing', a.id), isEmpty);
    });
  });

  test('encrypted store saves, loads, clears, and rebuilds', () async {
    final directory = await Directory.systemTemp.createTemp('graph_store_');
    addTearDown(() => directory.delete(recursive: true));
    final encryptedFile = File('${directory.path}/knowledge_graph.enc');
    final store = PersonalKnowledgeGraphStore(
      storage: EncryptedJsonFileStore(
        file: encryptedFile,
        keyStore: InMemoryPrivateDataEncryptionKeyStore(),
      ),
      engine: PersonalKnowledgeGraphEngine(extractor: _FixtureExtractor()),
    );

    final rebuilt = await store.rebuild([
      _entry('stored-entry', DateTime.utc(2026, 3, 1), 'source text'),
    ]);
    final loaded = await store.load();
    expect(loaded.toJson(), rebuilt.toJson());
    expect(loaded.nodes.first.evidence.first.entryId, 'stored-entry');
    expect(
      await EncryptedJsonFileStore.fileOmitsPlaintextNeedle(
        encryptedFile,
        'Alice mention',
      ),
      isTrue,
    );

    await store.clear();
    expect((await store.load()).nodes, isEmpty);
  });

  test('migrates structurally cited v1 graphs to schema v2', () {
    final node = GraphNode(
      type: NodeType.belief,
      label: 'Practice helps',
      confidence: 0.8,
      evidence: [
        GraphNodeEvidence(
          entryId: 'legacy-entry',
          observedAt: DateTime.utc(2025, 1, 1),
          confidence: 0.8,
          excerpt: 'I believe practice helps',
          startUtf16: 0,
          endUtf16: 24,
        ),
      ],
    );
    final migrated = PersonalKnowledgeGraph.fromJson({
      'schemaVersion': 1,
      'nodes': [node.toJson()],
      'edges': <Object?>[],
    });

    expect(migrated.schemaVersion, 2);
    expect(migrated.nodes.single.id, node.id);
    expect(migrated.nodes.single.evidence.single.startUtf16, 0);
    expect(migrated.trajectories, isEmpty);
  });

  test(
    'reconcile is idempotent and removes updated and deleted evidence',
    () async {
      final directory = await Directory.systemTemp.createTemp('graph_delta_');
      addTearDown(() => directory.delete(recursive: true));
      final store = PersonalKnowledgeGraphStore(
        storage: EncryptedJsonFileStore(
          file: File('${directory.path}/graph.enc'),
          keyStore: InMemoryPrivateDataEncryptionKeyStore(),
        ),
        engine: PersonalKnowledgeGraphEngine(extractor: _FrequencyExtractor()),
      );
      final first = _entry('a', DateTime.utc(2026, 1, 1), 'Alice');
      final second = _entry('b', DateTime.utc(2026, 1, 2), 'Bob');

      final initial = await store.reconcile([first, second]);
      final repeated = await store.reconcile([first, second]);
      expect(repeated.toJson(), initial.toJson());

      final changed = _entry('a', DateTime.utc(2026, 1, 1), 'Carol');
      final reconciled = await store.reconcile([changed]);
      expect(reconciled.nodes.map((node) => node.label), ['Carol']);
      expect(reconciled.materialization.processedEntryRevisions.keys, {'a'});
    },
  );

  test('serializes concurrent materialized graph writes', () async {
    final directory = await Directory.systemTemp.createTemp(
      'graph_concurrent_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final store = PersonalKnowledgeGraphStore(
      storage: EncryptedJsonFileStore(
        file: File('${directory.path}/graph.enc'),
        keyStore: InMemoryPrivateDataEncryptionKeyStore(),
      ),
      engine: PersonalKnowledgeGraphEngine(extractor: _FrequencyExtractor()),
    );
    final entries = List.generate(
      8,
      (index) => _entry(
        'entry-$index',
        DateTime.utc(2026, 1, index + 1),
        'Person$index',
      ),
    );

    await Future.wait([
      for (var index = 1; index <= entries.length; index++)
        store.reconcile(entries.take(index)),
    ]);

    final graph = await store.load();
    expect(graph.nodes, hasLength(entries.length));
    expect(
      graph.materialization.processedEntryRevisions,
      hasLength(entries.length),
    );
  });

  test('rule extraction materializes v2 entities and exact trajectories', () {
    const text =
        'I felt anxious about Sarah. I started Project Phoenix. '
        'I decided to ship the beta and it resulted in five signups.';
    final graph = PersonalKnowledgeGraphEngine().ingest(
      _entry('v2', DateTime.utc(2026, 4, 1), text),
    );

    expect(
      graph.nodes.map((node) => node.type),
      containsAll([
        NodeType.emotion,
        NodeType.project,
        NodeType.decision,
        NodeType.outcome,
      ]),
    );
    for (final trajectory in graph.trajectories) {
      for (final window in trajectory.windows) {
        expect(window.evidence, isNotEmpty);
        for (final evidence in window.evidence) {
          expect(evidence.isExactSliceOf(text), isTrue);
        }
      }
    }
    expect(
      graph.trajectories.map((item) => item.type),
      contains(GraphTrajectoryType.relationshipSentiment),
    );
  });
}

class _FixtureExtractor implements GraphEntityExtractor {
  @override
  GraphExtraction extract({
    required String text,
    LocalCaptureContext? localCaptureContext,
  }) => GraphExtraction(
    entities: [
      GraphEntityMention(
        type: NodeType.person,
        label: 'Alice',
        confidence: 0.8,
        excerpt: text,
        startUtf16: 0,
        endUtf16: text.length,
      ),
      GraphEntityMention(
        type: NodeType.goal,
        label: 'Write a book',
        confidence: 0.75,
        excerpt: text,
        startUtf16: 0,
        endUtf16: text.length,
      ),
    ],
    relations: [
      GraphRelationMention(
        sourceType: NodeType.person,
        sourceLabel: 'Alice',
        targetType: NodeType.goal,
        targetLabel: 'Write a book',
        type: EdgeType.influences,
        isDirected: true,
        confidence: 0.7,
        excerpt: text,
        startUtf16: 0,
        endUtf16: text.length,
      ),
    ],
  );
}

class _FrequencyExtractor implements GraphEntityExtractor {
  @override
  GraphExtraction extract({
    required String text,
    LocalCaptureContext? localCaptureContext,
  }) => GraphExtraction(
    entities: [
      GraphEntityMention(
        type: NodeType.person,
        label: text,
        confidence: 0.8,
        excerpt: text,
        startUtf16: 0,
        endUtf16: text.length,
      ),
    ],
  );
}

class _AsyncFixtureExtractor
    implements GraphEntityExtractor, AsyncGraphEntityExtractor {
  final _sync = _FixtureExtractor();
  final List<String> asyncEntryOrder = [];

  @override
  GraphExtraction extract({
    required String text,
    LocalCaptureContext? localCaptureContext,
  }) => _sync.extract(text: text, localCaptureContext: localCaptureContext);

  @override
  Future<GraphExtraction> extractAsync({
    required String text,
    LocalCaptureContext? localCaptureContext,
  }) async {
    asyncEntryOrder.add(text);
    await Future<void>.delayed(Duration.zero);
    return extract(text: text, localCaptureContext: localCaptureContext);
  }
}

class _InvalidEvidenceExtractor implements GraphEntityExtractor {
  @override
  GraphExtraction extract({
    required String text,
    LocalCaptureContext? localCaptureContext,
  }) => GraphExtraction(
    entities: [
      GraphEntityMention(
        type: NodeType.person,
        label: 'Alice',
        confidence: 1,
        excerpt: 'exact transcript',
        startUtf16: 0,
        endUtf16: text.length,
      ),
    ],
    relations: [
      GraphRelationMention(
        sourceType: NodeType.person,
        sourceLabel: 'Alice',
        targetType: NodeType.goal,
        targetLabel: 'Goal',
        type: EdgeType.influences,
        isDirected: true,
        confidence: 1,
        excerpt: text,
        startUtf16: 1,
        endUtf16: text.length,
      ),
    ],
  );
}

JournalEntry _entry(
  String id,
  DateTime createdAt,
  String transcript, {
  bool isArchived = false,
  bool keepSeparate = false,
  bool treatAsNew = false,
  String memorySurfacing = 'normal',
  LocalCaptureContext? localCaptureContext,
}) => JournalEntry(
  id: id,
  createdAt: createdAt,
  transcript: transcript,
  durationSeconds: 1,
  reflection: const Reflection(
    mood: '',
    emotionalIntensity: 0,
    recurringThemes: [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  ),
  isArchived: isArchived,
  keepSeparate: keepSeparate,
  treatAsNew: treatAsNew,
  memorySurfacing: memorySurfacing,
  localCaptureContext: localCaptureContext,
);
