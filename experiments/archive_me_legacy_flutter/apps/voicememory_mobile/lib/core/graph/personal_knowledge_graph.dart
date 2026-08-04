import '../../features/archive_evidence/comparable_evidence_text.dart';
import '../../models/journal_entry.dart';
import '../../models/local_capture_context.dart';
import '../llm/on_device_extractor.dart';
import 'graph_node.dart';

typedef GraphClock = DateTime Function();
typedef _EntryExtraction = ({
  JournalEntry entry,
  String text,
  GraphExtraction extraction,
});
typedef _PreparedEntry = ({JournalEntry entry, String text});

enum GraphTrajectoryType {
  beliefEvolution,
  relationshipSentiment,
  habitFrequency,
  projectProgress,
  decisionOutcome,
}

class GraphTrajectoryWindow {
  GraphTrajectoryWindow({
    String? id,
    required this.start,
    required this.end,
    required num value,
    required this.label,
    Iterable<GraphTrajectoryEvidence> evidence = const [],
  }) : value = value.toDouble(),
       evidence = List.unmodifiable(
         evidence.where((item) => item.hasStructurallyValidCitation),
       ),
       id =
           id ??
           stableGraphId('window', [
             start.toUtc().toIso8601String(),
             end.toUtc().toIso8601String(),
             label,
           ]);

  final String id;
  final DateTime start;
  final DateTime end;
  final double value;
  final String label;
  final List<GraphTrajectoryEvidence> evidence;

  bool get hasValidEvidence =>
      evidence.isNotEmpty &&
      evidence.every((item) => item.hasStructurallyValidCitation);

  Map<String, dynamic> toJson() => {
    'id': id,
    'start': start.toUtc().toIso8601String(),
    'end': end.toUtc().toIso8601String(),
    'value': value,
    'label': label,
    'evidence': evidence.map((item) => item.toJson()).toList(),
  };

