import 'dart:collection';

import 'package:uuid/uuid.dart';

import '../../core/graph/graph_node.dart';
import '../../core/graph/personal_knowledge_graph.dart';
import '../../core/graph/personal_knowledge_graph_store.dart';
import '../semantic_clusters/semantic_cluster.dart';
import '../semantic_clusters/semantic_cluster_store.dart';

final class AudioTranscriptNode {
  const AudioTranscriptNode({
    required this.sentence,
    required this.nodeId,
    required this.startUtf16,
    required this.endUtf16,
  });

  final String sentence;
  final String nodeId;
  final int startUtf16;
  final int endUtf16;
}

final class AudioGraphMapping {
  AudioGraphMapping({
    required this.audioId,
    required Iterable<GraphNode> nodes,
    required Iterable<GraphEdge> edges,
    required Iterable<String> clusterIds,
    required Iterable<AudioTranscriptNode> transcriptNodes,
    required this.emotionalValence,
  }) : nodes = UnmodifiableListView(nodes),
       edges = UnmodifiableListView(edges),
       clusterIds = UnmodifiableListView(clusterIds),
       transcriptNodes = UnmodifiableListView(transcriptNodes);

  final String audioId;
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final List<String> clusterIds;
  final List<AudioTranscriptNode> transcriptNodes;
  final double emotionalValence;
}

