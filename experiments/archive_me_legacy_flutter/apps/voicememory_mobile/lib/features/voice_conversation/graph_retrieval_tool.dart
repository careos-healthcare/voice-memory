import 'dart:convert';

import '../../core/graph/graph_node.dart';
import '../../core/graph/personal_knowledge_graph.dart';
import '../../core/search/local_vector_search_engine.dart';
import '../../services/ai/local_semantic_store.dart';

typedef ConversationGraphLoader = Future<PersonalKnowledgeGraph> Function();

abstract interface class MemoryGraphQueryTool {
  Future<String> executeJson(Map<String, dynamic> arguments);
}

class GraphRetrievalTool implements MemoryGraphQueryTool {
  const GraphRetrievalTool({
    required this.semanticStore,
    required this.loadGraph,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final LocalSemanticStore semanticStore;
  final ConversationGraphLoader loadGraph;
  final DateTime Function() _clock;

  Future<Map<String, dynamic>> query({
    required String topic,
    String? timeframe,
    int limit = 8,
  }) async {
    final constrained = await semanticStore.applyGraphConstraints(
      await loadGraph(),
    );
    final window = _resolveWindow(timeframe);
    final localSemanticHits = await semanticStore.search(
      topic,
      limit: limit * 2,
    );
    final semanticNodeIds = localSemanticHits
        .expand((hit) => hit.nodeIds)
        .toSet();
    final vector = LocalVectorSearchEngine(graph: constrained);
    final vectorHits = vector.search(topic, limit: limit * 2);
    vector.dispose();

    final rankedIds = <String>[];
    for (final hit in vectorHits) {
      if (!rankedIds.contains(hit.node.id)) rankedIds.add(hit.node.id);
    }
    for (final id in semanticNodeIds) {
      if (!rankedIds.contains(id)) rankedIds.add(id);
    }
    final byId = {for (final node in constrained.nodes) node.id: node};
    final seeds = rankedIds
        .map((id) => byId[id])
        .whereType<GraphNode>()
        .where((node) => _nodeInWindow(node, window))
        .take(limit)
        .toList();

    final includedIds = <String>{...seeds.map((node) => node.id)};
    for (final seed in seeds.take(4)) {
      includedIds.addAll(
        constrained
            .getConnectedNodes(seed.id)
            .where((node) => _nodeInWindow(node, window))
            .take(3)
            .map((node) => node.id),
      );
    }
    final nodes = includedIds
        .map((id) => byId[id])
        .whereType<GraphNode>()
        .take(limit + 6)
        .toList();
    final edges = constrained.edges
        .where(
          (edge) =>
              includedIds.contains(edge.sourceNodeId) &&
              includedIds.contains(edge.targetNodeId) &&
              _edgeInWindow(edge, window),
        )
        .take(20)
        .toList();

    return {
      'topic': topic.trim(),
      'timeframe': {
        'start': window.start?.toIso8601String(),
        'end': window.end.toIso8601String(),
      },
      'nodes': [
        for (final node in nodes)
          {
            'id': node.id,
            'type': node.type.name,
            'label': node.label,
            'confidence': node.confidence,
            'origin': node.origin.wireName,
            'evidence': [
              for (final item
                  in node.evidence
                      .where((item) => window.includes(item.observedAt))
                      .take(2))
                {
                  'sourceEntryId': item.entryId,
                  'observedAt': item.observedAt.toIso8601String(),
                  'exactQuote': _bounded(item.excerpt, 240),
                  'confidence': item.confidence,
                },
            ],
          },
      ],
      'edges': [
        for (final edge in edges)
          {
            'sourceNodeId': edge.sourceNodeId,
            'targetNodeId': edge.targetNodeId,
            'relation': edge.type.name,
            'weight': edge.weight,
          },
      ],
      'resultCount': nodes.length,
      'privacy':
          'Retrieved locally from the decrypted vault for this ephemeral session.',
    };
  }

  @override
  Future<String> executeJson(Map<String, dynamic> arguments) async =>
      jsonEncode(
        await query(
          topic: arguments['topic'] as String? ?? '',
          timeframe: arguments['timeframe'] as String?,
        ),
      );

  _RetrievalWindow _resolveWindow(String? value) {
    final end = _clock().toUtc();
    final normalized = value?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty || normalized == 'all time') {
      return _RetrievalWindow(start: null, end: end);
    }
    final days = RegExp(
      r'(?:last|past)\s+(\d+)\s+days?',
    ).firstMatch(normalized);
    if (days != null) {
      final count = int.tryParse(days.group(1) ?? '')?.clamp(1, 3650) ?? 90;
      return _RetrievalWindow(
        start: end.subtract(Duration(days: count)),
        end: end,
      );
    }
    if (normalized.contains('this month')) {
      return _RetrievalWindow(
        start: DateTime.utc(end.year, end.month),
        end: end,
      );
    }
    if (normalized.contains('this year')) {
      return _RetrievalWindow(start: DateTime.utc(end.year), end: end);
    }
    return _RetrievalWindow(
      start: end.subtract(const Duration(days: 90)),
      end: end,
    );
  }

  bool _nodeInWindow(GraphNode node, _RetrievalWindow window) =>
      node.evidence.any((item) => window.includes(item.observedAt));

  bool _edgeInWindow(GraphEdge edge, _RetrievalWindow window) =>
      edge.evidence.any((item) => window.includes(item.observedAt));
}

class _RetrievalWindow {
  const _RetrievalWindow({required this.start, required this.end});

  final DateTime? start;
  final DateTime end;

  bool includes(DateTime value) {
    final utc = value.toUtc();
    return !utc.isAfter(end) && (start == null || !utc.isBefore(start!));
  }
}

String _bounded(String value, int maximum) =>
    value.length <= maximum ? value : '${value.substring(0, maximum - 1)}…';
