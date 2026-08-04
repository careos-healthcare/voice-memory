import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/features/life_os_export/personal_life_os_export_service.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';

void main() {
  final exportedAt = DateTime.utc(2026, 7, 23, 14, 30);

  group('PersonalLifeOsExportService autobiography', () {
    test(
      'produces deterministic ordered Markdown with exact citations',
      () async {
        final hiddenTail =
            'FULL-UNCAPPED-TRANSCRIPT AUDIO_PATH SYNC_ACCOUNT_DATA';
        final graph = PersonalKnowledgeGraph(
          nodes: [
            _chapterNode(
              id: 'university',
              label: 'University',
              evidence: [
                _evidence('uni-2', '2020-06-01', 'University graduation.'),
                _evidence('uni-1', '2018-09-01', 'Started university.'),
              ],
            ),
            _chapterNode(
              id: 'job',
              label: 'Job',
              evidence: [
                _evidence(
                  'job-2',
                  '2017-02-01',
                  '${List.filled(180, 'A').join()}$hiddenTail',
                  confidence: 0.7,
                ),
                _evidence(
                  'job-1',
                  '2017-01-01',
                  r'A *private* [work] #chapter.',
                  confidence: 0.8,
                ),
              ],
            ),
          ],
        );
        final service = _serviceReturning(graph);

        final first = await service.buildAutobiography([
          _privateEntry(),
        ], exportedAt: exportedAt);
        final second = await service.buildAutobiography([
          _privateEntry(),
        ], exportedAt: exportedAt);

        expect(first.contents, second.contents);
        expect(first.kind, LifeOsExportKind.autobiography);
        expect(first.filename, 'archiveme-life-story-2026-07-23.md');
        expect(first.mimeType, 'text/markdown');
        expect(first.contents, startsWith('# ArchiveMe Life Story\n'));
        expect(first.contents, contains('Generated (UTC): 2026-07-23'));
        expect(first.contents, contains('Chapter count: 2'));
        expect(first.contents, contains('### Evidence-backed narrative'));
        expect(
          first.contents.indexOf('## Job'),
          lessThan(first.contents.indexOf('## University')),
        );
        expect(first.contents, contains(r'A \*private\* \[work\] \#chapter\.'));
        expect(
          first.contents,
          contains(
            r'entryId: job\-1; observedAt: 2017-01-01T00:00:00.000Z; '
            'confidence: 0.8',
          ),
        );
        expect(
          first.contents.indexOf(r'entryId: job\-1'),
          lessThan(first.contents.indexOf(r'entryId: job\-2')),
        );
        expect(first.contents, isNot(contains(hiddenTail)));
        expect(first.contents, isNot(contains('/private/audio/source.m4a')));
        expect(first.contents, isNot(contains('pendingUpload')));
        expect(first.contents, contains('Review before sharing'));
      },
    );

    test('produces a valid empty-story section', () async {
      final artifact = await _serviceReturning(
        PersonalKnowledgeGraph(),
      ).buildAutobiography(const [], exportedAt: exportedAt);

      expect(artifact.contents, contains('Chapter count: 0'));
      expect(
        artifact.contents,
        contains('## Your story is still taking shape'),
      );
      expect(artifact.contents, contains('Review before sharing'));
    });
  });

  group('PersonalLifeOsExportService knowledge graph', () {
    test('produces clean deterministic sorted portable JSON', () async {
      final graph = PersonalKnowledgeGraph(
        schemaVersion: 3,
        nodes: [
          GraphNode(
            id: 'node-z',
            type: NodeType.goal,
            label: 'Goal',
            confidence: 0.9,
            evidence: [
              _evidence('entry-b', '2026-02-01', 'Later evidence'),
              _evidence('entry-a', '2026-01-01', 'Earlier evidence'),
            ],
          ),
          GraphNode(
            id: 'node-a',
            type: NodeType.person,
            label: 'Alex',
            confidence: 0.8,
            evidence: [_evidence('entry-c', '2026-03-01', 'Met Alex')],
          ),
        ],
        edges: [
          GraphEdge(
            id: 'edge-z',
            sourceNodeId: 'node-z',
            targetNodeId: 'node-a',
            type: EdgeType.influences,
            isDirected: true,
            weight: 0.7,
            evidence: [
              _edgeEvidence('edge-b', '2026-04-02', 'Later edge'),
              _edgeEvidence('edge-a', '2026-04-01', 'Earlier edge'),
            ],
          ),
          GraphEdge(
            id: 'edge-a',
            sourceNodeId: 'node-a',
            targetNodeId: 'node-z',
            type: EdgeType.associatedWith,
            isDirected: false,
            weight: 0.6,
          ),
        ],
      );
      final service = _serviceReturning(graph);

      final first = await service.buildKnowledgeGraphPackage([
        _privateEntry(),
      ], exportedAt: exportedAt);
      final second = await service.buildKnowledgeGraphPackage([
        _privateEntry(),
      ], exportedAt: exportedAt);
      final envelope = Map<String, dynamic>.from(
        jsonDecode(first.contents) as Map,
      );
      final portableGraph = Map<String, dynamic>.from(envelope['graph'] as Map);
      final roundTrip = PersonalKnowledgeGraph.fromJson(portableGraph);
      final nodes = portableGraph['nodes'] as List;
      final edges = portableGraph['edges'] as List;

      expect(first.contents, second.contents);
      expect(first.filename, 'archiveme-knowledge-graph-2026-07-23.json');
      expect(first.mimeType, 'application/json');
      expect(envelope.keys, [
        'product',
        'format',
        'version',
        'exportedAt',
        'graph',
      ]);
      expect(envelope['product'], 'ArchiveMe');
      expect(envelope['exportedAt'], '2026-07-23T14:30:00.000Z');
      expect(portableGraph.keys, ['schemaVersion', 'nodes', 'edges']);
      expect(roundTrip.schemaVersion, 3);
      expect(roundTrip.nodes.map((node) => node.id), ['node-a', 'node-z']);
      expect(roundTrip.edges.map((edge) => edge.id), ['edge-a', 'edge-z']);
      expect(roundTrip.nodes.last.evidence.map((item) => item.entryId), [
        'entry-a',
        'entry-b',
      ]);
      expect(roundTrip.edges.last.evidence.map((item) => item.entryId), [
        'edge-a',
        'edge-b',
      ]);
      expect((nodes.first as Map)['id'], 'node-a');
      expect((edges.first as Map)['id'], 'edge-a');
      _expectNoForbiddenKeys(envelope);
      expect(first.contents, isNot(contains('/private/audio/source.m4a')));
      expect(first.contents, isNot(contains('private full transcript')));
      expect(first.contents, isNot(contains('pendingUpload')));
    });
  });

  group('Life OS export authorization', () {
    test('locked state rejects before graph building', () async {
      var builds = 0;
      final service = PersonalLifeOsExportService(
        authorization: ForegroundUnlockedLifeOsExportAuthorization(
          lifecycleState: () => AppLifecycleState.resumed,
          isLocked: () async => true,
        ),
        graphBuilder: (_) {
          builds++;
          return PersonalKnowledgeGraph();
        },
      );

      await expectLater(
        service.buildKnowledgeGraphPackage(const [], exportedAt: exportedAt),
        throwsA(isA<LifeOsExportAuthorizationException>()),
      );
      expect(builds, 0);
    });

    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.detached,
    ]) {
      test('$state rejects before graph building', () async {
        var builds = 0;
        final service = PersonalLifeOsExportService(
          authorization: ForegroundUnlockedLifeOsExportAuthorization(
            lifecycleState: () => state,
            isLocked: () async => false,
          ),
          graphBuilder: (_) {
            builds++;
            return PersonalKnowledgeGraph();
          },
        );

        await expectLater(
          service.buildKnowledgeGraphPackage(const [], exportedAt: exportedAt),
          throwsA(isA<LifeOsExportAuthorizationException>()),
        );
        expect(builds, 0);
      });
    }

    test('foreground unlocked state allows serialization', () async {
      var builds = 0;
      final service = PersonalLifeOsExportService(
        authorization: ForegroundUnlockedLifeOsExportAuthorization(
          lifecycleState: () => AppLifecycleState.resumed,
          isLocked: () async => false,
        ),
        graphBuilder: (_) {
          builds++;
          return PersonalKnowledgeGraph();
        },
      );

      final artifact = await service.buildKnowledgeGraphPackage(
        const [],
        exportedAt: exportedAt,
      );

      expect(builds, 1);
      expect(jsonDecode(artifact.contents), isA<Map<String, dynamic>>());
    });
  });
}

