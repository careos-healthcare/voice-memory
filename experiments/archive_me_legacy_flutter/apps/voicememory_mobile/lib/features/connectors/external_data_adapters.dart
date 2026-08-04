import '../../core/graph/graph_node.dart';
import '../../core/graph/personal_knowledge_graph.dart';

class HealthDailySample {
  const HealthDailySample({
    required this.day,
    this.sleepHours,
    this.steps,
    this.restingHeartRate,
  });

  final DateTime day;
  final double? sleepHours;
  final int? steps;
  final double? restingHeartRate;
}

class SpotifyTrackSample {
  const SpotifyTrackSample({
    required this.trackId,
    required this.playedAt,
    required this.trackName,
    required this.artistName,
    this.valence,
    this.energy,
  });

  final String trackId;
  final DateTime playedAt;
  final String trackName;
  final String artistName;
  final double? valence;
  final double? energy;
}

abstract interface class ExternalDataAdapter<T> {
  PersonalKnowledgeGraph adapt(T input);
}

class HealthKitAdapter implements ExternalDataAdapter<HealthDailySample> {
  const HealthKitAdapter();

  @override
  PersonalKnowledgeGraph adapt(HealthDailySample input) {
    final day = DateTime.utc(input.day.year, input.day.month, input.day.day);
    final nodes = <GraphNode>[
      if (input.sleepHours case final hours?)
        _node(
          metric: 'sleep',
          label: 'Sleep: ${hours.toStringAsFixed(1)}h',
          day: day,
          type: NodeType.habit,
        ),
      if (input.steps case final steps?)
        _node(
          metric: 'steps',
          label: 'Steps: $steps',
          day: day,
          type: NodeType.habit,
        ),
      if (input.restingHeartRate case final bpm?)
        _node(
          metric: 'resting-heart-rate',
          label: 'Resting heart rate: ${bpm.round()} bpm',
          day: day,
          type: NodeType.emotion,
        ),
    ];
    return PersonalKnowledgeGraph(
      nodes: nodes,
      edges: _dailyEdges(nodes, day, ExternalSource.appleHealth),
    );
  }

  GraphNode _node({
    required String metric,
    required String label,
    required DateTime day,
    required NodeType type,
  }) => GraphNode(
    id: stableGraphId('external-node', [
      ExternalSource.appleHealth.wireName,
      metric,
      _dayKey(day),
    ]),
    type: type,
    label: label,
    confidence: 1,
    origin: NodeOrigin.external,
    externalSource: ExternalSource.appleHealth,
    createdAt: day,
    evidence: [_evidence(ExternalSource.appleHealth, metric, label, day)],
  );
}

class SpotifyAdapter implements ExternalDataAdapter<List<SpotifyTrackSample>> {
  const SpotifyAdapter();

  @override
  PersonalKnowledgeGraph adapt(List<SpotifyTrackSample> input) {
    if (input.isEmpty) return PersonalKnowledgeGraph();
    final played = [...input]..sort((a, b) => a.playedAt.compareTo(b.playedAt));
    final day = DateTime.utc(
      played.last.playedAt.year,
      played.last.playedAt.month,
      played.last.playedAt.day,
    );
    final valences = played.map((item) => item.valence).whereType<double>();
    final energies = played.map((item) => item.energy).whereType<double>();
    final nodes = <GraphNode>[
      _node(
        metric: 'listening-activity',
        label:
            'Listening activity: ${played.length} track${played.length == 1 ? '' : 's'}',
        day: day,
      ),
      if (valences.isNotEmpty)
        _node(
          metric: 'music-valence',
          label: 'Music valence: ${(_average(valences) * 100).round()}%',
          day: day,
        ),
      if (energies.isNotEmpty)
        _node(
          metric: 'music-energy',
          label: 'Music energy: ${(_average(energies) * 100).round()}%',
          day: day,
        ),
    ];
    return PersonalKnowledgeGraph(
      nodes: nodes,
      edges: _dailyEdges(nodes, day, ExternalSource.spotify),
    );
  }

  GraphNode _node({
    required String metric,
    required String label,
    required DateTime day,
  }) => GraphNode(
    id: stableGraphId('external-node', [
      ExternalSource.spotify.wireName,
      metric,
      _dayKey(day),
    ]),
    type: NodeType.emotion,
    label: label,
    confidence: 1,
    origin: NodeOrigin.external,
    externalSource: ExternalSource.spotify,
    createdAt: day,
    evidence: [_evidence(ExternalSource.spotify, metric, label, day)],
  );
}

List<GraphEdge> _dailyEdges(
  List<GraphNode> nodes,
  DateTime day,
  ExternalSource source,
) {
  if (nodes.length < 2) return const [];
  final edges = <GraphEdge>[];
  for (var index = 1; index < nodes.length; index++) {
    final label = '${nodes.first.label} · ${nodes[index].label}';
    edges.add(
      GraphEdge(
        sourceNodeId: nodes.first.id,
        targetNodeId: nodes[index].id,
        type: EdgeType.associatedWith,
        isDirected: false,
        weight: 1,
        interactionDate: day,
        evidence: [_edgeEvidence(source, 'daily-context', label, day)],
        origin: NodeOrigin.external,
        externalSource: source,
        createdAt: day,
      ),
    );
  }
  return edges;
}

GraphNodeEvidence _evidence(
  ExternalSource source,
  String metric,
  String label,
  DateTime day,
) => GraphNodeEvidence(
  entryId: 'external:${source.wireName}:$metric:${_dayKey(day)}',
  observedAt: day,
  confidence: 1,
  excerpt: label,
  startUtf16: 0,
  endUtf16: label.length,
);

GraphEdgeEvidence _edgeEvidence(
  ExternalSource source,
  String metric,
  String label,
  DateTime day,
) => GraphEdgeEvidence(
  entryId: 'external:${source.wireName}:$metric:${_dayKey(day)}',
  observedAt: day,
  confidence: 1,
  excerpt: label,
  startUtf16: 0,
  endUtf16: label.length,
);

String _dayKey(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

double _average(Iterable<double> values) {
  var total = 0.0;
  var count = 0;
  for (final value in values) {
    total += value.clamp(0, 1);
    count++;
  }
  return count == 0 ? 0 : total / count;
}
