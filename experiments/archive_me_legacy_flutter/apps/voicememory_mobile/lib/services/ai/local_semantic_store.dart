import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../core/graph/graph_node.dart';
import '../../core/graph/personal_knowledge_graph.dart';
import '../../core/search/local_vector_search_engine.dart';
import '../../features/ai_engines/on_device_extraction_engine.dart';
import '../../features/ai_engines/models/hypothesis_evolution.dart';
import '../../features/archive_evidence/comparable_evidence_text.dart';
import '../../models/journal_entry.dart';
import '../../storage/encrypted_json_file_store.dart';
import 'sqlite_vec_vector_store.dart';

final class AggregatedNodeVector {
  AggregatedNodeVector({
    required this.nodeId,
    required Iterable<double> vector,
    required this.sampleCount,
    required DateTime updatedAt,
  }) : vector = List<double>.unmodifiable(vector),
       updatedAt = updatedAt.toUtc();

  final String nodeId;
  final List<double> vector;
  final int sampleCount;
  final DateTime updatedAt;
}

class LocalSemanticHit {
  const LocalSemanticHit({
    required this.entryId,
    required this.score,
    required this.nodeIds,
    required this.tags,
  });

  final String entryId;
  final double score;
  final List<String> nodeIds;
  final Set<String> tags;
}

class LocalNegativeConstraint {
  const LocalNegativeConstraint({
    required this.conclusionId,
    required this.nodeIds,
    required this.edgeIds,
    required this.correctionNote,
    required this.createdAt,
  });

  final String conclusionId;
  final Set<String> nodeIds;
  final Set<String> edgeIds;
  final String? correctionNote;
  final DateTime createdAt;
}

/// Encrypted, content-free vector and graph metadata store.
///
/// Transcript text is used transiently to create embeddings and is never
/// serialized. Persisted rows contain only opaque entry/node IDs, tags,
/// revisions, and normalized vectors.
class LocalSemanticStore {
  LocalSemanticStore({
    required EncryptedJsonFileStore storage,
    LocalEmbeddingDriver embeddingDriver = const HashedLocalEmbeddingDriver(),
    SqliteVecVectorStore? vectorStore,
    this.maxRecords = 20000,
  }) : // Public named parameters cannot initialize private fields directly.
       // ignore: prefer_initializing_formals
       _storage = storage,
       // ignore: prefer_initializing_formals
       _embeddingDriver = embeddingDriver,
       // ignore: prefer_initializing_formals
       _vectorStore = vectorStore;

  final EncryptedJsonFileStore _storage;
  final LocalEmbeddingDriver _embeddingDriver;
  final SqliteVecVectorStore? _vectorStore;
  final int maxRecords;
  bool _vectorIndexReady = false;
  Future<void> _writeTail = Future<void>.value();
  final StreamController<Set<String>> _rejectedNodeChanges =
      StreamController<Set<String>>.broadcast();
  final StreamController<Set<String>> _rejectedEdgeChanges =
      StreamController<Set<String>>.broadcast();
  final StreamController<void> _overlayGraphChanges =
      StreamController<void>.broadcast();

  Stream<Set<String>> get rejectedNodeChanges => _rejectedNodeChanges.stream;
  Stream<Set<String>> get rejectedEdgeChanges => _rejectedEdgeChanges.stream;
  Stream<void> get overlayGraphChanges => _overlayGraphChanges.stream;
  bool get hasNativeVectorAcceleration => _vectorStore?.isAccelerated == true;

  Future<void> upsert(OnDeviceExtractionResult result) => _serialized(() async {
    final records = await _read();
    final related = result.graph.nodes
        .where(
          (node) => node.evidence.any((item) => item.entryId == result.entryId),
        )
        .toList();
    final nodes = related.map((node) => node.id).toSet().toList()..sort();
    records[result.entryId] = _LocalSemanticRecord(
      entryId: result.entryId,
      revision: _vectorRevision(result.embedding),
      vector: result.embedding,
      nodeIds: nodes,
      tags: result.tags,
      updatedAt: DateTime.now().toUtc(),
      confidence: _meanConfidence(related),
    );
    await _write(records);
  });

