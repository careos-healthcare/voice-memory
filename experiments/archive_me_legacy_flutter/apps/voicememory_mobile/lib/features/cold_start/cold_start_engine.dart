import '../../core/graph/graph_node.dart';
import '../../core/graph/personal_knowledge_graph.dart';
import '../../core/graph/personal_knowledge_graph_store.dart';
import '../../models/journal_entry.dart';
import '../../storage/mobile_prefs_store.dart';
import '../archive_evidence/comparable_evidence_text.dart';

enum ColdStartFocus { work, health, growth, relationships }

class ColdStartSeedData {
  const ColdStartSeedData({
    this.people = const [],
    this.focus,
    this.goalOrChallenge = '',
    this.completedAt,
  });

  final List<String> people;
  final ColdStartFocus? focus;
  final String goalOrChallenge;
  final DateTime? completedAt;

  bool get hasContext =>
      people.isNotEmpty || focus != null || goalOrChallenge.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
    if (people.isNotEmpty) 'people': people.take(2).toList(),
    if (focus case final focus?) 'focus': focus.name,
    if (goalOrChallenge.trim().isNotEmpty)
      'goalOrChallenge': goalOrChallenge.trim(),
    if (completedAt case final completedAt?)
      'completedAt': completedAt.toUtc().toIso8601String(),
  };

  static ColdStartSeedData? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final rawPeople = json['people'];
    final people = (rawPeople is List ? rawPeople : const <Object?>[])
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .take(2)
        .toList();
    final focusName = json['focus']?.toString();
    final focus = ColdStartFocus.values
        .where((candidate) => candidate.name == focusName)
        .firstOrNull;
    final goal = json['goalOrChallenge']?.toString().trim() ?? '';
    return ColdStartSeedData(
      people: people,
      focus: focus,
      goalOrChallenge: goal,
      completedAt: DateTime.tryParse(json['completedAt']?.toString() ?? ''),
    );
  }
}

class ColdStartSeedStore {
  const ColdStartSeedStore(this._prefs);

  static const prefsKey = 'coldStartSeedSurveyV1';
  static const burstShownKey = 'coldStartFirstBurstShownV1';
  final MobilePrefsStore _prefs;

  Future<ColdStartSeedData?> load() async =>
      ColdStartSeedData.fromJson(await _prefs.readMap(prefsKey));

  Future<bool> isComplete() async => await load() != null;

  Future<void> save(ColdStartSeedData data) =>
      _prefs.writeMap(prefsKey, data.toJson());

  Future<bool> isFirstBurstShown() async =>
      await _prefs.readBool(burstShownKey) ?? false;

  Future<void> markFirstBurstShown() => _prefs.writeBool(burstShownKey, true);

  Future<void> resetForTest() async {
    await _prefs.remove(prefsKey);
    await _prefs.remove(burstShownKey);
  }
}

class ColdStartEngine {
  const ColdStartEngine({required this.seedStore, required this.graphStore});

  final ColdStartSeedStore seedStore;
  final PersonalKnowledgeGraphStore graphStore;

  PersonalKnowledgeGraph generate(ColdStartSeedData data) {
    final peopleText = data.people.join(', ');
    final nodes = <GraphNode>[];
    for (final person in data.people) {
      final start = peopleText.indexOf(person);
      nodes.add(
        GraphNode(
          origin: NodeOrigin.systemSeed,
          type: NodeType.person,
          label: person,
          confidence: .95,
          evidence: [
            _nodeEvidence(
              entryId: 'cold-start-people',
              excerpt: person,
              start: start,
            ),
          ],
        ),
      );
    }
    final focus = data.focus;
    final focusNode = focus == null
        ? null
        : GraphNode(
            origin: NodeOrigin.systemSeed,
            type: NodeType.topic,
            label: _focusLabel(focus),
            confidence: .92,
            evidence: [
              _nodeEvidence(
                entryId: 'cold-start-focus',
                excerpt: _focusLabel(focus),
                start: 0,
              ),
            ],
          );
    if (focusNode != null) nodes.add(focusNode);

    final goal = data.goalOrChallenge.trim();
    final goalNode = goal.isEmpty
        ? null
        : GraphNode(
            origin: NodeOrigin.systemSeed,
            type: NodeType.goal,
            label: goal,
            confidence: .9,
            evidence: [
              _nodeEvidence(
                entryId: 'cold-start-goal',
                excerpt: goal,
                start: 0,
              ),
            ],
          );
    if (goalNode != null) nodes.add(goalNode);

    final edges = <GraphEdge>[
      if (focusNode != null)
        for (final person in nodes.where(
          (node) => node.type == NodeType.person,
        ))
          GraphEdge(
            origin: NodeOrigin.systemSeed,
            sourceNodeId: person.id,
            targetNodeId: focusNode.id,
            type: EdgeType.associatedWith,
            isDirected: false,
            weight: .72,
            evidence: [_edgeEvidence(focusNode.evidence.first)],
          ),
      if (goalNode != null && focusNode != null)
        GraphEdge(
          origin: NodeOrigin.systemSeed,
          sourceNodeId: goalNode.id,
          targetNodeId: focusNode.id,
          type: EdgeType.influences,
          isDirected: true,
          weight: .8,
          evidence: [_edgeEvidence(goalNode.evidence.first)],
        ),
    ];
    return PersonalKnowledgeGraph(nodes: nodes, edges: edges);
  }

