import '../graph/graph_node.dart';
import '../graph/personal_knowledge_graph.dart';
import 'evidence_reference.dart';

class SentimentWindow {
  SentimentWindow({
    required DateTime start,
    required DateTime end,
    required num positivity,
    required this.mentionCount,
    required Iterable<EvidenceReference> evidence,
  }) : start = start.toUtc(),
       end = end.toUtc(),
       positivity = clampGraphScore(positivity),
       evidence = List.unmodifiable(evidence);

  final DateTime start;
  final DateTime end;
  final double positivity;
  final int mentionCount;
  final List<EvidenceReference> evidence;
}

class RelationshipMemory {
  RelationshipMemory({
    required this.personNodeId,
    required this.personLabel,
    required Iterable<SentimentWindow> sentimentTrajectory,
    required Iterable<String> earlierTopics,
    required Iterable<String> laterTopics,
    required this.positivityPercentDelta,
    required Iterable<EvidenceReference> evidence,
  }) : sentimentTrajectory = List.unmodifiable(sentimentTrajectory),
       earlierTopics = List.unmodifiable(earlierTopics),
       laterTopics = List.unmodifiable(laterTopics),
       evidence = List.unmodifiable(evidence);

  final String personNodeId;
  final String personLabel;
  final List<SentimentWindow> sentimentTrajectory;
  final List<String> earlierTopics;
  final List<String> laterTopics;
  final double positivityPercentDelta;
  final List<EvidenceReference> evidence;
}

class RelationshipMemoryEngine {
  const RelationshipMemoryEngine(this.graph);

  final PersonalKnowledgeGraph graph;

  List<RelationshipMemory> analyze({
    Duration window = const Duration(days: 30),
  }) {
    if (window <= Duration.zero) {
      throw ArgumentError.value(window, 'window', 'Must be positive');
    }
    final results = <RelationshipMemory>[];
    for (final person in graph.nodes.where((n) => n.type == NodeType.person)) {
      final evidence = referencesForNode(graph, person);
      if (evidence.isEmpty) continue;
      final first = evidence.first.observedAt;
      final last = evidence.last.observedAt;
      final windows = <SentimentWindow>[];
      var start = first;
      while (!start.isAfter(last)) {
        final end = start.add(window);
        final items = evidence
            .where(
              (e) =>
                  !e.observedAt.isBefore(start) && e.observedAt.isBefore(end),
            )
            .toList();
        if (items.isNotEmpty) {
          windows.add(
            SentimentWindow(
              start: start,
              end: end,
              positivity: _positivity(items),
              mentionCount: items.length,
              evidence: items,
            ),
          );
        }
        start = end;
      }
      final connected = graph.getConnectedNodes(person.id);
      final midpoint = first.add(last.difference(first) ~/ 2);
      final earlier = <String>{};
      final later = <String>{};
      for (final node in connected) {
        for (final item in referencesForNode(graph, node)) {
          (item.observedAt.isAfter(midpoint) ? later : earlier).add(node.label);
        }
      }
      final initial = windows.first.positivity;
      final delta = (windows.last.positivity - initial) * 100;
      results.add(
        RelationshipMemory(
          personNodeId: person.id,
          personLabel: person.label,
          sentimentTrajectory: windows,
          earlierTopics: earlier.toList()..sort(),
          laterTopics: later.toList()..sort(),
          positivityPercentDelta: delta,
          evidence: evidence,
        ),
      );
    }
    results.sort((a, b) => a.personLabel.compareTo(b.personLabel));
    return List.unmodifiable(results);
  }

  static double _positivity(List<EvidenceReference> evidence) {
    var positive = 0;
    var negative = 0;
    for (final item in evidence) {
      final words = normalizeGraphLabel(item.excerpt).split(' ');
      positive += words.where(_positiveMarkers.contains).length;
      negative += words.where(_negativeMarkers.contains).length;
    }
    final total = positive + negative;
    return total == 0 ? 0.5 : positive / total;
  }

  static const _positiveMarkers = {
    'happy',
    'good',
    'great',
    'grateful',
    'kind',
    'love',
    'loved',
    'supportive',
    'calm',
    'joy',
    'trusted',
    'trust',
    'confident',
  };
  static const _negativeMarkers = {
    'angry',
    'bad',
    'sad',
    'upset',
    'hurt',
    'difficult',
    'worried',
    'frustrated',
    'conflict',
    'afraid',
    'fear',
    'tense',
  };
}