  /// Adds content-free graph references for a visual memory.
  ///
  /// [searchableText] is embedded transiently and is never serialized.
  Future<bool> upsertMediaMemory({
    required String sourceNodeId,
    required String searchableText,
    required Iterable<String> nodeIds,
    required Iterable<String> tags,
  }) => _serialized(() async {
    final text = searchableText.trim();
    if (sourceNodeId.isEmpty || text.isEmpty) return false;
    final records = await _read();
    final sortedNodeIds = nodeIds.toSet().toList()..sort();
    final normalizedTags = tags.toSet();
    final revision = sha256
        .convert(
          utf8.encode(
            '$text\u001f${sortedNodeIds.join('\u001f')}\u001f'
            '${(normalizedTags.toList()..sort()).join('\u001f')}',
          ),
        )
        .toString();
    final existing = records[sourceNodeId];
    if (existing?.revision == revision &&
        _sameList(existing!.nodeIds, sortedNodeIds) &&
        existing.tags.length == normalizedTags.length &&
        existing.tags.containsAll(normalizedTags)) {
      return false;
    }
    records[sourceNodeId] = _LocalSemanticRecord(
      entryId: sourceNodeId,
      revision: revision,
      vector: _embeddingDriver.embed(text),
      nodeIds: sortedNodeIds,
      tags: normalizedTags,
      updatedAt: DateTime.now().toUtc(),
      confidence: 1,
    );
    await _write(records);
    return true;
  });

  Future<bool> upsertFromGraph(
    JournalEntry entry,
    PersonalKnowledgeGraph graph,
  ) => _serialized(() async {
    final text = ComparableEvidenceText.userText(entry);
    if (!_eligible(entry, text)) return false;
    final records = await _read();
    final revision = sha256.convert(text.codeUnits).toString();
    final existing = records[entry.id];
    final related = graph.nodes
        .where((node) => node.evidence.any((item) => item.entryId == entry.id))
        .toList();
    final nodeIds = related.map((node) => node.id).toSet().toList()..sort();
    final tags = related.map((node) => node.type.name).toSet();
    final confidence = _meanConfidence(related);
    if (existing?.revision == revision &&
        _sameList(existing!.nodeIds, nodeIds) &&
        existing.tags.length == tags.length &&
        existing.tags.containsAll(tags) &&
        (existing.confidence - confidence).abs() < .0001) {
      return false;
    }
    records[entry.id] = _LocalSemanticRecord(
      entryId: entry.id,
      revision: revision,
      vector: _embeddingDriver.embed(text),
      nodeIds: nodeIds,
      tags: tags,
      updatedAt: DateTime.now().toUtc(),
      confidence: confidence,
    );
    await _write(records);
    return true;
  });

  Future<int> reconcileFromGraph(
    List<JournalEntry> entries,
    PersonalKnowledgeGraph graph,
  ) => _serialized(() async {
    final records = await _read();
    final eligibleIds = entries
        .where(
          (entry) => _eligible(entry, ComparableEvidenceText.userText(entry)),
        )
        .map((entry) => entry.id)
        .toSet();
    final previousCount = records.length;
    records.removeWhere((id, _) => !eligibleIds.contains(id));
    var changed = previousCount - records.length;
    for (final entry in entries) {
      final text = ComparableEvidenceText.userText(entry);
      if (!_eligible(entry, text)) continue;
      final revision = sha256.convert(text.codeUnits).toString();
      final related = graph.nodes
          .where(
            (node) => node.evidence.any((item) => item.entryId == entry.id),
          )
          .toList();
      final nodeIds = related.map((node) => node.id).toSet().toList()..sort();
      final tags = related.map((node) => node.type.name).toSet();
      final confidence = _meanConfidence(related);
      final existing = records[entry.id];
      if (existing?.revision == revision &&
          _sameList(existing!.nodeIds, nodeIds) &&
          existing.tags.length == tags.length &&
          existing.tags.containsAll(tags) &&
          (existing.confidence - confidence).abs() < .0001) {
        continue;
      }
      records[entry.id] = _LocalSemanticRecord(
        entryId: entry.id,
        revision: revision,
        vector: _embeddingDriver.embed(text),
        nodeIds: nodeIds,
        tags: tags,
        updatedAt: DateTime.now().toUtc(),
        confidence: confidence,
      );
      changed++;
    }
    if (changed > 0) await _write(records);
    return changed;
  });