final class AudioGraphMapper {
  const AudioGraphMapper({
    required this.graphStore,
    required this.clusterStore,
    this.onCompleted,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final PersonalKnowledgeGraphStore graphStore;
  final SemanticClusterStore clusterStore;
  final void Function(AudioGraphMapping mapping)? onCompleted;
  final DateTime Function() _clock;

  static const _positive = {
    'calm',
    'grateful',
    'happy',
    'hopeful',
    'excited',
    'proud',
    'better',
    'love',
    'progress',
  };
  static const _negative = {
    'sad',
    'angry',
    'afraid',
    'anxious',
    'stressed',
    'tired',
    'overwhelmed',
    'worse',
    'lonely',
  };
  static const _stopwords = {
    'about',
    'after',
    'again',
    'also',
    'because',
    'been',
    'before',
    'could',
    'from',
    'have',
    'into',
    'just',
    'that',
    'their',
    'there',
    'they',
    'this',
    'today',
    'want',
    'with',
    'would',
  };

  Future<AudioGraphMapping> mapTranscript({
    required String audioId,
    required String transcript,
    DateTime? capturedAt,
  }) async {
    final text = transcript.trim();
    if (audioId.trim().isEmpty || text.isEmpty || text.length > 1000000) {
      throw ArgumentError('Invalid audio transcript.');
    }
    final observedAt = (capturedAt ?? _clock()).toUtc();
    final sentences = _sentences(text);
    final nodes = <GraphNode>[];
    final transcriptNodes = <AudioTranscriptNode>[];
    final edges = <GraphEdge>[];
    for (var index = 0; index < sentences.length; index++) {
      final sentence = sentences[index];
      final keywords = _tokens(sentence.text)
          .where((word) => word.length >= 4 && !_stopwords.contains(word))
          .take(5)
          .toList();
      final action = RegExp(
        r'\b(i need to|i will|i should|remember to|todo|next step)\b',
        caseSensitive: false,
      ).hasMatch(sentence.text);
      final emotional = _tokens(
        sentence.text,
      ).any((word) => _positive.contains(word) || _negative.contains(word));
      final id = 'audio:${const Uuid().v4()}';
      final label = keywords.isEmpty
          ? sentence.text.split(RegExp(r'\s+')).take(6).join(' ')
          : keywords.join(' · ');
      final node = GraphNode(
        id: id,
        type: action
            ? NodeType.actionItem
            : emotional
            ? NodeType.emotion
            : NodeType.topic,
        label: label,
        confidence: .82,
        origin: NodeOrigin.extracted,
        evidence: [
          GraphNodeEvidence(
            entryId: 'audio:$audioId',
            observedAt: observedAt,
            confidence: .92,
            excerpt: sentence.text,
            startUtf16: sentence.start,
            endUtf16: sentence.end,
          ),
        ],
      );
      nodes.add(node);
      transcriptNodes.add(
        AudioTranscriptNode(
          sentence: sentence.text,
          nodeId: id,
          startUtf16: sentence.start,
          endUtf16: sentence.end,
        ),
      );
      if (index > 0) {
        edges.add(
          GraphEdge(
            id: 'audio-edge:${const Uuid().v4()}',
            sourceNodeId: nodes[index - 1].id,
            targetNodeId: id,
            type: EdgeType.mentionedWith,
            isDirected: true,
            weight: .75,
            evidence: [
              GraphEdgeEvidence(
                entryId: 'audio:$audioId',
                observedAt: observedAt,
                confidence: .85,
                excerpt: sentence.text,
                startUtf16: sentence.start,
                endUtf16: sentence.end,
              ),
            ],
          ),
        );
      }
    }

    await graphStore.update(
      (current) => PersonalKnowledgeGraph(
        schemaVersion: current.schemaVersion,
        nodes: [...current.nodes, ...nodes],
        edges: [...current.edges, ...edges],
        materialization: current.materialization,
      ),
    );
    final linked = await _linkClusters(text, nodes, observedAt);
    final mapping = AudioGraphMapping(
      audioId: audioId,
      nodes: nodes,
      edges: edges,
      clusterIds: linked,
      transcriptNodes: transcriptNodes,
      emotionalValence: _valence(text),
    );
    onCompleted?.call(mapping);
    return mapping;
  }

  Future<List<String>> _linkClusters(
    String transcript,
    List<GraphNode> nodes,
    DateTime observedAt,
  ) async {
    final transcriptTokens = _tokens(transcript).toSet();
    final clusters = await clusterStore.list();
    final matches = clusters.where((cluster) {
      final clusterTokens = _tokens(
        '${cluster.title} ${cluster.summary}',
      ).toSet();
      return clusterTokens.intersection(transcriptTokens).isNotEmpty;
    }).toList();
    if (matches.isEmpty) {
      final cluster = SemanticCluster(
        id: 'whispering-vault',
        title: 'Voice Reflections',
        category: SemanticClusterCategory.theme,
        nodeIds: nodes.map((node) => node.id),
        activityVelocity: .25,
        confidenceScore: .82,
        summary: 'Concepts extracted locally from offline voice reflections.',
        updatedAt: observedAt,
      );
      await clusterStore.upsert(cluster);
      return [cluster.id];
    }
    for (final cluster in matches.take(5)) {
      await clusterStore.upsert(
        cluster.copyWith(
          nodeIds: {...cluster.nodeIds, ...nodes.map((node) => node.id)},
          activityVelocity: (cluster.activityVelocity + .08).clamp(0, 1),
          updatedAt: observedAt,
        ),
      );
    }
    return matches.take(5).map((cluster) => cluster.id).toList();
  }

  double _valence(String text) {
    final tokens = _tokens(text);
    if (tokens.isEmpty) return 0;
    final positive = tokens.where(_positive.contains).length;
    final negative = tokens.where(_negative.contains).length;
    return ((positive - negative) / (positive + negative).clamp(1, 100)).clamp(
      -1,
      1,
    );
  }

  List<String> _tokens(String text) => RegExp(
    r"[A-Za-z][A-Za-z'-]+",
  ).allMatches(text.toLowerCase()).map((match) => match.group(0)!).toList();

  List<_Sentence> _sentences(String text) {
    final result = <_Sentence>[];
    for (final match in RegExp(r'[^.!?\n]+[.!?]?').allMatches(text)) {
      final raw = match.group(0)!;
      final leading = raw.length - raw.trimLeft().length;
      final sentence = raw.trim();
      if (sentence.isEmpty) continue;
      final start = match.start + leading;
      result.add(_Sentence(sentence, start, start + sentence.length));
    }
    return result;
  }
}

final class _Sentence {
  const _Sentence(this.text, this.start, this.end);
  final String text;
  final int start;
  final int end;
}
