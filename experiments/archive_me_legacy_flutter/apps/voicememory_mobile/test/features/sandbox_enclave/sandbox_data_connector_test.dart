import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/features/cognitive_analytics/cognitive_metrics_models.dart';
import 'package:voicememory_mobile/features/sandbox_enclave/sandbox_data_connector.dart';
import 'package:voicememory_mobile/features/sandbox_enclave/sandbox_models.dart';

void main() {
  test(
    'exports only filtered graph fields as an immutable JSON copy',
    () async {
      final node = GraphNode(
        id: 'node-1',
        type: NodeType.memory,
        label: 'Private label',
        confidence: .8,
        origin: NodeOrigin.manual,
        tags: const ['focus'],
        evidence: [
          GraphNodeEvidence(
            entryId: 'entry-secret',
            observedAt: DateTime.utc(2026),
            confidence: 1,
            excerpt: 'secret transcript',
            startUtf16: 0,
            endUtf16: 17,
          ),
        ],
      );
      final connector = SandboxDataConnector.loaders(
        graphLoader: () async => PersonalKnowledgeGraph(nodes: [node]),
        metricsLoader: () async => CognitiveMetricsSnapshot(
          range: CognitiveTimeRange.allTime,
          points: const [],
          insights: const [],
        ),
      );
      final request = SandboxDataViewRequest.graphNodes(nodeIds: [node.id]);

      final first = await connector.createView(request);
      final decoded = jsonDecode(utf8.decode(first)) as Map<String, dynamic>;
      final row = (decoded['rows'] as List).single as Map<String, dynamic>;
      expect(row['label'], 'Private label');
      expect(row, isNot(contains('evidence')));
      expect(row, isNot(contains('mediaAttachments')));
      expect(utf8.decode(first), isNot(contains('secret transcript')));
      row['label'] = 'mutated';

      final second = await connector.createView(request);
      expect(utf8.decode(second), isNot(contains('mutated')));
      expect(second, first);
    },
  );

  test('filters metric ranges and enforces byte boundaries', () async {
    final connector = SandboxDataConnector.loaders(
      graphLoader: () async => PersonalKnowledgeGraph(),
      metricsLoader: () async => CognitiveMetricsSnapshot(
        range: CognitiveTimeRange.allTime,
        points: [
          _point(DateTime.utc(2026, 1, 1)),
          _point(DateTime.utc(2026, 1, 2)),
        ],
        insights: const ['not exported'],
      ),
    );
    final bytes = await connector.createView(
      SandboxDataViewRequest.cognitiveMetrics(start: DateTime.utc(2026, 1, 2)),
    );
    final decoded = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    expect(decoded['rows'], hasLength(1));
    expect(utf8.decode(bytes), isNot(contains('not exported')));

    await expectLater(
      connector.createView(
        const SandboxDataViewRequest.cognitiveMetrics(maximumBytes: 128),
      ),
      throwsFormatException,
    );
  });
}

CognitiveMetricPoint _point(DateTime day) => CognitiveMetricPoint(
  day: day,
  valence: .2,
  movingAverage7: .1,
  movingAverage30: .1,
  movingAverage90: .1,
  cognitiveLoad: .3,
  semanticVelocity: .4,
  habitMomentum: .5,
  sleepHours: 8,
  journalCount: 1,
  negativeClusterDensity: .1,
  activeNodeCount: 2,
  resolvedClusterCount: 1,
);