  Future<List<LocalSemanticHit>> search(
    String query, {
    Set<String> requiredTags = const {},
    Set<String>? allowedNodeIds,
    String? clusterType,
    DateTime? updatedAfter,
    double minimumConfidence = 0,
    int limit = 20,
  }) async {
    await _writeTail.catchError((Object _) {});
    if (!_vectorIndexReady && _vectorStore?.isAccelerated == true) {
      await prepareVectorIndex();
    }
    final queryVector = _embeddingDriver.embed(query);
    final vectorStore = _vectorStore;
    if (_vectorIndexReady && vectorStore?.isAccelerated == true) {
      try {
        final rejected = await rejectedNodeIds();
        final candidateLimit = math.max(64, limit * 8).clamp(1, 500);
        final nativeHits = vectorStore!.search(
          queryVector,
          limit: candidateLimit,
          clusterType:
              clusterType ??
              (requiredTags.length == 1 ? requiredTags.first : null),
          updatedAfter: updatedAfter,
          minimumConfidence: minimumConfidence,
        );
        final hits = <LocalSemanticHit>[];
        for (final hit in nativeHits) {
          if (!hit.tags.containsAll(requiredTags)) continue;
          final visibleNodeIds = hit.nodeIds
              .where(
                (id) =>
                    !rejected.contains(id) &&
                    (allowedNodeIds == null || allowedNodeIds.contains(id)),
              )
              .toList(growable: false);
          if ((hit.nodeIds.isNotEmpty || allowedNodeIds != null) &&
              visibleNodeIds.isEmpty) {
            continue;
          }
          hits.add(
            LocalSemanticHit(
              entryId: hit.entryId,
              score: hit.cosineSimilarity,
              nodeIds: visibleNodeIds,
              tags: hit.tags,
            ),
          );
          if (hits.length >= limit.clamp(1, 100)) break;
        }
        return List.unmodifiable(hits);
      } on Object {
        // The encrypted JSON source remains authoritative if the optional
        // native index is unavailable or requires rebuilding.
      }
    }
    final records = await _read();
    final rejected = await rejectedNodeIds();
    final hits = <LocalSemanticHit>[];
    for (final record in records.values) {
      if (!record.tags.containsAll(requiredTags)) continue;
      if (clusterType?.isNotEmpty == true) {
        final sortedTags = record.tags.toList()..sort();
        if (sortedTags.firstOrNull != clusterType) continue;
      }
      if (updatedAfter != null && record.updatedAt.isBefore(updatedAfter)) {
        continue;
      }
      if (record.confidence < minimumConfidence.clamp(0, 1)) continue;
      final visibleNodeIds = record.nodeIds
          .where(
            (id) =>
                !rejected.contains(id) &&
                (allowedNodeIds == null || allowedNodeIds.contains(id)),
          )
          .toList();
      if ((record.nodeIds.isNotEmpty || allowedNodeIds != null) &&
          visibleNodeIds.isEmpty) {
        continue;
      }
      hits.add(
        LocalSemanticHit(
          entryId: record.entryId,
          score: _cosine(queryVector, record.vector),
          nodeIds: visibleNodeIds,
          tags: record.tags,
        ),
      );
    }
    hits.sort((a, b) {
      final score = b.score.compareTo(a.score);
      return score != 0 ? score : a.entryId.compareTo(b.entryId);
    });
    return List.unmodifiable(hits.take(limit.clamp(1, 100)));
  }

