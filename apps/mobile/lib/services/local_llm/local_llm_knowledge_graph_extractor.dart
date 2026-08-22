import 'dart:convert';

import 'package:archiveme_mobile/features/reflections/data/offline_reflection_knowledge_graph.dart';

/// Structured graph update payload extracted from local LLM JSON output.
final class LocalLlmGraphUpdate {
  const LocalLlmGraphUpdate({
    required this.entryId,
    required this.nodes,
    required this.edges,
    this.tensionOrContradiction,
    this.nextSmallAction,
    this.recurringThemes = const [],
  });

  final String entryId;
  final List<ReflectionGraphNode> nodes;
  final List<ReflectionGraphEdge> edges;
  final String? tensionOrContradiction;
  final String? nextSmallAction;
  final List<String> recurringThemes;

  OfflineReflectionKnowledgeGraph toKnowledgeGraph() {
    if (nodes.isNotEmpty || edges.isNotEmpty) {
      return OfflineReflectionKnowledgeGraph(
        entryId: entryId,
        nodes: nodes,
        edges: edges,
        tensionOrContradiction: tensionOrContradiction,
        nextSmallAction: nextSmallAction,
      );
    }

    return OfflineReflectionKnowledgeGraph.fromReflectionFields(
      entryId: entryId,
      tensionOrContradiction: tensionOrContradiction,
      nextSmallAction: nextSmallAction,
      recurringThemes: recurringThemes,
    );
  }
}

/// Prompt + JSON parsing helpers for knowledge graph maintenance.
abstract final class LocalLlmKnowledgeGraphExtractor {
  LocalLlmKnowledgeGraphExtractor._();

  static const schemaName = 'knowledge_graph_update';

  static String buildPrompt({
    required String entryId,
    required String transcript,
    List<String> existingThemes = const [],
  }) {
    final themeHint = existingThemes.isEmpty
        ? 'none'
        : existingThemes.join(', ');
    return '''
You extract a reflection knowledge graph update for one journal entry.
Respond with JSON only — no markdown fences or commentary.

Schema "$schemaName":
{
  "entryId": "$entryId",
  "tensionOrContradiction": "string or null",
  "nextSmallAction": "string or null",
  "recurringThemes": ["string"],
  "nodes": [
    {"id": "entry:$entryId", "kind": "journal_entry", "label": "$entryId"},
    {"id": "theme:example:$entryId", "kind": "theme", "label": "example"}
  ],
  "edges": [
    {"from": "entry:$entryId", "to": "theme:example:$entryId", "relation": "mentions_theme", "weight": 0.8}
  ]
}

Allowed node kinds: journal_entry, tension, next_action, theme.
Allowed relations: has_tension, suggests_action, mentions_theme.
Existing themes: $themeHint

Transcript:
$transcript
'''.trim();
  }

  static LocalLlmGraphUpdate parseGraphJson({
    required String entryId,
    required String rawCompletion,
  }) {
    final decoded = _decodeJsonObject(rawCompletion);
    final resolvedEntryId =
        (decoded['entryId'] as String?)?.trim().isNotEmpty == true
        ? decoded['entryId'] as String
        : entryId;

    final nodes = _parseNodes(decoded['nodes'], fallbackEntryId: resolvedEntryId);
    final edges = _parseEdges(decoded['edges']);
    final themes = _parseStringList(decoded['recurringThemes']);

    return LocalLlmGraphUpdate(
      entryId: resolvedEntryId,
      nodes: nodes,
      edges: edges,
      tensionOrContradiction: _nullableString(
        decoded['tensionOrContradiction'],
      ),
      nextSmallAction: _nullableString(decoded['nextSmallAction']),
      recurringThemes: themes,
    );
  }

  static Map<String, dynamic> _decodeJsonObject(String rawCompletion) {
    final trimmed = rawCompletion.trim();
    if (trimmed.isEmpty) {
      throw FormatException('Knowledge graph completion was empty.');
    }

    final candidates = <String>[
      trimmed,
      _extractJsonFence(trimmed) ?? '',
      _extractFirstJsonObject(trimmed) ?? '',
    ].where((candidate) => candidate.isNotEmpty);

    Object? lastError;
    for (final candidate in candidates) {
      try {
        final decoded = jsonDecode(candidate);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } on Object catch (error, stackTrace) {
        lastError = error;
      }
    }

    throw FormatException(
      'Could not parse knowledge graph JSON: $lastError',
    );
  }

  static String? _extractJsonFence(String value) {
    final match = RegExp(
      r'```(?:json)?\s*([\s\S]*?)```',
      multiLine: true,
    ).firstMatch(value);
    return match?.group(1)?.trim();
  }

  static String? _extractFirstJsonObject(String value) {
    final start = value.indexOf('{');
    final end = value.lastIndexOf('}');
    if (start == -1 || end <= start) {
      return null;
    }
    return value.substring(start, end + 1);
  }

  static List<ReflectionGraphNode> _parseNodes(
    Object? rawNodes, {
    required String fallbackEntryId,
  }) {
    if (rawNodes is! List) {
      return [
        ReflectionGraphNode(
          id: 'entry:$fallbackEntryId',
          kind: 'journal_entry',
          label: fallbackEntryId,
        ),
      ];
    }

    final nodes = <ReflectionGraphNode>[];
    for (final item in rawNodes) {
      if (item is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(item);
      final id = (map['id'] as String?)?.trim();
      final kind = (map['kind'] as String?)?.trim();
      final label = (map['label'] as String?)?.trim();
      if (id == null || id.isEmpty || kind == null || kind.isEmpty) {
        continue;
      }
      final payload = map['payload'];
      nodes.add(
        ReflectionGraphNode(
          id: id,
          kind: kind,
          label: label == null || label.isEmpty ? id : label,
          payload: payload is Map
              ? Map<String, dynamic>.from(payload)
              : const {},
        ),
      );
    }

    if (nodes.any((node) => node.id == 'entry:$fallbackEntryId')) {
      return nodes;
    }

    return [
      ReflectionGraphNode(
        id: 'entry:$fallbackEntryId',
        kind: 'journal_entry',
        label: fallbackEntryId,
      ),
      ...nodes,
    ];
  }

  static List<ReflectionGraphEdge> _parseEdges(Object? rawEdges) {
    if (rawEdges is! List) {
      return const [];
    }

    final edges = <ReflectionGraphEdge>[];
    for (final item in rawEdges) {
      if (item is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(item);
      final from = (map['from'] as String?)?.trim();
      final to = (map['to'] as String?)?.trim();
      final relation = (map['relation'] as String?)?.trim();
      if (from == null ||
          from.isEmpty ||
          to == null ||
          to.isEmpty ||
          relation == null ||
          relation.isEmpty) {
        continue;
      }
      edges.add(
        ReflectionGraphEdge(
          fromNodeId: from,
          toNodeId: to,
          relation: relation,
          weight: (map['weight'] as num?)?.toDouble() ?? 1,
        ),
      );
    }
    return edges;
  }

  static List<String> _parseStringList(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    return raw
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  static String? _nullableString(Object? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.toString().trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') {
      return null;
    }
    return trimmed;
  }
}