  Future<PersonalKnowledgeGraph> persist(ColdStartSeedData data) async {
    final completed = ColdStartSeedData(
      people: data.people,
      focus: data.focus,
      goalOrChallenge: data.goalOrChallenge,
      completedAt: DateTime.now().toUtc(),
    );
    final current = await graphStore.load();
    final merged = merge(current, generate(completed));
    final seeded = PersonalKnowledgeGraph(
      schemaVersion: 2,
      nodes: merged.nodes,
      edges: merged.edges,
      trajectories: merged.trajectories,
      materialization: GraphMaterializationMetadata(
        processedEntryRevisions:
            current.materialization.processedEntryRevisions,
        extractorVersion: graphStore.extractorVersion,
        governanceVersion: graphStore.governanceVersion,
        governanceHash: graphStore.governanceHash,
        materializedAt: DateTime.now().toUtc(),
      ),
    );
    await graphStore.save(seeded);
    await seedStore.save(completed);
    return seeded;
  }

  PersonalKnowledgeGraph merge(
    PersonalKnowledgeGraph base,
    PersonalKnowledgeGraph additions,
  ) {
    final nodes = {for (final node in base.nodes) node.id: node};
    final edges = {for (final edge in base.edges) edge.id: edge};
    for (final node in additions.nodes) {
      nodes[node.id] = node;
    }
    for (final edge in additions.edges) {
      edges[edge.id] = edge;
    }
    return PersonalKnowledgeGraph(
      schemaVersion: base.schemaVersion,
      nodes: nodes.values,
      edges: edges.values,
      trajectories: base.trajectories,
      materialization: base.materialization,
    );
  }

  PersonalKnowledgeGraph connectFirstEntry(
    PersonalKnowledgeGraph graph,
    JournalEntry entry,
  ) {
    final text = ComparableEvidenceText.userText(entry);
    if (text.isEmpty) return graph;
    final sourceId = stableGraphId('journal-entry', [entry.id]);
    final evidence = GraphEdgeEvidence(
      entryId: entry.id,
      observedAt: entry.createdAt,
      confidence: .75,
      excerpt: text,
      startUtf16: 0,
      endUtf16: text.length,
    );
    final seedNodes = graph.nodes
        .where(
          (node) => node.evidence.any(
            (item) => item.entryId.startsWith('cold-start-'),
          ),
        )
        .take(3);
    final edges = [...graph.edges];
    for (final seed in seedNodes) {
      final edge = GraphEdge(
        origin: NodeOrigin.systemSeed,
        sourceNodeId: sourceId,
        targetNodeId: seed.id,
        type: EdgeType.associatedWith,
        isDirected: false,
        weight: .75,
        evidence: [evidence],
      );
      if (!edges.any((existing) => existing.id == edge.id)) edges.add(edge);
    }
    return PersonalKnowledgeGraph(
      schemaVersion: graph.schemaVersion,
      nodes: graph.nodes,
      edges: edges,
      trajectories: graph.trajectories,
      materialization: graph.materialization,
    );
  }

  static String _focusLabel(ColdStartFocus focus) => switch (focus) {
    ColdStartFocus.work => 'Work',
    ColdStartFocus.health => 'Health',
    ColdStartFocus.growth => 'Growth',
    ColdStartFocus.relationships => 'Relationships',
  };

  static GraphNodeEvidence _nodeEvidence({
    required String entryId,
    required String excerpt,
    required int start,
  }) => GraphNodeEvidence(
    entryId: entryId,
    observedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    confidence: 1,
    excerpt: excerpt,
    startUtf16: start,
    endUtf16: start + excerpt.length,
  );

  static GraphEdgeEvidence _edgeEvidence(GraphNodeEvidence evidence) =>
      GraphEdgeEvidence(
        entryId: evidence.entryId,
        observedAt: evidence.observedAt,
        confidence: evidence.confidence,
        excerpt: evidence.excerpt,
        startUtf16: evidence.startUtf16,
        endUtf16: evidence.endUtf16,
      );
}