  /// Performs a content-free nearest-neighbor lookup from a caller-owned
  /// vector. The native sqlite-vec index is preferred; encrypted records remain
  /// the authoritative fallback when the optional extension is unavailable.
  Future<List<LocalSemanticHit>> searchVector(
    List<double> query, {
    Set<String>? allowedNodeIds,
    double minimumConfidence = 0,
    int limit = 20,
  }) async {
    await _writeTail.catchError((Object _) {});
    if (!_vectorIndexReady && _vectorStore?.isAccelerated == true) {
      await prepareVectorIndex();
    }
    final queryVector = Float32List.fromList(query);
    final vectorStore = _vectorStore;
    if (_vectorIndexReady && vectorStore?.isAccelerated == true) {
      try {
        final rejected = await rejectedNodeIds();
        return List.unmodifiable(
          vectorStore!
              .search(
                queryVector,
                limit: math.max(64, limit * 8).clamp(1, 500),
                minimumConfidence: minimumConfidence,
              )
              .map(
                (hit) => LocalSemanticHit(
                  entryId: hit.entryId,
                  score: hit.cosineSimilarity,
                  nodeIds: hit.nodeIds
                      .where(
                        (id) =>
                            !rejected.contains(id) &&
                            (allowedNodeIds == null ||
                                allowedNodeIds.contains(id)),
                      )
                      .toList(growable: false),
                  tags: hit.tags,
                ),
              )
              .where((hit) => hit.nodeIds.isNotEmpty)
              .take(limit.clamp(1, 100)),
        );
      } on Object {
        // Continue with the encrypted local source below.
      }
    }
    final rejected = await rejectedNodeIds();
    final hits = <LocalSemanticHit>[];
    for (final record in (await _read()).values) {
      if (record.confidence < minimumConfidence) continue;
      final nodeIds = record.nodeIds
          .where(
            (id) =>
                !rejected.contains(id) &&
                (allowedNodeIds == null || allowedNodeIds.contains(id)),
          )
          .toList(growable: false);
      if (nodeIds.isEmpty) continue;
      hits.add(
        LocalSemanticHit(
          entryId: record.entryId,
          score: _cosine(queryVector, record.vector),
          nodeIds: nodeIds,
          tags: record.tags,
        ),
      );
    }
    hits.sort((left, right) => right.score.compareTo(left.score));
    return List.unmodifiable(hits.take(limit.clamp(1, 100)));
  }

  Future<int> count() async {
    await _writeTail.catchError((Object _) {});
    return (await _read()).length;
  }

  Future<void> prepareVectorIndex() {
    if (_vectorIndexReady || _vectorStore?.isAccelerated != true) {
      return Future.value();
    }
    return _serialized(() async {
      if (_vectorIndexReady || _vectorStore?.isAccelerated != true) return;
      final records = (await _read()).values.toList()
        ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
      try {
        _replaceNativeIndex(records.take(maxRecords));
      } on Object {
        _vectorIndexReady = false;
      }
    });
  }

  /// Returns content-free per-node vectors derived from encrypted records.
  ///
  /// Every eligible record contributes once to each referenced node. The
  /// arithmetic mean is normalized so callers cannot infer aggregate vector
  /// magnitude or access individual entry vectors.
  Future<List<AggregatedNodeVector>> readAggregatedNodeVectors({
    Iterable<String>? nodeIds,
  }) async {
    await _writeTail.catchError((Object _) {});
    final requested = nodeIds?.toSet();
    if (requested?.isEmpty == true) return const [];
    final records = (await _read()).values.toList()
      ..sort((left, right) => left.entryId.compareTo(right.entryId));
    final accumulators = <String, _NodeVectorAccumulator>{};
    for (final record in records) {
      if (record.vector.isEmpty) continue;
      for (final nodeId in record.nodeIds.toSet()) {
        if (nodeId.isEmpty ||
            (requested != null && !requested.contains(nodeId))) {
          continue;
        }
        final accumulator = accumulators[nodeId];
        if (accumulator != null &&
            accumulator.values.length != record.vector.length) {
          continue;
        }
        final target =
            accumulator ?? _NodeVectorAccumulator(record.vector.length);
        accumulators[nodeId] = target;
        for (var index = 0; index < record.vector.length; index++) {
          target.values[index] += record.vector[index];
        }
        target.sampleCount++;
        if (record.updatedAt.isAfter(target.updatedAt)) {
          target.updatedAt = record.updatedAt;
        }
      }
    }
    final orderedIds = accumulators.keys.toList()..sort();
    final result = <AggregatedNodeVector>[];
    for (final nodeId in orderedIds) {
      final accumulator = accumulators[nodeId]!;
      final mean = [
        for (final total in accumulator.values) total / accumulator.sampleCount,
      ];
      var squaredNorm = 0.0;
      for (final value in mean) {
        squaredNorm += value * value;
      }
      if (squaredNorm == 0) continue;
      final norm = math.sqrt(squaredNorm);
      result.add(
        AggregatedNodeVector(
          nodeId: nodeId,
          vector: mean.map((value) => value / norm),
          sampleCount: accumulator.sampleCount,
          updatedAt: accumulator.updatedAt,
        ),
      );
    }
    return List.unmodifiable(result);
  }

