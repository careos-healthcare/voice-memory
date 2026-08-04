import 'dart:typed_data';

import '../../core/graph/graph_node.dart';
import '../../core/graph/personal_knowledge_graph.dart';
import '../../core/graph/personal_knowledge_graph_store.dart';
import '../../core/llm/on_device_extractor.dart';
import '../../core/llm/native/llama_inference_session.dart';
import '../../core/llm/semantic_extraction_result.dart';
import '../../core/search/local_vector_search_engine.dart';
import '../../services/ai/local_semantic_store.dart';
import '../../services/ai/sqlite_vec_vector_store.dart';
import '../data_ingestion/legacy_ingestion_store.dart';
import 'autonomous_muse_models.dart';
import 'autonomous_muse_store.dart';
import 'bridge_confidence_engine.dart';

abstract interface class LegacyEntityAnalyzer {
  Future<List<String>> extract(String text);
}

final class OnDeviceLegacyEntityAnalyzer implements LegacyEntityAnalyzer {
  const OnDeviceLegacyEntityAnalyzer({
    this.sessionProvider,
    this.maximumInputCharacters = 12000,
  });

  final Future<LlamaInferenceSession?> Function()? sessionProvider;
  final int maximumInputCharacters;

  @override
  Future<List<String>> extract(String text) async {
    final bounded = text.length <= maximumInputCharacters
        ? text
        : text.substring(0, maximumInputCharacters);
    final session = await sessionProvider?.call();
    final extraction = await OnDeviceSemanticExtractor(
      asyncSession: session == null ? null : _LlamaSemanticSession(session),
    ).extractSemanticAsync(text: bounded);
    const retainedTypes = {
      SemanticEntityType.person,
      SemanticEntityType.project,
      SemanticEntityType.event,
      SemanticEntityType.goal,
      SemanticEntityType.belief,
      SemanticEntityType.decision,
    };
    return extraction.entities
        .where(
          (entity) =>
              retainedTypes.contains(entity.type) && entity.confidence >= .5,
        )
        .map((entity) => entity.label.trim())
        .where((label) => label.isNotEmpty)
        .toSet()
        .take(12)
        .toList(growable: false);
  }
}

abstract interface class LegacyBridgeRationaleGenerator {
  Future<LegacyBridgeRationale> generate({
    required LegacySweepNote source,
    required GraphNode target,
    required List<String> entities,
  });
}

final class LegacyBridgeRationale {
  const LegacyBridgeRationale({required this.text, required this.confidence});

  final String text;
  final double confidence;
}

typedef LegacyRawCompletion = Future<String> Function(String prompt);

final class LocalLegacyBridgeRationaleGenerator
    implements LegacyBridgeRationaleGenerator {
  const LocalLegacyBridgeRationaleGenerator({this.complete});

  final LegacyRawCompletion? complete;

  @override
  Future<LegacyBridgeRationale> generate({
    required LegacySweepNote source,
    required GraphNode target,
    required List<String> entities,
  }) async {
    final entityText = entities.take(6).join(', ');
    final fallback = entityText.isEmpty
        ? 'Both memories share strongly similar local semantic patterns.'
        : 'Both memories discuss $entityText.';
    final completion = complete;
    if (completion == null) {
      return LegacyBridgeRationale(text: fallback, confidence: .78);
    }
    final excerpt = source.markdown.length <= 1500
        ? source.markdown
        : source.markdown.substring(0, 1500);
    try {
      final value = await completion(
        'In one short sentence explain why the note "${source.title}" and '
        '"${target.label}" may be related. Mention only evidence present in '
        'this local note. Entities: $entityText\n\n$excerpt',
      );
      final clean = value.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (clean.isEmpty) {
        return LegacyBridgeRationale(text: fallback, confidence: .72);
      }
      return LegacyBridgeRationale(
        text: clean.length <= 240 ? clean : '${clean.substring(0, 237)}...',
        confidence: .92,
      );
    } on Object {
      return LegacyBridgeRationale(text: fallback, confidence: .72);
    }
  }
}

abstract interface class LegacyBridgeBuilding {
  Future<List<LegacyBridgeSuggestion>> build(LegacySweepNote note);
  Future<void> accept(String suggestionId);
  void reject(String suggestionId);
  void defer(String suggestionId, DateTime until);
}

final class SemanticBridgeBuilder implements LegacyBridgeBuilding {
  static const similarityEpsilon = 1e-7;

