import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/config/app_config.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/features/action_plans/action_plan_generator_service.dart';
import 'package:voicememory_mobile/features/action_plans/action_plan_models.dart';
import 'package:voicememory_mobile/features/life_simulator/life_simulator_engine.dart';
import 'package:voicememory_mobile/features/life_simulator/life_simulator_models.dart';
import 'package:voicememory_mobile/features/semantic_clusters/semantic_cluster.dart';
import 'package:voicememory_mobile/services/capture_attest_service.dart';
import 'package:voicememory_mobile/storage/capture_token_cache.dart';
import 'package:voicememory_mobile/storage/device_id.dart';

void main() {
  setUpAll(AppConfig.initApiResolution);

  test(
    'simulation request is structural, fresh, and reverse maps targets',
    () async {
      late Map<String, dynamic> captured;
      late Map<String, String> headers;
      final service = _service((request) async {
        captured = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
        headers = request.headers;
        final nodes = (captured['nodes'] as List).cast<Map>();
        return _jsonResponse(
          _validResponse(nodes[0]['id'] as String, nodes[1]['id'] as String),
        );
      });
      final graph = _graph();

      final plan = await service.generateFromSimulation(
        _scenario(graph),
        SimulationPath.continueTrajectory,
        graph,
      );
      final serialized = jsonEncode(captured).toLowerCase();

      expect(captured.keys.toSet(), {
        'source',
        'nodes',
        'edges',
        'aggregateMetrics',
        'trajectoryData',
      });
      expect(captured['source'], 'simulation_trajectory');
      expect(
        (captured['trajectoryData'] as List)
            .map((point) => point['horizonDays'])
            .toList(),
        [30, 90, 365],
      );
      expect(headers['x-vm-capture-token'], 'capture-token');
      expect(headers['x-vm-client'], 'voicememory-mobile');
      for (final privateValue in const [
        'raw-node-habit-user-42',
        'raw-node-goal-user-42',
        'raw-edge-user-42',
        'private evening routine',
        'private launch goal',
        'exact private quoted words',
        'entry-user-42',
        '/private/audio/user-42.m4a',
        'scenario-private-id',
      ]) {
        expect(serialized, isNot(contains(privateValue)));
      }
      expect(_normalizedKeys(captured), isNot(contains('label')));
      expect(_normalizedKeys(captured), isNot(contains('title')));
      expect(_normalizedKeys(captured), isNot(contains('evidence')));
      expect(_normalizedKeys(captured), isNot(contains('transcript')));
      expect(_normalizedKeys(captured), isNot(contains('entryid')));
      expect(_normalizedKeys(captured), isNot(contains('path')));
      expect(plan.simulationId, 'scenario-private-id');
      expect(plan.title, 'Optional small experiments');
      expect(plan.steps, hasLength(3));
      expect(plan.steps.map((step) => step.targetNodeId).toSet(), {
        'raw-node-goal-user-42',
        'raw-node-habit-user-42',
      });
      final scheduled = plan.steps.singleWhere(
        (step) => step.title == 'Try a scheduled action',
      );
      expect(scheduled.frequency.type, ActionPlanFrequencyType.customDays);
      expect(scheduled.frequency.weekdays, {DateTime.monday, DateTime.friday});
      expect(plan.id, startsWith('plan_local_'));
      expect(plan.steps.map((step) => step.id).toSet(), hasLength(3));
    },
  );

  test('cluster payload omits title, summary, IDs, and evidence content', () {
    var nonce = 0;
    final service = _service(
      (_) async => _jsonResponse({}),
      opaqueToken: () => 'opaque_${nonce++}',
    );
    final graph = _graph();
    final cluster = _cluster();

    final first = service.buildClusterPayload(cluster: cluster, graph: graph);
    final second = service.buildClusterPayload(cluster: cluster, graph: graph);
    final serialized = jsonEncode(first).toLowerCase();

    expect(first.keys.toSet(), {
      'source',
      'nodes',
      'edges',
      'aggregateMetrics',
      'clusterData',
    });
    expect(first['source'], 'semantic_cluster');
    expect((first['clusterData'] as Map).keys.toSet(), {
      'categoryToken',
      'cohesion',
      'activity',
    });
    for (final privateValue in const [
      'cluster-private-id',
      'private cluster title',
      'private cluster summary',
      'raw-node-habit-user-42',
      'raw-node-goal-user-42',
      'exact private quoted words',
      'entry-user-42',
    ]) {
      expect(serialized, isNot(contains(privateValue)));
    }
    expect(_opaqueIds(first), isNot(equals(_opaqueIds(second))));
  });

  test(
    'unknown response target causes exactly three local fallback steps',
    () async {
      final service = _service(
        (_) async =>
            _jsonResponse(_validResponse('unknown_node', 'unknown_node')),
      );

      final plan = await service.generateFromCluster(_cluster(), _graph());

      expect(plan.clusterId, 'cluster-private-id');
      expect(plan.title, 'Three small experiments');
      expect(plan.steps, hasLength(3));
      expect(
        plan.steps.every(
          (step) =>
              step.frequency.type == ActionPlanFrequencyType.daily &&
              {
                'raw-node-habit-user-42',
                'raw-node-goal-user-42',
              }.contains(step.targetNodeId),
        ),
        isTrue,
      );
      expect(plan.steps.map((step) => step.title).toList(), [
        'Open the next task for two minutes',
        'Make the routine one step easier',
        'Take one minute to choose the next step',
      ]);
    },
  );

  test('malformed frequency and wrong habit count both use fallback', () async {
    var requestCount = 0;
    final service = _service((request) async {
      final payload = Map<String, dynamic>.from(
        jsonDecode(request.body) as Map,
      );
      final target = (payload['nodes'] as List).first['id'] as String;
      final response = _validResponse(target, target);
      if (requestCount++ == 0) {
        (response['microHabits'] as List).removeLast();
      } else {
        final first = (response['microHabits'] as List).first as Map;
        first['customWeekdays'] = ['monday'];
      }
      return _jsonResponse(response);
    });

    final first = await service.generateFromCluster(_cluster(), _graph());
    final second = await service.generateFromCluster(_cluster(), _graph());

    expect(first.title, 'Three small experiments');
    expect(second.title, 'Three small experiments');
    expect(first.steps, hasLength(3));
    expect(second.steps, hasLength(3));
  });

  test('transport failure uses deterministic node-type fallback', () async {
    final service = _service((_) async => http.Response('failed', 500));

    final plan = await service.generateFromCluster(_cluster(), _graph());

    expect(plan.steps, hasLength(3));
    expect(plan.steps.map((step) => step.title).toList(), [
      'Open the next task for two minutes',
      'Make the routine one step easier',
      'Take one minute to choose the next step',
    ]);
  });
}