  Future<int> trustedAnchorCount() async {
    await _writeTail.catchError((Object _) {});
    return ((await _readDocument())['trustedAnchors'] as List? ?? const [])
        .length;
  }

  Future<void> upsertHypothesis(HypothesisEvolution hypothesis) =>
      _serialized(() async {
        final document = await _readDocument();
        final hypotheses =
            (document['hypotheses'] as List? ?? const [])
                .map(HypothesisEvolution.fromJson)
                .whereType<HypothesisEvolution>()
                .where((item) => item.theoryId != hypothesis.theoryId)
                .toList()
              ..add(hypothesis);
        hypotheses.sort(
          (a, b) => b.evolutionHistory.last.date.compareTo(
            a.evolutionHistory.last.date,
          ),
        );
        document['hypotheses'] = hypotheses
            .take(200)
            .map((item) => item.toJson())
            .toList(growable: false);
        await _storage.writeJson(document);
      });

  Future<List<HypothesisEvolution>> activeHypotheses({
    int confidenceBelow = 85,
    int limit = 20,
  }) async {
    await _writeTail.catchError((Object _) {});
    final rows = (await _readDocument())['hypotheses'] as List? ?? const [];
    final hypotheses =
        rows
            .map(HypothesisEvolution.fromJson)
            .whereType<HypothesisEvolution>()
            .where((item) => item.currentConfidence < confidenceBelow)
            .toList()
          ..sort(
            (a, b) => b.evolutionHistory.last.date.compareTo(
              a.evolutionHistory.last.date,
            ),
          );
    return List.unmodifiable(hypotheses.take(limit.clamp(1, 50)));
  }

  Future<HypothesisEvolution?> hypothesisById(String theoryId) async {
    await _writeTail.catchError((Object _) {});
    final rows = (await _readDocument())['hypotheses'] as List? ?? const [];
    for (final row in rows) {
      final hypothesis = HypothesisEvolution.fromJson(row);
      if (hypothesis?.theoryId == theoryId) return hypothesis;
    }
    return null;
  }

  Future<void> saveManualGraph(PersonalKnowledgeGraph graph) async {
    await _serialized(() async {
      final document = await _readDocument();
      document['manualGraph'] = graph.toJson();
      await _storage.writeJson(document);
    });
    _overlayGraphChanges.add(null);
  }