  SemanticBridgeBuilder({
    required this.legacyStore,
    required this.museStore,
    required this.graphStore,
    required this.semanticStore,
    required this.embeddingDriver,
    required this.entityAnalyzer,
    required this.rationaleGenerator,
    this.confidenceEngine = const BridgeConfidenceEngine(),
    DateTime Function()? clock,
    this.minimumSimilarity = .75,
    this.maximumSuggestionsPerNote = 3,
  }) : _clock = clock ?? DateTime.now;

  final LegacyIngestionStore legacyStore;
  final AutonomousMuseStore museStore;
  final PersonalKnowledgeGraphStore graphStore;
  final LocalSemanticStore semanticStore;
  final LocalEmbeddingDriver embeddingDriver;
  final LegacyEntityAnalyzer entityAnalyzer;
  final LegacyBridgeRationaleGenerator rationaleGenerator;
  final BridgeConfidenceEngine confidenceEngine;
  final double minimumSimilarity;
  final int maximumSuggestionsPerNote;
  final DateTime Function() _clock;

  static bool isAboveSimilarityThreshold(
    double value, {
    double threshold = .85,
  }) => value - threshold > similarityEpsilon;

  bool qualifiesSimilarity(double value) =>
      value + similarityEpsilon >= minimumSimilarity;

  @override
  Future<List<LegacyBridgeSuggestion>> build(LegacySweepNote note) async {
    final graph = await graphStore.load();
    final nodes = {for (final node in graph.nodes) node.id: node};
    final connected = <String>{
      for (final edge in graph.edges)
        _pair(edge.sourceNodeId, edge.targetNodeId),
    };
    final vector = embeddingDriver.embed(note.markdown);
    _upsertDigestVector(note, vector);

    final scores = <String, double>{};
    if (legacyStore.vectorStore.isAccelerated) {
      for (final hit in legacyStore.vectorStore.search(vector, limit: 64)) {
        for (final nodeId in hit.nodeIds) {
          scores.update(
            nodeId,
            (score) =>
                score > hit.cosineSimilarity ? score : hit.cosineSimilarity,
            ifAbsent: () => hit.cosineSimilarity,
          );
        }
      }
    }
    for (final hit in await semanticStore.searchVector(vector, limit: 64)) {
      for (final nodeId in hit.nodeIds) {
        scores.update(
          nodeId,
          (score) => score > hit.score ? score : hit.score,
          ifAbsent: () => hit.score,
        );
      }
    }

    final candidates =
        scores.entries
            .where(
              (candidate) =>
                  candidate.key != note.id &&
                  qualifiesSimilarity(candidate.value) &&
                  nodes.containsKey(candidate.key) &&
                  !connected.contains(_pair(note.id, candidate.key)) &&
                  !museStore.hasLegacySuggestionPair(note.id, candidate.key),
            )
            .toList()
          ..sort((left, right) => right.value.compareTo(left.value));
    final entities = await entityAnalyzer.extract(note.markdown);
    final sourceExcerpt = note.markdown.length <= 240
        ? note.markdown
        : note.markdown.substring(0, 240);
    final suggestions = <LegacyBridgeSuggestion>[];
    for (final candidate in candidates.take(maximumSuggestionsPerNote)) {
      final target = nodes[candidate.key]!;
      final rationale = await rationaleGenerator.generate(
        source: note,
        target: target,
        entities: entities,
      );
      final suggestion = LegacyBridgeSuggestion(
        id: stableGraphId('legacy-muse-suggestion', [
          _pair(note.id, target.id),
        ]),
        sourceNodeId: note.id,
        targetNodeId: target.id,
        sourceLabel: note.title,
        targetLabel: target.label,
        entities: entities,
        confidenceScore: candidate.value,
        rationale: rationale.text,
        sourceExcerpt: sourceExcerpt,
        targetExcerpt: target.evidence.firstOrNull?.excerpt ?? target.label,
        rationaleConfidence: rationale.confidence,
        createdAt: _clock(),
      );
      final decision = confidenceEngine.categorize(suggestion);
      if (decision.band == BridgeConfidenceBand.discarded) continue;
      if (decision.autoLink) {
        final automatic = LegacyBridgeSuggestion(
          id: suggestion.id,
          sourceNodeId: suggestion.sourceNodeId,
          targetNodeId: suggestion.targetNodeId,
          sourceLabel: suggestion.sourceLabel,
          targetLabel: suggestion.targetLabel,
          entities: suggestion.entities,
          confidenceScore: suggestion.confidenceScore,
          rationale: suggestion.rationale,
          sourceExcerpt: suggestion.sourceExcerpt,
          targetExcerpt: suggestion.targetExcerpt,
          rationaleConfidence: suggestion.rationaleConfidence,
          tags: {...suggestion.tags, 'muse_auto'},
          createdAt: suggestion.createdAt,
        );
        museStore.upsertLegacySuggestion(automatic);
        await _materialize(automatic, LegacyBridgeSuggestionStatus.autoLinked);
        suggestions.add(automatic);
      } else {
        museStore.upsertLegacySuggestion(suggestion);
        suggestions.add(suggestion);
      }
    }
    return List.unmodifiable(suggestions);
  }

