import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/config/app_config.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/features/semantic_clusters/cluster_synthesis_service.dart';
import 'package:voicememory_mobile/features/semantic_clusters/semantic_cluster.dart';
import 'package:voicememory_mobile/services/capture_attest_service.dart';
import 'package:voicememory_mobile/storage/capture_token_cache.dart';
import 'package:voicememory_mobile/storage/device_id.dart';

void main() {
  setUpAll(AppConfig.initApiResolution);

  test('sends only anonymized structure and applies strict response', () async {
    late http.Request captured;
    final transport = ApiTransport(
      baseUrl: AppConfig.productionApiBaseUrl,
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'title': 'Focused connections',
            'briefSummary':
                'A connected project theme is becoming more active.',
            'category': 'project',
            'confidenceScore': 0.91,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    var tokenNumber = 0;
    final service = ClusterSynthesisService(
      transport: transport,
      attest: _Attest(),
      anonymousToken: () => 'request_token_${tokenNumber++}',
    );
    final cluster = _cluster();

    final result = await service.synthesize(cluster: cluster, graph: _graph());
    final payload = jsonDecode(captured.body) as Map<String, dynamic>;
    final serialized = captured.body.toLowerCase();

    expect(captured.url.path, '/api/cluster-synthesis');
    expect(captured.headers[ApiTransport.captureTokenHeader], 'capture-token');
    expect(payload.keys.toSet(), {
      'clusterId',
      'category',
      'candidateTitle',
      'nodes',
      'edgeMetrics',
      'vectorMetrics',
      'velocityMetrics',
    });
    expect(payload['clusterId'], startsWith('c_request_token_'));
    expect(
      (payload['nodes'] as List)
          .cast<Map<String, dynamic>>()
          .map((node) => node['anonymousId'])
          .toSet()
          .length,
      2,
    );
    for (final forbiddenKey in const [
      'id',
      'nodeid',
      'userid',
      'evidence',
      'transcript',
      'audio',
      'media',
      'path',
      'content',
    ]) {
      expect(_normalizedKeys(payload), isNot(contains(forbiddenKey)));
    }
    for (final forbiddenContent in const [
      'real-node-id-alice',
      'real-node-id-project',
      'entry-private-42',
      'private transcript excerpt',
      '/private/audio/recording.m4a',
      'user-991',
    ]) {
      expect(serialized, isNot(contains(forbiddenContent.toLowerCase())));
    }
    expect(result.title, 'Focused connections');
    expect(
      result.summary,
      'A connected project theme is becoming more active.',
    );
    expect(result.category, SemanticClusterCategory.project);
    expect(result.confidenceScore, 0.91);
  });

  test('returns local cluster when response is not strict', () async {
    final transport = ApiTransport(
      baseUrl: AppConfig.productionApiBaseUrl,
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'title': 'Cloud title',
            'briefSummary': 'Cloud summary',
            'category': 'theme',
            'confidenceScore': 0.8,
            'unexpected': 'not allowed',
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    final cluster = _cluster();

    final result = await ClusterSynthesisService(
      transport: transport,
      attest: _Attest(),
    ).synthesize(cluster: cluster, graph: _graph());

    expect(identical(result, cluster), isTrue);
  });

  test('returns local cluster on attestation failure', () async {
    final cluster = _cluster();
    final result = await ClusterSynthesisService(
      transport: ApiTransport(baseUrl: AppConfig.productionApiBaseUrl),
      attest: _Attest(fail: true),
    ).synthesize(cluster: cluster, graph: _graph());

    expect(identical(result, cluster), isTrue);
  });
}

SemanticCluster _cluster() => SemanticCluster(
  id: 'real-cluster-id-user-991',
  title: 'Project connections',
  category: SemanticClusterCategory.theme,
  nodeIds: const ['real-node-id-alice', 'real-node-id-project'],
  activityVelocity: 0.4,
  confidenceScore: 0.75,
  summary: 'Local fallback summary',
);

PersonalKnowledgeGraph _graph() => PersonalKnowledgeGraph(
  materialization: const GraphMaterializationMetadata(
    processedEntryRevisions: {'/private/audio/recording.m4a': 'user-991'},
  ),
  nodes: [
    GraphNode(
      id: 'real-node-id-alice',
      type: NodeType.person,
      label: 'Collaborator',
      confidence: 0.8,
      evidence: [_evidence()],
    ),
    GraphNode(
      id: 'real-node-id-project',
      type: NodeType.project,
      label: 'Launch project',
      confidence: 0.9,
      evidence: [_evidence(), _evidence()],
    ),
  ],
  edges: [
    GraphEdge(
      sourceNodeId: 'real-node-id-alice',
      targetNodeId: 'real-node-id-project',
      type: EdgeType.associatedWith,
      isDirected: false,
      weight: 0.8,
      evidence: [
        GraphEdgeEvidence(
          entryId: 'entry-private-42',
          observedAt: DateTime.utc(2026, 7, 1),
          confidence: 0.9,
          excerpt: 'private transcript excerpt',
          startUtf16: 0,
          endUtf16: 26,
        ),
      ],
    ),
  ],
);

GraphNodeEvidence _evidence() => GraphNodeEvidence(
  entryId: 'entry-private-42',
  observedAt: DateTime.utc(2026, 7, 1),
  confidence: 0.9,
  excerpt: 'private transcript excerpt',
  startUtf16: 0,
  endUtf16: 26,
);

Set<String> _normalizedKeys(Object? value) {
  final keys = <String>{};
  void visit(Object? item) {
    if (item is Map) {
      for (final entry in item.entries) {
        keys.add(
          entry.key
              .toString()
              .replaceAll(RegExp('[^a-zA-Z0-9]'), '')
              .toLowerCase(),
        );
        visit(entry.value);
      }
    } else if (item is List) {
      item.forEach(visit);
    }
  }

  visit(value);
  return keys;
}

final class _Attest extends CaptureAttestService {
  _Attest({this.fail = false})
    : super(
        api: VoiceCaptureApiClient(
          ApiTransport(baseUrl: AppConfig.productionApiBaseUrl),
        ),
        deviceIds: _DeviceIds(),
        tokenCache: CaptureTokenCache(),
      );

  final bool fail;

  @override
  Future<String> ensureCaptureToken({bool forceRefresh = false}) async {
    if (fail) throw StateError('attestation unavailable');
    return 'capture-token';
  }
}

final class _DeviceIds extends DeviceIdStore {
  @override
  Future<String> getOrCreate() async => 'device';
}