  Future<PersonalKnowledgeGraph> manualGraph() async {
    await _writeTail.catchError((Object _) {});
    final raw = (await _readDocument())['manualGraph'];
    if (raw is! Map) return PersonalKnowledgeGraph();
    return PersonalKnowledgeGraph.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<void> saveExternalGraph(PersonalKnowledgeGraph graph) async {
    await _serialized(() async {
      final document = await _readDocument();
      document['externalGraph'] = graph.toJson();
      await _storage.writeJson(document);
    });
    _overlayGraphChanges.add(null);
  }

  Future<PersonalKnowledgeGraph> externalGraph() async {
    await _writeTail.catchError((Object _) {});
    final raw = (await _readDocument())['externalGraph'];
    if (raw is! Map) return PersonalKnowledgeGraph();
    return PersonalKnowledgeGraph.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<List<Map<String, dynamic>>> manualTruthAnchorsJson() async {
    final graph = await manualGraph();
    return [
      for (final node in graph.nodes)
        if (node.origin == NodeOrigin.manual)
          {
            'kind': 'node',
            'id': node.id,
            'label': node.label,
            'category': node.type.name,
            'origin': node.origin.wireName,
            'confidence': 100,
            'note': node.evidence.firstOrNull?.excerpt ?? '',
          },
      for (final edge in graph.edges)
        if (edge.origin == NodeOrigin.manual)
          {
            'kind': 'edge',
            'id': edge.id,
            'sourceNodeId': edge.sourceNodeId,
            'targetNodeId': edge.targetNodeId,
            'relation': edge.type.name,
            'origin': edge.origin.wireName,
            'confidence': 100,
            'note': edge.evidence.firstOrNull?.excerpt ?? '',
          },
    ];
  }

  Future<List<Map<String, dynamic>>> externalTruthAnchorsJson() async {
    final graph = await externalGraph();
    final anchors = [
      for (final node in graph.nodes)
        if (node.origin == NodeOrigin.external)
          {
            'kind': 'node',
            'id': node.id,
            'label': node.label,
            'category': node.type.name,
            'origin': node.origin.wireName,
            'confidence': 100,
            'source': node.externalSource?.wireName,
            'observedAt': node.createdAt.toIso8601String(),
            'note': node.evidence.firstOrNull?.excerpt ?? '',
          },
      for (final edge in graph.edges)
        if (edge.origin == NodeOrigin.external)
          {
            'kind': 'edge',
            'id': edge.id,
            'sourceNodeId': edge.sourceNodeId,
            'targetNodeId': edge.targetNodeId,
            'relation': edge.type.name,
            'origin': edge.origin.wireName,
            'confidence': 100,
            'source': edge.externalSource?.wireName,
            'observedAt': edge.createdAt.toIso8601String(),
            'note': edge.evidence.firstOrNull?.excerpt ?? '',
          },
    ];
    anchors.sort(
      (left, right) =>
          '${right['observedAt']}'.compareTo('${left['observedAt']}'),
    );
    return anchors;
  }

  Future<List<Map<String, dynamic>>> truthAnchorsJson() async {
    final manual = await manualTruthAnchorsJson();
    final external = await externalTruthAnchorsJson();
    return [...manual.take(70), ...external.take(30)];
  }

  Future<void> recordHighTrustAnchors({
    required String conclusionId,
    required Iterable<String> sourceEntryIds,
  }) => _serialized(() async {
    final document = await _readDocument();
    final rows = (document['trustedAnchors'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .where((row) => row['conclusionId'] != conclusionId)
        .toList();
    rows.add({
      'conclusionId': conclusionId,
      'sourceEntryIds': sourceEntryIds.toSet().toList()..sort(),
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
    document['trustedAnchors'] = rows.take(500).toList();
    await _storage.writeJson(document);
  });

  Future<void> recordNegativeConstraint({
    required String conclusionId,
    required Iterable<String> nodeIds,
    Iterable<String> edgeIds = const [],
    String? correctionNote,
  }) => _serialized(() async {
    final document = await _readDocument();
    final rows = (document['negativeConstraints'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .where((row) => row['conclusionId'] != conclusionId)
        .toList();
    rows.add({
      'conclusionId': conclusionId,
      'nodeIds': nodeIds.toSet().toList()..sort(),
      'edgeIds': edgeIds.toSet().toList()..sort(),
      if (correctionNote?.trim().isNotEmpty == true)
        'correctionNote': correctionNote!.trim(),
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
    document['negativeConstraints'] = rows.take(500).toList();
    await _storage.writeJson(document);
    _rejectedNodeChanges.add(_rejectedNodeIdsFromDocument(document));
    _rejectedEdgeChanges.add(_rejectedEdgeIdsFromDocument(document));
  });

  Future<List<LocalNegativeConstraint>> recentNegativeConstraints({
    int limit = 20,
  }) async {
    await _writeTail.catchError((Object _) {});
    final rows =
        (await _readDocument())['negativeConstraints'] as List? ?? const [];
    final result = <LocalNegativeConstraint>[];
    for (final raw in rows.whereType<Map>()) {
      final row = Map<String, dynamic>.from(raw);
      final conclusionId = row['conclusionId']?.toString() ?? '';
      final createdAt = DateTime.tryParse(row['createdAt']?.toString() ?? '');
      if (conclusionId.isEmpty || createdAt == null) continue;
      result.add(
        LocalNegativeConstraint(
          conclusionId: conclusionId,
          nodeIds: (row['nodeIds'] as List? ?? const [])
              .map((id) => '$id')
              .toSet(),
          edgeIds: (row['edgeIds'] as List? ?? const [])
              .map((id) => '$id')
              .toSet(),
          correctionNote: row['correctionNote']?.toString(),
          createdAt: createdAt.toUtc(),
        ),
      );
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(result.take(limit.clamp(1, 100)));
  }

  Future<Set<String>> rejectedNodeIds() async =>
      _rejectedNodeIdsFromDocument(await _readDocument());
  Future<Set<String>> rejectedEdgeIds() async =>
      _rejectedEdgeIdsFromDocument(await _readDocument());

  Future<PersonalKnowledgeGraph> applyGraphConstraints(
    PersonalKnowledgeGraph graph,
  ) async {
    final rejected = await rejectedNodeIds();
    final rejectedEdges = await rejectedEdgeIds();
    if (rejected.isEmpty && rejectedEdges.isEmpty) return graph;
    final nodes = graph.nodes
        .where((node) => !rejected.contains(node.id))
        .toList();
    final nodeIds = nodes.map((node) => node.id).toSet();
    return PersonalKnowledgeGraph(
      schemaVersion: graph.schemaVersion,
      nodes: nodes,
      edges: graph.edges
          .where(
            (edge) =>
                !rejectedEdges.contains(edge.id) &&
                nodeIds.contains(edge.sourceNodeId) &&
                nodeIds.contains(edge.targetNodeId),
          )
          .toList(),
      trajectories: graph.trajectories
          .where(
            (trajectory) =>
                nodeIds.contains(trajectory.subjectNodeId) &&
                (trajectory.relatedNodeId == null ||
                    nodeIds.contains(trajectory.relatedNodeId)),
          )
          .toList(),
      materialization: graph.materialization,
      clock: graph.clock,
    );
  }

  Future<void> clear() => _serialized(() async {
    if (await _storage.file.exists()) await _storage.file.delete();
    if (_vectorStore?.isAccelerated == true) {
      _vectorStore!.clear();
      _vectorIndexReady = true;
    }
  });

  Future<void> dispose() async {
    await _writeTail.catchError((Object _) {});
    _vectorStore?.close();
    await _rejectedNodeChanges.close();
    await _rejectedEdgeChanges.close();
    await _overlayGraphChanges.close();
  }

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _writeTail = _writeTail.catchError((Object _) {}).then((_) async {
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<Map<String, _LocalSemanticRecord>> _read() async {
    try {
      final raw = await _readDocument();
      final rows = raw['records'];
      if (rows is! List) return {};
      final result = <String, _LocalSemanticRecord>{};
      for (final row in rows.whereType<Map>()) {
        final record = _LocalSemanticRecord.fromJson(row);
        if (record != null) result[record.entryId] = record;
      }
      return result;
    } on Object {
      return {};
    }
  }

  Future<void> _write(Map<String, _LocalSemanticRecord> records) {
    final ordered = records.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return _writeRecords(ordered);
  }

  Future<void> _writeRecords(List<_LocalSemanticRecord> ordered) async {
    final document = await _readDocument();
    final retained = ordered.take(maxRecords).toList(growable: false);
    await _storage.writeJson({
      ...document,
      'schemaVersion': 2,
      'dimensions': _embeddingDriver.dimensions,
      'records': retained
          .map((record) => record.toJson())
          .toList(growable: false),
    });
    final vectorStore = _vectorStore;
    if (vectorStore?.isAccelerated != true) return;
    try {
      _replaceNativeIndex(retained);
    } on Object {
      _vectorIndexReady = false;
      // Keep the encrypted document authoritative. Search falls back to it.
    }
  }

  void _replaceNativeIndex(Iterable<_LocalSemanticRecord> records) {
    _vectorStore!.replaceAll([
      for (final record in records)
        SqliteVecRecord(
          entryId: record.entryId,
          embedding: record.vector,
          clusterType: (record.tags.toList()..sort()).firstOrNull ?? '',
          updatedAt: record.updatedAt,
          confidence: record.confidence,
          nodeIds: record.nodeIds,
          tags: record.tags,
        ),
    ]);
    _vectorIndexReady = true;
  }

  Future<Map<String, dynamic>> _readDocument() async {
    try {
      final raw = await _storage.readJson();
      if (raw is Map<String, dynamic>) return Map<String, dynamic>.from(raw);
      if (raw is Map) return Map<String, dynamic>.from(raw);
    } on Object {
      // Corrupt encrypted semantic state fails closed to an empty document.
    }
    return {};
  }

  static Set<String> _rejectedNodeIdsFromDocument(
    Map<String, dynamic> document,
  ) => {
    for (final raw
        in (document['negativeConstraints'] as List? ?? const [])
            .whereType<Map>())
      for (final id in (raw['nodeIds'] as List? ?? const [])) '$id',
  };

  static Set<String> _rejectedEdgeIdsFromDocument(
    Map<String, dynamic> document,
  ) => {
    for (final raw
        in (document['negativeConstraints'] as List? ?? const [])
            .whereType<Map>())
      for (final id in (raw['edgeIds'] as List? ?? const [])) '$id',
  };

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }

  static bool _eligible(JournalEntry entry, String text) =>
      text.isNotEmpty &&
      !entry.isArchived &&
      !entry.keepSeparate &&
      !entry.treatAsNew &&
      entry.memorySurfacing != 'do_not_surface';

  static String _vectorRevision(Float32List vector) =>
      sha256.convert(vector.buffer.asUint8List()).toString();

  static double _meanConfidence(List<GraphNode> nodes) {
    if (nodes.isEmpty) return 1;
    var total = 0.0;
    for (final node in nodes) {
      total += node.confidence.clamp(0, 1);
    }
    return total / nodes.length;
  }

  static double _cosine(Float32List a, Float32List b) {
    if (a.length != b.length || a.isEmpty) return 0;
    var dot = 0.0;
    var left = 0.0;
    var right = 0.0;
    for (var index = 0; index < a.length; index++) {
      dot += a[index] * b[index];
      left += a[index] * a[index];
      right += b[index] * b[index];
    }
    final denominator = math.sqrt(left) * math.sqrt(right);
    return denominator == 0 ? 0 : dot / denominator;
  }
}

final class _NodeVectorAccumulator {
  _NodeVectorAccumulator(int dimensions)
    : values = List<double>.filled(dimensions, 0),
      updatedAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  final List<double> values;
  int sampleCount = 0;
  DateTime updatedAt;
}

class _LocalSemanticRecord {
  const _LocalSemanticRecord({
    required this.entryId,
    required this.revision,
    required this.vector,
    required this.nodeIds,
    required this.tags,
    required this.updatedAt,
    required this.confidence,
  });

  final String entryId;
  final String revision;
  final Float32List vector;
  final List<String> nodeIds;
  final Set<String> tags;
  final DateTime updatedAt;
  final double confidence;

  Map<String, dynamic> toJson() => {
    'entryId': entryId,
    'revision': revision,
    'vector': vector.toList(growable: false),
    'nodeIds': nodeIds,
    'tags': tags.toList()..sort(),
    'updatedAt': updatedAt.toIso8601String(),
    'confidence': confidence,
  };

  static _LocalSemanticRecord? fromJson(Map raw) {
    final json = Map<String, dynamic>.from(raw);
    final entryId = json['entryId'];
    final revision = json['revision'];
    final vector = json['vector'];
    final updatedAt = DateTime.tryParse(json['updatedAt']?.toString() ?? '');
    if (entryId is! String ||
        entryId.isEmpty ||
        revision is! String ||
        vector is! List ||
        updatedAt == null) {
      return null;
    }
    final values = <double>[];
    for (final value in vector) {
      if (value is! num || !value.isFinite) return null;
      values.add(value.toDouble());
    }
    return _LocalSemanticRecord(
      entryId: entryId,
      revision: revision,
      vector: Float32List.fromList(values),
      nodeIds: (json['nodeIds'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
      tags: (json['tags'] as List? ?? const [])
          .map((item) => item.toString())
          .toSet(),
      updatedAt: updatedAt,
      confidence: (json['confidence'] as num?)?.toDouble().clamp(0, 1) ?? 1,
    );
  }
}