  factory GraphTrajectoryWindow.fromJson(Map<String, dynamic> json) {
    final evidence = (json['evidence'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) =>
              GraphTrajectoryEvidence.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((item) => item.hasStructurallyValidCitation)
        .toList();
    return GraphTrajectoryWindow(
      id: json['id'] as String?,
      start:
          DateTime.tryParse(json['start'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      end:
          DateTime.tryParse(json['end'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      value: json['value'] as num? ?? 0,
      label: json['label'] as String? ?? '',
      evidence: evidence,
    );
  }
}

class GraphTrajectory {
  GraphTrajectory({
    String? id,
    required this.type,
    required this.subjectNodeId,
    this.relatedNodeId,
    Iterable<GraphTrajectoryWindow> windows = const [],
  }) : windows = List.unmodifiable(
         windows.where((window) => window.hasValidEvidence),
       ),
       id =
           id ??
           stableGraphId('trajectory', [
             type.name,
             subjectNodeId,
             relatedNodeId ?? '',
           ]);

  final String id;
  final GraphTrajectoryType type;
  final String subjectNodeId;
  final String? relatedNodeId;
  final List<GraphTrajectoryWindow> windows;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'subjectNodeId': subjectNodeId,
    'relatedNodeId': relatedNodeId,
    'windows': windows.map((item) => item.toJson()).toList(),
  };

  factory GraphTrajectory.fromJson(Map<String, dynamic> json) =>
      GraphTrajectory(
        id: json['id'] as String?,
        type: GraphTrajectoryType.values.byName(
          json['type'] as String? ?? GraphTrajectoryType.beliefEvolution.name,
        ),
        subjectNodeId: json['subjectNodeId'] as String? ?? '',
        relatedNodeId: json['relatedNodeId'] as String?,
        windows: (json['windows'] as List? ?? const []).whereType<Map>().map(
          (item) =>
              GraphTrajectoryWindow.fromJson(Map<String, dynamic>.from(item)),
        ),
      );
}

class GraphMaterializationMetadata {
  const GraphMaterializationMetadata({
    this.processedEntryRevisions = const {},
    this.extractorVersion = '',
    this.governanceVersion = '',
    this.governanceHash = '',
    this.materializedAt,
  });

  final Map<String, String> processedEntryRevisions;
  final String extractorVersion;
  final String governanceVersion;
  final String governanceHash;
  final DateTime? materializedAt;

  Map<String, dynamic> toJson() => {
    'processedEntryRevisions': processedEntryRevisions,
    'extractorVersion': extractorVersion,
    'governanceVersion': governanceVersion,
    'governanceHash': governanceHash,
    'materializedAt': materializedAt?.toUtc().toIso8601String(),
  };

  factory GraphMaterializationMetadata.fromJson(Map<String, dynamic> json) =>
      GraphMaterializationMetadata(
        processedEntryRevisions: Map<String, String>.from(
          json['processedEntryRevisions'] as Map? ?? const {},
        ),
        extractorVersion: json['extractorVersion'] as String? ?? '',
        governanceVersion: json['governanceVersion'] as String? ?? '',
        governanceHash: json['governanceHash'] as String? ?? '',
        materializedAt: DateTime.tryParse(
          json['materializedAt'] as String? ?? '',
        ),
      );
}

class PersonalKnowledgeGraph {
  PersonalKnowledgeGraph({
    this.schemaVersion = 2,
    Iterable<GraphNode> nodes = const [],
    Iterable<GraphEdge> edges = const [],
    Iterable<GraphTrajectory> trajectories = const [],
    this.materialization = const GraphMaterializationMetadata(),
    this.clock,
  }) : nodes = List.unmodifiable(nodes),
       edges = List.unmodifiable(edges),
       trajectories = List.unmodifiable(trajectories);

  final int schemaVersion;
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final List<GraphTrajectory> trajectories;
  final GraphMaterializationMetadata materialization;
  final GraphClock? clock;

  List<GraphNode> getConnectedNodes(String nodeId, {EdgeType? type}) {
    final byId = {for (final node in nodes) node.id: node};
    final connected = <String>{};
    for (final edge in edges) {
      if (type != null && edge.type != type) continue;
      if (edge.sourceNodeId == nodeId) connected.add(edge.targetNodeId);
      if (edge.targetNodeId == nodeId) connected.add(edge.sourceNodeId);
    }
    final result = connected
        .map((id) => byId[id])
        .whereType<GraphNode>()
        .toList();
    result.sort((a, b) => a.id.compareTo(b.id));
    return List.unmodifiable(result);
  }

  List<GraphNode> findPath(String sourceNodeId, String targetNodeId) {
    final byId = {for (final node in nodes) node.id: node};
    if (!byId.containsKey(sourceNodeId) || !byId.containsKey(targetNodeId)) {
      return const [];
    }
    if (sourceNodeId == targetNodeId) return [byId[sourceNodeId]!];

    final queue = <String>[sourceNodeId];
    final previous = <String, String?>{sourceNodeId: null};
    var cursor = 0;
    while (cursor < queue.length) {
      final current = queue[cursor++];
      final neighbors = <String>[];
      for (final edge in edges) {
        if (edge.sourceNodeId == current) {
          neighbors.add(edge.targetNodeId);
        }
        if (!edge.isDirected && edge.targetNodeId == current) {
          neighbors.add(edge.sourceNodeId);
        }
      }
      neighbors.sort();
      for (final neighbor in neighbors) {
        if (previous.containsKey(neighbor) || !byId.containsKey(neighbor)) {
          continue;
        }
        previous[neighbor] = current;
        if (neighbor == targetNodeId) {
          final ids = <String>[targetNodeId];
          String? step = current;
          while (step != null) {
            ids.add(step);
            step = previous[step];
          }
          return List.unmodifiable(
            ids.reversed.map((id) => byId[id]!).toList(),
          );
        }
        queue.add(neighbor);
      }
    }
    return const [];
  }

  List<GraphNode> getEntitiesByFrequency({
    NodeType? type,
    Duration? timeframe,
  }) {
    final reference = clock?.call().toUtc() ?? _latestObservation();
    final ranked = <({GraphNode node, int count})>[];
    for (final node in nodes) {
      if (type != null && node.type != type) continue;
      final count = timeframe == null
          ? node.evidence.length
          : node.evidence
                .where(
                  (item) =>
                      !item.observedAt.isBefore(reference.subtract(timeframe)),
                )
                .length;
      if (count > 0) ranked.add((node: node, count: count));
    }
    ranked.sort((a, b) {
      final frequency = b.count.compareTo(a.count);
      return frequency != 0
          ? frequency
          : a.node.label.toLowerCase().compareTo(b.node.label.toLowerCase());
    });
    return List.unmodifiable(ranked.map((item) => item.node));
  }

  DateTime _latestObservation() {
    DateTime? latest;
    for (final node in nodes) {
      for (final evidence in node.evidence) {
        if (latest == null || evidence.observedAt.isAfter(latest)) {
          latest = evidence.observedAt;
        }
      }
    }
    return latest ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'nodes': nodes.map((node) => node.toJson()).toList(),
    'edges': edges.map((edge) => edge.toJson()).toList(),
    if (schemaVersion >= 2)
      'trajectories': trajectories.map((item) => item.toJson()).toList(),
    if (schemaVersion >= 2) 'materialization': materialization.toJson(),
  };

  factory PersonalKnowledgeGraph.fromJson(
    Map<String, dynamic> json, {
    GraphClock? clock,
  }) {
    final sourceVersion = (json['schemaVersion'] as num?)?.toInt() ?? 1;
    if (sourceVersion != 1 && sourceVersion != 2) {
      throw FormatException('Unsupported graph schema version: $sourceVersion');
    }
    final nodes = (json['nodes'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => GraphNode.fromJson(Map<String, dynamic>.from(item)))
        .where(
          (item) =>
              item.hasValidEvidence ||
              item.origin == NodeOrigin.media ||
              item.origin == NodeOrigin.document ||
              item.origin == NodeOrigin.horizon,
        )
        .toList();
    final nodeIds = nodes.map((item) => item.id).toSet();
    final edges = (json['edges'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => GraphEdge.fromJson(Map<String, dynamic>.from(item)))
        .where(
          (item) =>
              (item.hasValidEvidence ||
                  item.origin == NodeOrigin.media ||
                  item.origin == NodeOrigin.document ||
                  item.origin == NodeOrigin.horizon) &&
              nodeIds.contains(item.sourceNodeId) &&
              nodeIds.contains(item.targetNodeId),
        )
        .toList();
    final trajectories = sourceVersion < 2
        ? const <GraphTrajectory>[]
        : (json['trajectories'] as List? ?? const [])
              .whereType<Map>()
              .map(
                (item) =>
                    GraphTrajectory.fromJson(Map<String, dynamic>.from(item)),
              )
              .where(
                (item) =>
                    item.windows.isNotEmpty &&
                    nodeIds.contains(item.subjectNodeId) &&
                    (item.relatedNodeId == null ||
                        nodeIds.contains(item.relatedNodeId)),
              )
              .toList();
    return PersonalKnowledgeGraph(
      schemaVersion: 2,
      nodes: nodes,
      edges: edges,
      trajectories: trajectories,
      materialization: sourceVersion < 2
          ? const GraphMaterializationMetadata()
          : GraphMaterializationMetadata.fromJson(
              Map<String, dynamic>.from(
                json['materialization'] as Map? ?? const {},
              ),
            ),
      clock: clock,
    );
  }
}

class GraphEntityMention {
  GraphEntityMention({
    required this.type,
    required String label,
    required num confidence,
    this.excerpt,
    this.startUtf16 = -1,
    this.endUtf16 = -1,
  }) : label = label.trim(),
       confidence = clampGraphScore(confidence);

  final NodeType type;
  final String label;
  final double confidence;
  final String? excerpt;
  final int startUtf16;
  final int endUtf16;

  bool isExactSliceOf(String text) {
    final quote = excerpt;
    return quote != null &&
        quote.isNotEmpty &&
        startUtf16 >= 0 &&
        endUtf16 > startUtf16 &&
        endUtf16 <= text.length &&
        text.substring(startUtf16, endUtf16) == quote;
  }
}

class GraphRelationMention {
  GraphRelationMention({
    required this.sourceType,
    required String sourceLabel,
    required this.targetType,
    required String targetLabel,
    required this.type,
    required this.isDirected,
    required num confidence,
    this.excerpt,
    this.startUtf16 = -1,
    this.endUtf16 = -1,
  }) : sourceLabel = sourceLabel.trim(),
       targetLabel = targetLabel.trim(),
       confidence = clampGraphScore(confidence);

  final NodeType sourceType;
  final String sourceLabel;
  final NodeType targetType;
  final String targetLabel;
  final EdgeType type;
  final bool isDirected;
  final double confidence;
  final String? excerpt;
  final int startUtf16;
  final int endUtf16;

  bool isExactSliceOf(String text) {
    final quote = excerpt;
    return quote != null &&
        quote.isNotEmpty &&
        startUtf16 >= 0 &&
        endUtf16 > startUtf16 &&
        endUtf16 <= text.length &&
        text.substring(startUtf16, endUtf16) == quote;
  }
}

class GraphExtraction {
  GraphExtraction({
    Iterable<GraphEntityMention> entities = const [],
    Iterable<GraphRelationMention> relations = const [],
  }) : entities = List.unmodifiable(entities),
       relations = List.unmodifiable(relations);

  final List<GraphEntityMention> entities;
  final List<GraphRelationMention> relations;
}

abstract interface class GraphEntityExtractor {
  GraphExtraction extract({
    required String text,
    LocalCaptureContext? localCaptureContext,
  });
}

abstract interface class AsyncGraphEntityExtractor {
  Future<GraphExtraction> extractAsync({
    required String text,
    LocalCaptureContext? localCaptureContext,
  });
}

class PersonalKnowledgeGraphEngine {
  PersonalKnowledgeGraphEngine({GraphEntityExtractor? extractor, this.clock})
    : extractor = extractor ?? const OnDeviceSemanticExtractor();

  final GraphEntityExtractor extractor;
  final GraphClock? clock;

  PersonalKnowledgeGraph ingest(
    JournalEntry entry, {
    PersonalKnowledgeGraph? into,
  }) => ingestAll([entry], into: into);

  Future<PersonalKnowledgeGraph> ingestAsync(
    JournalEntry entry, {
    PersonalKnowledgeGraph? into,
  }) => ingestAllAsync([entry], into: into);

  /// Ingests an already-persisted transcription with its real evidence
  /// metadata. Raw strings are intentionally not accepted because an entry ID
  /// and observation timestamp cannot be inferred safely.
  PersonalKnowledgeGraph ingestTranscription(
    JournalEntry entry, {
    PersonalKnowledgeGraph? into,
  }) => ingest(entry, into: into);

  Future<PersonalKnowledgeGraph> ingestTranscriptionAsync(
    JournalEntry entry, {
    PersonalKnowledgeGraph? into,
  }) => ingestAsync(entry, into: into);

  PersonalKnowledgeGraph ingestAll(
    Iterable<JournalEntry> entries, {
    PersonalKnowledgeGraph? into,
  }) {
    final base = into ?? PersonalKnowledgeGraph(clock: clock);
    final extracted = <_EntryExtraction>[];
    for (final item in _preparedEntries(entries)) {
      extracted.add((
        entry: item.entry,
        text: item.text,
        extraction: extractor.extract(
          text: item.text,
          localCaptureContext: item.entry.localCaptureContext,
        ),
      ));
    }
    return materializeTrajectories(_mergeExtractions(base, extracted));
  }

  Future<PersonalKnowledgeGraph> ingestAllAsync(
    Iterable<JournalEntry> entries, {
    PersonalKnowledgeGraph? into,
  }) async {
    final base = into ?? PersonalKnowledgeGraph(clock: clock);
    final asyncExtractor = extractor is AsyncGraphEntityExtractor
        ? extractor as AsyncGraphEntityExtractor
        : null;
    final extracted = <_EntryExtraction>[];
    for (final item in _preparedEntries(entries)) {
      final extraction = asyncExtractor == null
          ? extractor.extract(
              text: item.text,
              localCaptureContext: item.entry.localCaptureContext,
            )
          : await asyncExtractor.extractAsync(
              text: item.text,
              localCaptureContext: item.entry.localCaptureContext,
            );
      extracted.add((
        entry: item.entry,
        text: item.text,
        extraction: extraction,
      ));
    }
    return materializeTrajectories(_mergeExtractions(base, extracted));
  }

  PersonalKnowledgeGraph rebuild(Iterable<JournalEntry> entries) =>
      ingestAll(entries);

  Future<PersonalKnowledgeGraph> rebuildAsync(Iterable<JournalEntry> entries) =>
      ingestAllAsync(entries);

  PersonalKnowledgeGraph removeEntryEvidence(
    PersonalKnowledgeGraph graph,
    Set<String> entryIds,
  ) {
    if (entryIds.isEmpty) return graph;
    final nodes = graph.nodes
        .map(
          (node) => GraphNode(
            id: node.id,
            type: node.type,
            label: node.label,
            confidence: node.confidence,
            evidence: node.evidence.where(
              (item) => !entryIds.contains(item.entryId),
            ),
            origin: node.origin,
            createdAt: node.createdAt,
            archivedAt: node.archivedAt,
            theoryId: node.theoryId,
            externalSource: node.externalSource,
            tags: node.tags,
          ),
        )
        .where((node) => node.evidence.isNotEmpty)
        .toList();
    final nodeIds = nodes.map((node) => node.id).toSet();
    final edges = graph.edges
        .map(
          (edge) => GraphEdge(
            id: edge.id,
            sourceNodeId: edge.sourceNodeId,
            targetNodeId: edge.targetNodeId,
            type: edge.type,
            isDirected: edge.isDirected,
            weight: edge.weight,
            interactionDate: edge.interactionDate,
            emotionalValenceScore: edge.emotionalValenceScore,
            intensity: edge.intensity,
            evidence: edge.evidence.where(
              (item) => !entryIds.contains(item.entryId),
            ),
            origin: edge.origin,
            createdAt: edge.createdAt,
            archivedAt: edge.archivedAt,
            theoryId: edge.theoryId,
            externalSource: edge.externalSource,
          ),
        )
        .where(
          (edge) =>
              edge.evidence.isNotEmpty &&
              nodeIds.contains(edge.sourceNodeId) &&
              nodeIds.contains(edge.targetNodeId),
        )
        .toList();
    return materializeTrajectories(
      PersonalKnowledgeGraph(
        nodes: nodes,
        edges: edges,
        materialization: graph.materialization,
        clock: clock,
      ),
    );
  }

  PersonalKnowledgeGraph materializeTrajectories(
    PersonalKnowledgeGraph graph, {
    GraphMaterializationMetadata? metadata,
  }) {
    final trajectories = <GraphTrajectory>[];
    for (final node in graph.nodes) {
      final type = switch (node.type) {
        NodeType.belief => GraphTrajectoryType.beliefEvolution,
        NodeType.habit => GraphTrajectoryType.habitFrequency,
        NodeType.project => GraphTrajectoryType.projectProgress,
        _ => null,
      };
      if (type == null) continue;
      final ordered = node.evidence.toList()
        ..sort((a, b) => a.observedAt.compareTo(b.observedAt));
      trajectories.add(
        GraphTrajectory(
          type: type,
          subjectNodeId: node.id,
          windows: [
            for (var index = 0; index < ordered.length; index++)
              GraphTrajectoryWindow(
                id: stableGraphId('window', [
                  type.name,
                  node.id,
                  ordered[index].entryId,
                  ordered[index].startUtf16.toString(),
                ]),
                start: ordered[index].observedAt,
                end: ordered[index].observedAt,
                value: type == GraphTrajectoryType.habitFrequency
                    ? index + 1
                    : ordered[index].confidence,
                label: switch (type) {
                  GraphTrajectoryType.beliefEvolution => 'Belief evidence',
                  GraphTrajectoryType.habitFrequency => 'Habit occurrence',
                  GraphTrajectoryType.projectProgress => 'Project update',
                  _ => '',
                },
                evidence: [ordered[index]],
              ),
          ],
        ),
      );
    }
    final byId = {for (final node in graph.nodes) node.id: node};
    for (final edge in graph.edges) {
      final trajectoryType = switch (edge.type) {
        EdgeType.feltAbout => GraphTrajectoryType.relationshipSentiment,
        EdgeType.resultedIn => GraphTrajectoryType.decisionOutcome,
        _ => null,
      };
      if (trajectoryType == null) continue;
      final source = byId[edge.sourceNodeId];
      final target = byId[edge.targetNodeId];
      if (source == null || target == null) continue;
      trajectories.add(
        GraphTrajectory(
          type: trajectoryType,
          subjectNodeId: edge.sourceNodeId,
          relatedNodeId: edge.targetNodeId,
          windows: edge.evidence.map(
            (evidence) => GraphTrajectoryWindow(
              id: stableGraphId('window', [
                trajectoryType.name,
                edge.id,
                evidence.entryId,
                evidence.startUtf16.toString(),
              ]),
              start: evidence.observedAt,
              end: evidence.observedAt,
              value: trajectoryType == GraphTrajectoryType.relationshipSentiment
                  ? _sentimentFor('${source.label} ${evidence.excerpt}')
                  : evidence.confidence,
              label: trajectoryType == GraphTrajectoryType.relationshipSentiment
                  ? '${source.label} felt about ${target.label}'
                  : '${source.label} resulted in ${target.label}',
              evidence: [
                GraphTrajectoryEvidence(
                  entryId: evidence.entryId,
                  observedAt: evidence.observedAt,
                  confidence: evidence.confidence,
                  excerpt: evidence.excerpt,
                  startUtf16: evidence.startUtf16,
                  endUtf16: evidence.endUtf16,
                ),
              ],
            ),
          ),
        ),
      );
    }
    trajectories.sort((a, b) => a.id.compareTo(b.id));
    return PersonalKnowledgeGraph(
      nodes: graph.nodes,
      edges: graph.edges,
      trajectories: trajectories,
      materialization: metadata ?? graph.materialization,
      clock: clock,
    );
  }

  PersonalKnowledgeGraph _mergeExtractions(
    PersonalKnowledgeGraph base,
    Iterable<_EntryExtraction> extracted,
  ) {
    final nodes = {for (final node in base.nodes) node.id: node};
    final edges = {for (final edge in base.edges) edge.id: edge};
    for (final item in extracted) {
      final entry = item.entry;
      final text = item.text;
      final extraction = item.extraction;
      final mentionNodeIds = <String>[];
      for (final mention in extraction.entities) {
        if (!mention.isExactSliceOf(text)) continue;
        final normalized = normalizeGraphLabel(mention.label);
        if (normalized.isEmpty) continue;
        final nodeId = stableGraphId('node', [mention.type.name, normalized]);
        final evidence = GraphNodeEvidence(
          entryId: entry.id,
          observedAt: entry.createdAt,
          confidence: mention.confidence,
          excerpt: mention.excerpt!,
          startUtf16: mention.startUtf16,
          endUtf16: mention.endUtf16,
        );
        final existing = nodes[nodeId];
        nodes[nodeId] = GraphNode(
          id: nodeId,
          type: mention.type,
          label: existing?.label ?? mention.label,
          confidence: existing == null
              ? mention.confidence
              : _max(existing.confidence, mention.confidence),
          evidence: [
            ...?existing?.evidence.where((item) => item.entryId != entry.id),
            evidence,
          ],
          origin: existing?.origin ?? NodeOrigin.extracted,
          createdAt: existing?.createdAt,
          archivedAt: existing?.archivedAt,
          theoryId: existing?.theoryId,
          externalSource: existing?.externalSource,
        );
        mentionNodeIds.add(nodeId);
      }

      final uniqueMentionIds = mentionNodeIds.toSet().toList()..sort();
      for (var i = 0; i < uniqueMentionIds.length; i++) {
        for (var j = i + 1; j < uniqueMentionIds.length; j++) {
          _mergeEdge(
            edges,
            sourceNodeId: uniqueMentionIds[i],
            targetNodeId: uniqueMentionIds[j],
            type: EdgeType.mentionedWith,
            isDirected: false,
            confidence: 0.55,
            entry: entry,
            excerpt: text,
            startUtf16: 0,
            endUtf16: text.length,
          );
        }
      }
      for (final relation in extraction.relations) {
        if (!relation.isExactSliceOf(text)) continue;
        final sourceId = stableGraphId('node', [
          relation.sourceType.name,
          normalizeGraphLabel(relation.sourceLabel),
        ]);
        final targetId = stableGraphId('node', [
          relation.targetType.name,
          normalizeGraphLabel(relation.targetLabel),
        ]);
        if (!nodes.containsKey(sourceId) || !nodes.containsKey(targetId)) {
          continue;
        }
        _mergeEdge(
          edges,
          sourceNodeId: sourceId,
          targetNodeId: targetId,
          type: relation.type,
          isDirected: relation.isDirected,
          confidence: relation.confidence,
          entry: entry,
          excerpt: relation.excerpt!,
          startUtf16: relation.startUtf16,
          endUtf16: relation.endUtf16,
          emotionalValenceScore: relation.type == EdgeType.evokedEmotion
              ? _emotionValence(relation.targetLabel)
              : null,
        );
      }
    }

    final sortedNodes = nodes.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final sortedEdges = edges.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return PersonalKnowledgeGraph(
      schemaVersion: 2,
      nodes: sortedNodes,
      edges: sortedEdges,
      materialization: base.materialization,
      clock: clock,
    );
  }

  static List<JournalEntry> _orderedEntries(Iterable<JournalEntry> entries) =>
      entries.toList()..sort((a, b) {
        final byTime = a.createdAt.compareTo(b.createdAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });

  static Iterable<_PreparedEntry> _preparedEntries(
    Iterable<JournalEntry> entries,
  ) sync* {
    for (final entry in _orderedEntries(entries)) {
      if (!_isEligible(entry)) continue;
      final text = ComparableEvidenceText.userText(entry).trim();
      if (text.isEmpty) continue;
      yield (entry: entry, text: text);
    }
  }

  static bool _isEligible(JournalEntry entry) =>
      !entry.isArchived &&
      !entry.keepSeparate &&
      !entry.treatAsNew &&
      entry.memorySurfacing != 'do_not_surface';

  static void _mergeEdge(
    Map<String, GraphEdge> edges, {
    required String sourceNodeId,
    required String targetNodeId,
    required EdgeType type,
    required bool isDirected,
    required num confidence,
    required JournalEntry entry,
    required String excerpt,
    required int startUtf16,
    required int endUtf16,
    num? emotionalValenceScore,
  }) {
    if (sourceNodeId == targetNodeId ||
        excerpt.isEmpty ||
        startUtf16 < 0 ||
        endUtf16 <= startUtf16 ||
        endUtf16 - startUtf16 != excerpt.length) {
      return;
    }
    final edgeId = stableGraphId('edge', [
      type.name,
      sourceNodeId,
      targetNodeId,
      isDirected.toString(),
    ]);
    final existing = edges[edgeId];
    final score = clampGraphScore(confidence);
    edges[edgeId] = GraphEdge(
      id: edgeId,
      sourceNodeId: sourceNodeId,
      targetNodeId: targetNodeId,
      type: type,
      isDirected: isDirected,
      weight: existing == null ? score : _max(existing.weight, score),
      interactionDate: entry.createdAt,
      emotionalValenceScore:
          emotionalValenceScore ?? existing?.emotionalValenceScore,
      intensity: existing == null
          ? score
          : _max(existing.intensity ?? 0, score),
      evidence: [
        ...?existing?.evidence.where((item) => item.entryId != entry.id),
        GraphEdgeEvidence(
          entryId: entry.id,
          observedAt: entry.createdAt,
          confidence: score,
          excerpt: excerpt,
          startUtf16: startUtf16,
          endUtf16: endUtf16,
        ),
      ],
      origin: existing?.origin ?? NodeOrigin.extracted,
      createdAt: existing?.createdAt,
      archivedAt: existing?.archivedAt,
      theoryId: existing?.theoryId,
      externalSource: existing?.externalSource,
    );
  }

  static double _max(double a, double b) => a > b ? a : b;

  static double _emotionValence(String label) {
    final normalized = normalizeGraphLabel(label);
    const positive = {
      'happy',
      'joyful',
      'calm',
      'excited',
      'grateful',
      'hopeful',
      'supported',
      'trusted',
    };
    const negative = {
      'sad',
      'angry',
      'afraid',
      'anxious',
      'worried',
      'overwhelmed',
      'lonely',
      'frustrated',
      'tense',
    };
    if (positive.any(normalized.contains)) return 1;
    if (negative.any(normalized.contains)) return -1;
    return 0;
  }

  static double _sentimentFor(String text) {
    final lower = text.toLowerCase();
    const positive = ['happy', 'grateful', 'love', 'proud', 'excited', 'calm'];
    const negative = ['angry', 'sad', 'afraid', 'anxious', 'upset', 'worried'];
    var score = 0;
    for (final word in positive) {
      if (lower.contains(word)) score++;
    }
    for (final word in negative) {
      if (lower.contains(word)) score--;
    }
    return (score / 2).clamp(-1.0, 1.0);
  }
}

class RuleBasedGraphEntityExtractor implements GraphEntityExtractor {
  const RuleBasedGraphEntityExtractor();

  static final List<({NodeType type, RegExp expression, double confidence})>
  _rules = [
    (
      type: NodeType.goal,
      expression: RegExp(
        r'\b(?:my goal is|i want to|i plan to|i hope to)\s+([^.!?;\n]+)',
        caseSensitive: false,
      ),
      confidence: 0.82,
    ),
    (
      type: NodeType.fear,
      expression: RegExp(
        r'\b(?:i am afraid of|i fear|i am worried about|i worry about)\s+([^.!?;\n]+)',
        caseSensitive: false,
      ),
      confidence: 0.84,
    ),
    (
      type: NodeType.habit,
      expression: RegExp(
        r'\b(?:i usually|every day i|each day i|my habit is|i keep)\s+([^.!?;\n]+)',
        caseSensitive: false,
      ),
      confidence: 0.72,
    ),
    (
      type: NodeType.belief,
      expression: RegExp(
        r'\b(?:i believe(?: that)?|i think that|my belief is)\s+([^.!?;\n]+)',
        caseSensitive: false,
      ),
      confidence: 0.78,
    ),
    (
      type: NodeType.decision,
      expression: RegExp(
        r'\b(?:i decided to|i have decided to|my decision is to|we decided to)\s+([^.!?;\n]+?)(?=\s+(?:and\s+)?(?:it|this)\s+resulted in|[.!?;\n]|$)',
        caseSensitive: false,
      ),
      confidence: 0.92,
    ),
    (
      type: NodeType.outcome,
      expression: RegExp(
        r'\b(?:the outcome was|this resulted in|it resulted in|the result was)\s+([^.!?;\n]+)',
        caseSensitive: false,
      ),
      confidence: 0.9,
    ),
    (
      type: NodeType.project,
      expression: RegExp(
        r'\b(?:project|working on|started|launched)\s+["“]?([A-Z][A-Za-z0-9_-]*(?:\s+[A-Z][A-Za-z0-9_-]*){0,4})["”]?',
      ),
      confidence: 0.88,
    ),
    (
      type: NodeType.emotion,
      expression: RegExp(
        r'\b(?:i feel|i felt|i am feeling|i was feeling)\s+(happy|sad|angry|anxious|afraid|excited|grateful|proud|calm|upset|worried|relieved)\b',
        caseSensitive: false,
      ),
      confidence: 0.94,
    ),
    (
      type: NodeType.memory,
      expression: RegExp(
        r'\b(?:i remember|a memory of|my memory of)\s+([^.!?;\n]+)',
        caseSensitive: false,
      ),
      confidence: 0.88,
    ),
    (
      type: NodeType.chapter,
      expression: RegExp(
        r'\b(?:this chapter is|a new chapter of|this phase is|this season of)\s+([^.!?;\n]+)',
        caseSensitive: false,
      ),
      confidence: 0.76,
    ),
    (
      type: NodeType.event,
      expression: RegExp(
        r'\b(?:the|my|our)\s+((?:meeting|wedding|conference|trip|birthday|appointment)(?:\s+[^.!?;\n]+)?)',
        caseSensitive: false,
      ),
      confidence: 0.68,
    ),
    (
      type: NodeType.place,
      expression: RegExp(
        r'\b(?:at|in|near)\s+([A-Z][A-Za-z0-9]*(?:\s+[A-Z][A-Za-z0-9]*){0,3})',
      ),
      confidence: 0.66,
    ),
    (
      type: NodeType.person,
      expression: RegExp(
        r'\b(?:i feel|i felt|i am feeling|i was feeling)\s+(?:happy|sad|angry|anxious|afraid|excited|grateful|proud|calm|upset|worried|relieved)\s+about\s+([A-Z][A-Za-z]*(?:\s+[A-Z][A-Za-z]*){0,2})',
      ),
      confidence: 0.86,
    ),
    (
      type: NodeType.person,
      expression: RegExp(
        r'\b(?:with|met|called|spoke to|talked to)\s+([A-Z][A-Za-z]*(?:\s+[A-Z][A-Za-z]*){0,2})',
      ),
      confidence: 0.7,
    ),
  ];

  @override
  GraphExtraction extract({
    required String text,
    LocalCaptureContext? localCaptureContext,
  }) {
    final entities = <GraphEntityMention>[];
    for (final rule in _rules) {
      for (final match in rule.expression.allMatches(text)) {
        final label = _cleanLabel(match.group(1) ?? '');
        if (label.isEmpty) continue;
        entities.add(
          GraphEntityMention(
            type: rule.type,
            label: label,
            confidence: rule.confidence,
            excerpt: match.group(0),
            startUtf16: match.start,
            endUtf16: match.end,
          ),
        );
      }
    }

    final location = localCaptureContext?.locationLabel?.trim();
    if (location?.isNotEmpty == true) {
      entities.add(
        GraphEntityMention(
          type: NodeType.place,
          label: location!,
          confidence: 0.95,
          excerpt: 'Local capture context: $location',
        ),
      );
    }
    final event = localCaptureContext?.calendarEventName?.trim();
    if (event?.isNotEmpty == true) {
      entities.add(
        GraphEntityMention(
          type: NodeType.event,
          label: event!,
          confidence: 0.95,
          excerpt: 'Local capture context: $event',
        ),
      );
    }

    final deduplicated = <String, GraphEntityMention>{};
    for (final entity in entities) {
      final key = '${entity.type.name}:${normalizeGraphLabel(entity.label)}';
      final current = deduplicated[key];
      if (current == null || entity.confidence > current.confidence) {
        deduplicated[key] = entity;
      }
    }
    final result = deduplicated.values.toList();
    final relations = _semanticRelations(text, result);
    return GraphExtraction(entities: result, relations: relations);
  }

  static List<GraphRelationMention> _semanticRelations(
    String text,
    List<GraphEntityMention> entities,
  ) {
    final lower = text.toLowerCase();
    final relations = <GraphRelationMention>[];
    for (final source in entities) {
      for (final target in entities) {
        if (identical(source, target)) continue;
        final sourceIndex = lower.indexOf(source.label.toLowerCase());
        final targetIndex = lower.indexOf(target.label.toLowerCase());
        if (sourceIndex < 0 || targetIndex <= sourceIndex) continue;
        final between = lower.substring(
          sourceIndex + source.label.length,
          targetIndex,
        );
        final semantic =
            source.type == NodeType.emotion &&
                RegExp(r'\babout\b').hasMatch(between)
            ? (type: EdgeType.feltAbout, directed: true, confidence: 0.92)
            : _edgeForConnector(between);
        if (semantic == null) continue;
        relations.add(
          GraphRelationMention(
            sourceType: source.type,
            sourceLabel: source.label,
            targetType: target.type,
            targetLabel: target.label,
            type: semantic.type,
            isDirected: semantic.directed,
            confidence: semantic.confidence,
            excerpt: text,
            startUtf16: 0,
            endUtf16: text.length,
          ),
        );
      }
    }
    return relations;
  }

  static ({EdgeType type, bool directed, double confidence})? _edgeForConnector(
    String connector,
  ) {
    if (RegExp(r'\btriggered by\b').hasMatch(connector)) {
      return (type: EdgeType.triggeredBy, directed: true, confidence: 0.82);
    }
    if (RegExp(r'\bevolved into\b').hasMatch(connector)) {
      return (type: EdgeType.evolvedInto, directed: true, confidence: 0.88);
    }
    if (RegExp(r'\binfluences?\b').hasMatch(connector)) {
      return (type: EdgeType.influences, directed: true, confidence: 0.78);
    }
    if (RegExp(r'\bassociated with\b').hasMatch(connector)) {
      return (type: EdgeType.associatedWith, directed: false, confidence: 0.72);
    }
    if (RegExp(r'\bdecided (?:on|to)\b').hasMatch(connector)) {
      return (type: EdgeType.decidedOn, directed: true, confidence: 0.9);
    }
    if (RegExp(r'\bresulted in\b').hasMatch(connector)) {
      return (type: EdgeType.resultedIn, directed: true, confidence: 0.92);
    }
    if (RegExp(r'\b(?:felt|feel|feels) .*?\babout\b').hasMatch(connector)) {
      return (type: EdgeType.feltAbout, directed: true, confidence: 0.9);
    }
    if (RegExp(r'\bpart of\b').hasMatch(connector)) {
      return (type: EdgeType.partOf, directed: true, confidence: 0.88);
    }
    if (RegExp(r'\bsupports? (?:my |the )?belief\b').hasMatch(connector)) {
      return (type: EdgeType.supportsBelief, directed: true, confidence: 0.9);
    }
    if (RegExp(r'\bcontradicts? (?:my |the )?belief\b').hasMatch(connector)) {
      return (
        type: EdgeType.contradictsBelief,
        directed: true,
        confidence: 0.9,
      );
    }
    return null;
  }

  static String _cleanLabel(String value) {
    final words = value.trim().replaceAll(RegExp(r'\s+'), ' ').split(' ');
    final limited = words.take(12).join(' ');
    return limited.replaceFirst(
      RegExp(r'\s+(?:and|but|because|when|while)$', caseSensitive: false),
      '',
    );
  }
}