  @override
  Future<void> accept(String suggestionId) async {
    final suggestion = museStore.legacySuggestion(suggestionId);
    if (suggestion == null ||
        suggestion.status != LegacyBridgeSuggestionStatus.pending) {
      return;
    }
    await _materialize(suggestion, LegacyBridgeSuggestionStatus.accepted);
  }

  Future<void> _materialize(
    LegacyBridgeSuggestion suggestion,
    LegacyBridgeSuggestionStatus resolvedStatus,
  ) async {
    await graphStore.update((graph) {
      if (graph.edges.any((edge) => edge.id == suggestion.id)) return graph;
      return PersonalKnowledgeGraph(
        schemaVersion: graph.schemaVersion,
        nodes: graph.nodes,
        edges: [
          ...graph.edges,
          GraphEdge(
            id: suggestion.id,
            sourceNodeId: suggestion.sourceNodeId,
            targetNodeId: suggestion.targetNodeId,
            type: EdgeType.associatedWith,
            isDirected: false,
            weight: suggestion.confidenceScore,
            origin: NodeOrigin.autonomousMuse,
            createdAt: suggestion.createdAt,
            evidence: suggestion.sourceExcerpt.isEmpty
                ? const []
                : [
                    GraphEdgeEvidence(
                      entryId: suggestion.sourceNodeId,
                      observedAt: suggestion.createdAt,
                      confidence: suggestion.confidenceScore,
                      excerpt: suggestion.sourceExcerpt,
                      startUtf16: 0,
                      endUtf16: suggestion.sourceExcerpt.length,
                    ),
                  ],
          ),
        ],
        trajectories: graph.trajectories,
        materialization: graph.materialization,
        clock: graph.clock,
      );
    });
    museStore.upsertLegacySuggestion(
      suggestion.resolve(resolvedStatus, _clock()),
    );
  }

  @override
  void reject(String suggestionId) {
    final suggestion = museStore.legacySuggestion(suggestionId);
    if (suggestion == null ||
        suggestion.status != LegacyBridgeSuggestionStatus.pending) {
      return;
    }
    museStore.upsertLegacySuggestion(
      suggestion.resolve(LegacyBridgeSuggestionStatus.rejected, _clock()),
    );
  }

  @override
  void defer(String suggestionId, DateTime until) {
    final suggestion = museStore.legacySuggestion(suggestionId);
    if (suggestion == null ||
        suggestion.status != LegacyBridgeSuggestionStatus.pending) {
      return;
    }
    museStore.upsertLegacySuggestion(suggestion.deferUntil(until));
  }

  void _upsertDigestVector(LegacySweepNote note, Float32List vector) {
    if (!legacyStore.vectorStore.isAccelerated) return;
    legacyStore.vectorStore.upsertAll([
      SqliteVecRecord(
        entryId: '${note.id}:digest',
        embedding: vector,
        clusterType: 'legacy_digest',
        updatedAt: _clock(),
        confidence: 1,
        nodeIds: [note.id],
        tags: {...note.tags, 'legacy-digest'},
      ),
    ]);
  }
}

String _pair(String left, String right) =>
    left.compareTo(right) <= 0 ? '$left::$right' : '$right::$left';

final class _LlamaSemanticSession implements AsyncSemanticInferenceSession {
  const _LlamaSemanticSession(this.session);

  final LlamaInferenceSession session;

  @override
  bool get isReady => session.isReady;

  @override
  Future<SemanticExtractionResult> infer(String text) => session.infer(text);
}
