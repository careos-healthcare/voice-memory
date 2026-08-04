import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph_store.dart';
import 'package:voicememory_mobile/features/horizon_lab/horizon_lab_service.dart';
import 'package:voicememory_mobile/features/horizon_lab/horizon_models.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  group('HorizonLabService', () {
    late Directory root;
    late PersonalKnowledgeGraphStore graphStore;
    late HorizonLabService service;
    late String databasePath;
    final now = DateTime.utc(2026, 7, 28);

    setUp(() async {
      root = Directory.systemTemp.createTempSync('horizon_lab_test_');
      final keys = InMemoryPrivateDataEncryptionKeyStore();
      graphStore = PersonalKnowledgeGraphStore(
        storage: EncryptedJsonFileStore(
          file: File('${root.path}/graph.enc'),
          keyStore: keys,
        ),
      );
      await graphStore.save(_sourceGraph());
      databasePath = '${root.path}/horizon.sqlite3';
      service = HorizonLabService.open(
        databasePath: databasePath,
        keyStore: keys,
        primaryGraphStore: graphStore,
        clock: () => now,
      );
    });

    tearDown(() async {
      await service.close();
      await graphStore.dispose();
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    test(
      'forks an isolated active graph subset without mutating reality',
      () async {
        final branch = await service.fork(
          name: 'Confidential Alternative',
          divergenceNodeId: 'pivot',
          activeNodeIds: const ['pivot', 'connected'],
        );
        final primary = await graphStore.load();

        expect(branch.overlay.nodes.map((node) => node.id), {
          'pivot',
          'connected',
        });
        expect(branch.overlay.edges, hasLength(1));
        expect(primary.nodes, hasLength(3));
        expect(branch.forkedNodeIds, contains('pivot'));
        expect(
          File(databasePath)
              .readAsStringSync(encoding: latin1)
              .contains('Confidential Alternative'),
          isFalse,
        );
      },
    );

    test('branch projection remains isolated until explicit merge', () async {
      final branch = await service.fork(
        name: 'Alternative A',
        divergenceNodeId: 'pivot',
      );
      final projected = await service.addProjections(branch.id, [
        HorizonProjectedNode(
          id: 'one-year',
          horizon: HorizonProjection.oneYear,
          label: 'Conditional project expansion',
          probability: .64,
          type: NodeType.outcome,
          risks: HorizonRiskVector(
            financial: .4,
            emotional: .3,
            career: .5,
            cognitiveLoad: .6,
            alignment: .8,
            reward: .7,
          ),
        ),
      ]);

      expect((await graphStore.load()).nodes, hasLength(3));
      expect(projected.overlay.nodes, hasLength(4));
      expect(projected.overlay.edges.length, greaterThan(1));
    });

    test(
      'CRDT merge adds projections but never overwrites source nodes',
      () async {
        final branch = await service.fork(
          name: 'Alternative B',
          divergenceNodeId: 'pivot',
        );
        final projected = await service.addProjections(branch.id, [
          HorizonProjectedNode(
            id: 'future',
            horizon: HorizonProjection.threeYears,
            label: 'Probabilistic aligned outcome',
            probability: .7,
            type: NodeType.goal,
            risks: HorizonRiskVector(
              financial: .2,
              emotional: .2,
              career: .3,
              cognitiveLoad: .4,
              alignment: .9,
              reward: .8,
            ),
          ),
        ]);
        final current = await graphStore.load();
        await graphStore.save(
          PersonalKnowledgeGraph(
            nodes: [
              GraphNode(
                id: 'pivot',
                type: NodeType.decision,
                label: 'Reality changed after fork',
                confidence: .9,
                evidence: [
                  _nodeEvidence('reality', 'Reality changed after fork'),
                ],
              ),
              ...current.nodes.where((node) => node.id != 'pivot'),
            ],
            edges: current.edges,
          ),
        );

        final merged = await service.mergeIntoPrimary(projected.id);
        expect(
          merged.nodes.singleWhere((node) => node.id == 'pivot').label,
          'Reality changed after fork',
        );
        expect(
          merged.nodes.where(
            (node) => node.label == 'Probabilistic aligned outcome',
          ),
          hasLength(1),
        );
        expect(
          (await service.get(projected.id))!.status,
          TimelineBranchStatus.converged,
        );
        await expectLater(
          service.mergeIntoPrimary(projected.id),
          throwsStateError,
        );
      },
    );
  });
}

PersonalKnowledgeGraph _sourceGraph() {
  final nodes = [
    GraphNode(
      id: 'pivot',
      type: NodeType.decision,
      label: 'Pivot',
      confidence: .9,
      evidence: [_nodeEvidence('pivot-entry', 'Pivot')],
    ),
    GraphNode(
      id: 'connected',
      type: NodeType.project,
      label: 'Connected',
      confidence: .9,
      evidence: [_nodeEvidence('connected-entry', 'Connected')],
    ),
    GraphNode(
      id: 'separate',
      type: NodeType.goal,
      label: 'Separate',
      confidence: .9,
      evidence: [_nodeEvidence('separate-entry', 'Separate')],
    ),
  ];
  return PersonalKnowledgeGraph(
    nodes: nodes,
    edges: [
      GraphEdge(
        id: 'connection',
        sourceNodeId: 'pivot',
        targetNodeId: 'connected',
        type: EdgeType.influences,
        isDirected: true,
        weight: 1,
        evidence: [
          GraphEdgeEvidence(
            entryId: 'edge-entry',
            observedAt: DateTime.utc(2026),
            confidence: .9,
            excerpt: 'Pivot connected',
            startUtf16: 0,
            endUtf16: 15,
          ),
        ],
      ),
    ],
  );
}

GraphNodeEvidence _nodeEvidence(String entryId, String excerpt) =>
    GraphNodeEvidence(
      entryId: entryId,
      observedAt: DateTime.utc(2026),
      confidence: .9,
      excerpt: excerpt,
      startUtf16: 0,
      endUtf16: excerpt.length,
    );