ActionPlanGeneratorService _service(
  Future<http.Response> Function(http.Request) handler, {
  String Function()? opaqueToken,
}) {
  var nonce = 0;
  return ActionPlanGeneratorService(
    transport: ApiTransport(
      baseUrl: AppConfig.productionApiBaseUrl,
      httpClient: MockClient(handler),
    ),
    attest: _Attest(),
    opaqueToken: opaqueToken ?? () => 'local_${nonce++}',
    clock: () => DateTime.utc(2026, 7, 27),
  );
}

http.Response _jsonResponse(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

Map<String, Object?> _validResponse(String firstTarget, String secondTarget) =>
    {
      'planTitle': 'Optional small experiments',
      'targetOutcome': 'Notice which brief actions feel sustainable.',
      'microHabits': [
        {
          'title': 'Try one tiny action',
          'frequency': 'daily',
          'customWeekdays': <String>[],
          'targetNodeId': firstTarget,
          'stackingCue': null,
        },
        {
          'title': 'Try a scheduled action',
          'frequency': 'custom_days',
          'customWeekdays': ['monday', 'friday'],
          'targetNodeId': secondTarget,
          'stackingCue': 'After a regular transition',
        },
        {
          'title': 'Notice completion',
          'frequency': 'daily',
          'customWeekdays': <String>[],
          'targetNodeId': firstTarget,
          'stackingCue': null,
        },
      ],
    };

CounterfactualScenario _scenario(PersonalKnowledgeGraph graph) {
  final generated = const LifeSimulatorEngine(clock: _clock).compare(
    graph: graph,
    target: SimulationTarget.habit(
      'raw-node-habit-user-42',
      displayLabel: 'Private evening routine',
    ),
  );
  return CounterfactualScenario(
    id: 'scenario-private-id',
    continueTrajectory: generated.continueTrajectory,
    alternativeTrajectory: generated.alternativeTrajectory,
  );
}

DateTime _clock() => DateTime.utc(2026, 7, 20);

SemanticCluster _cluster() => SemanticCluster(
  id: 'cluster-private-id',
  title: 'Private cluster title',
  summary: 'Private cluster summary',
  category: SemanticClusterCategory.habitCluster,
  nodeIds: const ['raw-node-habit-user-42', 'raw-node-goal-user-42'],
  activityVelocity: .64,
  confidenceScore: .72,
);

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
      evidence: [_evidence()],
    ),
    GraphNode(
      id: 'raw-node-goal-user-42',
      type: NodeType.goal,
      label: 'Private launch goal',
      confidence: .8,
      evidence: [_evidence()],
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
          entryId: 'entry-user-42',
          observedAt: DateTime.utc(2026, 7, 1),
          confidence: .75,
          excerpt: 'exact private quoted words',
          startUtf16: 0,
          endUtf16: 26,
        ),
      ],
    ),
  ],
);

GraphNodeEvidence _evidence() => GraphNodeEvidence(
  entryId: 'entry-user-42',
  observedAt: DateTime.utc(2026, 7, 1),
  confidence: .8,
  excerpt: 'exact private quoted words',
  startUtf16: 0,
  endUtf16: 26,
);

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

Set<String> _opaqueIds(Map<String, Object> payload) => {
  for (final node in (payload['nodes']! as List).cast<Map>())
    node['id'] as String,
  for (final edge in (payload['edges']! as List).cast<Map>())
    edge['id'] as String,
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
