import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/config/app_config.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/features/life_simulator/life_simulator_engine.dart';
import 'package:voicememory_mobile/features/life_simulator/life_simulator_models.dart';
import 'package:voicememory_mobile/features/life_simulator/life_simulator_synthesis_service.dart';
import 'package:voicememory_mobile/services/capture_attest_service.dart';
import 'package:voicememory_mobile/storage/capture_token_cache.dart';
import 'package:voicememory_mobile/storage/device_id.dart';

void main() {
  setUpAll(AppConfig.initApiResolution);

  test(
    'sends no raw identifiers, labels, or quotes and reverse maps response',
    () async {
      late Map<String, dynamic> captured;
      final transport = ApiTransport(
        baseUrl: AppConfig.productionApiBaseUrl,
        httpClient: MockClient((request) async {
          captured = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
          final nodeId = (captured['nodes'] as List).first['id'] as String;
          final edgeId = (captured['edges'] as List).first['id'] as String;
          final citationHandles = (captured['citations'] as List)
              .map((citation) => citation['handle'] as String)
              .toList();
          return http.Response(
            jsonEncode(
              _response(
                affectedIds: [nodeId, edgeId],
                citationHandles: citationHandles,
              ),
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      var nonce = 0;
      final graph = _graph();
      final local = _scenario(graph);
      final result = await LifeSimulatorSynthesisService(
        transport: transport,
        attest: _Attest(),
        opaqueToken: () => 'opaque_${nonce++}',
      ).synthesize(scenario: local, graph: graph);
      final serialized = jsonEncode(captured).toLowerCase();

      expect(captured.keys.toSet(), {
        'target',
        'nodes',
        'edges',
        'aggregateTopology',
        'historicalDeltas',
        'externalCorrelationSummaries',
        'citations',
      });
      for (final privateValue in const [
        'raw-node-habit-user-42',
        'raw-node-goal-user-42',
        'raw-edge-user-42',
        'private evening routine',
        'private launch goal',
        'exact private quoted words',
        'entry-user-42',
        '/private/audio/user-42.m4a',
      ]) {
        expect(serialized, isNot(contains(privateValue)));
      }
      expect(_normalizedKeys(captured), isNot(contains('label')));
      expect(_normalizedKeys(captured), isNot(contains('displaylabel')));
      expect(_normalizedKeys(captured), isNot(contains('transcript')));
      expect(_normalizedKeys(captured), isNot(contains('exactquote')));
      expect(_normalizedKeys(captured), isNot(contains('evidencetext')));
      expect(_normalizedKeys(captured), isNot(contains('sourceentryid')));

      final milestone = result.continueTrajectory.milestones.first;
      expect(
        {...milestone.affectedNodeIds, ...milestone.affectedEdgeIds},
        {'raw-node-goal-user-42', 'raw-edge-user-42'},
      );
      expect(milestone.narrativeSummary, 'Cloud narrative for 30 days.');
      expect(milestone.projectedConfidence, .81);
      expect(
        milestone.projectedNodeScores,
        local.continueTrajectory.milestones.first.projectedNodeScores,
      );
      expect(
        milestone.projectedEdgeWeights,
        local.continueTrajectory.milestones.first.projectedEdgeWeights,
      );
      expect(milestone.localCitationHandles, contains('entry-user-42:4:30'));
      final citation = milestone.citations.singleWhere(
        (item) => item.sourceEntryId == 'entry-user-42',
      );
      expect(citation.sourceEntryId, 'entry-user-42');
      expect(citation.exactQuote, 'exact private quoted words');
      expect(citation.startUtf16, 4);
      expect(citation.endUtf16, 30);
      expect(citation.confidenceScore, .6);
    },
  );

  test('allocates a fresh opaque namespace for every request', () {
    var nonce = 0;
    final service = LifeSimulatorSynthesisService(
      transport: ApiTransport(baseUrl: AppConfig.productionApiBaseUrl),
      attest: _Attest(),
      opaqueToken: () => 'request_${nonce++}',
    );
    final graph = _graph();
    final scenario = _scenario(graph);

    final first = service.buildAnonymizedPayload(
      scenario: scenario,
      graph: graph,
    );
    final second = service.buildAnonymizedPayload(
      scenario: scenario,
      graph: graph,
    );

    expect(_opaqueReferences(first), isNot(equals(_opaqueReferences(second))));
  });

  test(
    'returns the identical local scenario for a malformed response',
    () async {
      final graph = _graph();
      final scenario = _scenario(graph);
      final service = LifeSimulatorSynthesisService(
        transport: ApiTransport(
          baseUrl: AppConfig.productionApiBaseUrl,
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode({
                ..._response(affectedIds: const [], citationHandles: const []),
                'unexpected': true,
              }),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        ),
        attest: _Attest(),
      );

      final result = await service.synthesize(scenario: scenario, graph: graph);

      expect(identical(result, scenario), isTrue);
    },
  );
}

CounterfactualScenario _scenario(PersonalKnowledgeGraph graph) =>
    const LifeSimulatorEngine(clock: _clock).compare(
      graph: graph,
      target: SimulationTarget.habit(
        'raw-node-habit-user-42',
        displayLabel: 'Private evening routine',
      ),
    );

DateTime _clock() => DateTime.utc(2026, 7, 20);

PersonalKnowledgeGraph _graph() => PersonalKnowledgeGraph(
  materialization: const GraphMaterializationMetadata(
    processedEntryRevisions: {'/private/audio/user-42.m4a': 'user-42'},
  ),
  nodes: [
    GraphNode(
      id: 'raw-node-habit-user-42',
      type: NodeType.habit,
      label: 'Private evening routine',
      confidence: .7,
      evidence: [
        _nodeEvidence(.6, DateTime.utc(2026, 6, 1)),
        _nodeEvidence(.9, DateTime.utc(2026, 7, 1)),
      ],
    ),
    GraphNode(
      id: 'raw-node-goal-user-42',
      type: NodeType.goal,
      label: 'Private launch goal',
      confidence: .8,
      evidence: [
        GraphNodeEvidence(
          entryId: 'second-private-entry',
          observedAt: DateTime.utc(2026, 7, 2),
          confidence: .8,
          excerpt: 'another private quote',
          startUtf16: 0,
          endUtf16: 21,
        ),
      ],
    ),
  ],
  edges: [
    GraphEdge(
      id: 'raw-edge-user-42',
      sourceNodeId: 'raw-node-habit-user-42',
      targetNodeId: 'raw-node-goal-user-42',
      type: EdgeType.influences,
      isDirected: true,
      weight: .75,
      evidence: [
        GraphEdgeEvidence(
          entryId: 'edge-private-entry',
          observedAt: DateTime.utc(2026, 7, 3),
          confidence: .75,
          excerpt: 'private edge quote',
          startUtf16: 0,
          endUtf16: 18,
        ),
      ],
    ),
  ],
);

GraphNodeEvidence _nodeEvidence(double confidence, DateTime observedAt) =>
    GraphNodeEvidence(
      entryId: 'entry-user-42',
      observedAt: observedAt,
      confidence: confidence,
      excerpt: 'exact private quoted words',
      startUtf16: 4,
      endUtf16: 30,
    );

Map<String, Object> _response({
  required List<String> affectedIds,
  required List<String> citationHandles,
}) => {
  'continueTrajectory': _trajectoryResponse(affectedIds, citationHandles),
  'stopOrPivotTrajectory': _trajectoryResponse(affectedIds, citationHandles),
};

Map<String, Object> _trajectoryResponse(
  List<String> affectedIds,
  List<String> citationHandles,
) => {
  'summary': 'Cloud conditional summary.',
  'milestones': [
    for (final days in const [30, 90, 365])
      {
        'horizonDays': days,
        'narrativeSummary': 'Cloud narrative for $days days.',
        'projectedConfidence': .81,
        'stressImpactScore': -.12,
        'healthCorrelation': null,
        'affectedIds': affectedIds,
        'citationHandles': citationHandles,
      },
  ],
};

Set<String> _normalizedKeys(Object? value) {
  final result = <String>{};
  void visit(Object? item) {
    if (item is Map) {
      for (final entry in item.entries) {
        result.add(
          entry.key
              .toString()
              .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
              .toLowerCase(),
        );
        visit(entry.value);
      }
    } else if (item is List) {
      item.forEach(visit);
    }
  }

  visit(value);
  return result;
}

Set<String> _opaqueReferences(Map<String, Object> payload) => {
  for (final node in (payload['nodes']! as List).cast<Map>())
    node['id'] as String,
  for (final edge in (payload['edges']! as List).cast<Map>())
    edge['id'] as String,
  for (final citation in (payload['citations']! as List).cast<Map>())
    citation['handle'] as String,
};

final class _Attest extends CaptureAttestService {
  _Attest()
    : super(
        api: VoiceCaptureApiClient(
          ApiTransport(baseUrl: AppConfig.productionApiBaseUrl),
        ),
        deviceIds: _DeviceIds(),
        tokenCache: CaptureTokenCache(),
      );

  @override
  Future<String> ensureCaptureToken({bool forceRefresh = false}) async =>
      'capture-token';
}

final class _DeviceIds extends DeviceIdStore {
  @override
  Future<String> getOrCreate() async => 'device';
}