PersonalLifeOsExportService _serviceReturning(PersonalKnowledgeGraph graph) =>
    PersonalLifeOsExportService(
      authorization: _AllowAuthorization(),
      graphBuilder: (_) => graph,
    );

GraphNode _chapterNode({
  required String id,
  required String label,
  required List<GraphNodeEvidence> evidence,
}) => GraphNode(
  id: id,
  type: NodeType.chapter,
  label: label,
  confidence: 0.9,
  evidence: evidence,
);

GraphNodeEvidence _evidence(
  String id,
  String date,
  String excerpt, {
  double confidence = 0.9,
}) => GraphNodeEvidence(
  entryId: id,
  observedAt: DateTime.parse('${date}T00:00:00Z'),
  confidence: confidence,
  excerpt: excerpt,
);

GraphEdgeEvidence _edgeEvidence(String id, String date, String excerpt) =>
    GraphEdgeEvidence(
      entryId: id,
      observedAt: DateTime.parse('${date}T00:00:00Z'),
      confidence: 0.8,
      excerpt: excerpt,
    );

JournalEntry _privateEntry() => JournalEntry(
  id: 'private-entry',
  createdAt: DateTime.utc(2026, 7, 1),
  transcript: 'private full transcript',
  durationSeconds: 42,
  localAudioPath: '/private/audio/source.m4a',
  reflection: const Reflection(
    mood: 'private',
    emotionalIntensity: 4,
    recurringThemes: ['private'],
    exactLanguagePattern: 'private',
    concreteObservation: 'private',
    repeatedSignal: 'private',
  ),
  syncStatus: SyncStatus.pendingUpload,
);

void _expectNoForbiddenKeys(Object? value) {
  const forbidden = {
    'v',
    'n',
    'c',
    'm',
    'ciphertext',
    'nonce',
    'mac',
    'key',
    'transcript',
    'localAudioPath',
    'syncStatus',
    'account',
    'analytics',
  };
  if (value is Map) {
    for (final entry in value.entries) {
      expect(forbidden, isNot(contains(entry.key)));
      _expectNoForbiddenKeys(entry.value);
    }
  } else if (value is Iterable) {
    for (final item in value) {
      _expectNoForbiddenKeys(item);
    }
  }
}

class _AllowAuthorization implements LifeOsExportAuthorization {
  @override
  Future<void> authorize() async {}
}
