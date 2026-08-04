import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/features/ai_engines/models/ai_explainability.dart';
import 'package:voicememory_mobile/features/ai_engines/models/hypothesis_evolution.dart';
import 'package:voicememory_mobile/features/export_backup/markdown_export_service.dart';
import 'package:voicememory_mobile/features/media/media_attachment.dart';
import 'package:voicememory_mobile/features/semantic_clusters/semantic_cluster.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/journal_sync_metadata.dart';
import 'package:voicememory_mobile/models/reflection.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'markdown_export_test_',
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test(
    'exports structured Markdown, exact citations, and authorized media',
    () async {
      final entry = _entry();
      final evidence = GraphNodeEvidence(
        entryId: entry.id,
        observedAt: entry.createdAt,
        confidence: 1,
        excerpt: 'Exact quote',
        startUtf16: 0,
        endUtf16: 11,
      );
      final manualNode = GraphNode(
        id: 'manual-node',
        type: NodeType.belief,
        label: 'Manual *anchor*',
        confidence: 1,
        origin: NodeOrigin.manual,
        evidence: [evidence],
      );
      final otherNode = GraphNode(
        id: 'other-node',
        type: NodeType.goal,
        label: 'Resolved goal',
        confidence: 1,
        evidence: [evidence],
      );
      final manualEdge = GraphEdge(
        sourceNodeId: manualNode.id,
        targetNodeId: otherNode.id,
        type: EdgeType.influences,
        isDirected: true,
        weight: 1,
        origin: NodeOrigin.manual,
        evidence: [
          GraphEdgeEvidence(
            entryId: entry.id,
            observedAt: entry.createdAt,
            confidence: 1,
            excerpt: 'Exact quote',
            startUtf16: 0,
            endUtf16: 11,
          ),
        ],
      );
      final manualGraph = PersonalKnowledgeGraph(
        nodes: [manualNode],
        edges: [manualEdge],
      );
      final graph = PersonalKnowledgeGraph(nodes: [otherNode]);
      final hypothesis = HypothesisEvolution(
        theoryId: 'theory-1',
        statement: 'A <careful> hypothesis',
        evolutionHistory: [
          ConfidenceSnapshot(
            date: DateTime.utc(2026, 1, 3),
            confidenceScore: 65,
            triggeringEvidence: const VerifiableCitation(
              sourceEntryId: 'entry-1',
              exactQuote: 'Exact quote',
              confidenceScore: 1,
              startUtf16: 0,
              endUtf16: 11,
            ),
            deltaReasoning: 'Because *this* was observed.',
          ),
          ConfidenceSnapshot(
            date: DateTime.utc(2026, 1, 4),
            confidenceScore: 70,
            triggeringEvidence: const VerifiableCitation(
              sourceEntryId: 'entry-1',
              exactQuote: 'Invented citation',
              confidenceScore: 1,
              startUtf16: 0,
              endUtf16: 17,
            ),
            deltaReasoning: 'This citation must be omitted.',
          ),
        ],
      );
      final cluster = SemanticCluster(
        id: 'cluster-1',
        title: 'Cluster [title]',
        category: SemanticClusterCategory.theme,
        nodeIds: [manualNode.id, otherNode.id],
        activityVelocity: 0.5,
        confidenceScore: 0.8,
        summary: '<script>alert(1)</script>',
      );
      final authorization = _Authorization(true);
      final attachmentSource = _AttachmentSource();
      Map<String, Uint8List>? exported;
      var sharedPath = '';
      final service = MarkdownExportService(
        loadEntries: () async => [entry],
        loadManualGraph: () async => manualGraph,
        loadActiveHypotheses: () async => [hypothesis],
        loadSemanticClusters: () async => [cluster],
        loadKnowledgeGraph: () async => graph,
        authorization: authorization,
        attachmentSource: attachmentSource,
        temporaryDirectory: () async => temporaryDirectory,
        clock: () => DateTime.utc(2026, 7, 27),
        share: (path) async {
          sharedPath = path;
          exported = _decodeZip(await File(path).readAsBytes());
        },
      );

      final result = await service.export(explicitUserAction: true);

      expect(result.succeeded, isTrue);
      expect(result.entryCount, 1);
      expect(authorization.calls, 1);
      expect(sharedPath, endsWith('.zip'));
      expect(
        exported!.keys,
        containsAll(<String>[
          'index.md',
          'entries/2026-01-02-0001.md',
          'truth-anchors.md',
          'semantic-clusters.md',
          'confidence-history.md',
          'media/audio-1.m4a',
          'media/image-2.png',
        ]),
      );

      final entryMarkdown = String.fromCharCodes(
        exported!['entries/2026-01-02-0001.md']!,
      );
      expect(entryMarkdown, contains('Exact quote and a full transcript.'));
      expect(entryMarkdown, contains(r'\# heading'));
      expect(entryMarkdown, contains('Reflection &lt;summary&gt;'));
      expect(
        entryMarkdown,
        contains('[Audio recording](../media/audio-1.m4a)'),
      );
      expect(entryMarkdown, contains('![Caption \\[safe\\]]'));

      final anchors = String.fromCharCodes(exported!['truth-anchors.md']!);
      expect(anchors, contains(r'Manual \*anchor\*'));
      expect(anchors, contains('Resolved goal'));
      expect(anchors, contains('Exact quote'));

      final clusters = String.fromCharCodes(exported!['semantic-clusters.md']!);
      expect(clusters, contains('Manual \\*anchor\\*'));
      expect(clusters, contains('Resolved goal'));
      expect(clusters, contains('&lt;script&gt;alert(1)&lt;/script&gt;'));

      final confidence = String.fromCharCodes(
        exported!['confidence-history.md']!,
      );
      expect(confidence, contains('Exact quote'));
      expect(confidence, isNot(contains('Invented citation')));
      expect(await temporaryDirectory.list().toList(), isEmpty);
      expect(attachmentSource.returnedBytes.every((byte) => byte == 0), isTrue);
    },
  );

  test(
    'uses safe filenames and excludes paths, IDs, tokens, keys, embeddings',
    () async {
      final entry = _entry(
        id: '../../Users/device-id',
        localAudioPath: '/Users/private/device/audio-secret.m4a',
        attachmentPath: '../../keys/master-key.bin',
      );
      Map<String, Uint8List>? exported;
      final service = _service(
        temporaryDirectory,
        entries: [entry],
        share: (path) async {
          exported = _decodeZip(await File(path).readAsBytes());
        },
      );

      final result = await service.export(explicitUserAction: true);

      expect(result.succeeded, isTrue);
      expect(
        exported!.keys.every(
          (name) =>
              !name.startsWith('/') &&
              !name.split('/').contains('..') &&
              !name.contains('device-id'),
        ),
        isTrue,
      );
      final allText = exported!.entries
          .where((item) => item.key.endsWith('.md'))
          .map((item) => String.fromCharCodes(item.value))
          .join('\n');
      expect(allText, isNot(contains('/Users/private')));
      expect(allText, isNot(contains('master-key')));
      expect(allText, isNot(contains('device-id')));
      expect(allText, isNot(contains('sync-token')));
      expect(allText, isNot(contains('embedding')));
    },
  );

  test(
    'does no work without explicit action or when biometric is denied',
    () async {
      var loads = 0;
      var shares = 0;
      final denied = _Authorization(false);
      final service = MarkdownExportService(
        loadEntries: () async {
          loads++;
          return [];
        },
        loadManualGraph: () async => PersonalKnowledgeGraph(),
        loadActiveHypotheses: () async => [],
        loadSemanticClusters: () async => [],
        loadKnowledgeGraph: () async => PersonalKnowledgeGraph(),
        authorization: denied,
        temporaryDirectory: () async => temporaryDirectory,
        share: (_) async => shares++,
      );

      final notExplicit = await service.export(explicitUserAction: false);
      expect(
        notExplicit.failure,
        MarkdownExportFailure.explicitUserActionRequired,
      );
      expect(denied.calls, 0);

      final biometricDenied = await service.export(explicitUserAction: true);
      expect(biometricDenied.failure, MarkdownExportFailure.biometricDenied);
      expect(denied.calls, 1);
      expect(loads, 0);
      expect(shares, 0);
      expect(await temporaryDirectory.list().toList(), isEmpty);
    },
  );

  test(
    'shares once and securely cleans plaintext after share errors',
    () async {
      var shares = 0;
      final service = _service(
        temporaryDirectory,
        entries: [_entry()],
        share: (path) async {
          shares++;
          expect(await File(path).exists(), isTrue);
          throw StateError('share failed');
        },
      );

      final result = await service.export(explicitUserAction: true);

      expect(result.failure, MarkdownExportFailure.exportFailed);
      expect(shares, 1);
      expect(await temporaryDirectory.list().toList(), isEmpty);
    },
  );

  test('omits media links when attachment bytes are unavailable', () async {
    Map<String, Uint8List>? exported;
    final service = MarkdownExportService(
      loadEntries: () async => [_entry()],
      loadManualGraph: () async => PersonalKnowledgeGraph(),
      loadActiveHypotheses: () async => [],
      loadSemanticClusters: () async => [],
      loadKnowledgeGraph: () async => PersonalKnowledgeGraph(),
      authorization: _Authorization(true),
      attachmentSource: _NullAttachmentSource(),
      temporaryDirectory: () async => temporaryDirectory,
      share: (path) async {
        exported = _decodeZip(await File(path).readAsBytes());
      },
    );

    expect((await service.export(explicitUserAction: true)).succeeded, isTrue);
    final markdown = utf8.decode(exported!['entries/2026-01-02-0001.md']!);
    expect(markdown, isNot(contains('../media/')));
    expect(exported!.keys.where((path) => path.startsWith('media/')), isEmpty);
  });
}

MarkdownExportService _service(
  Directory temporaryDirectory, {
  required List<JournalEntry> entries,
  required MarkdownExportShare share,
}) => MarkdownExportService(
  loadEntries: () async => entries,
  loadManualGraph: () async => PersonalKnowledgeGraph(),
  loadActiveHypotheses: () async => [],
  loadSemanticClusters: () async => [],
  loadKnowledgeGraph: () async => PersonalKnowledgeGraph(),
  authorization: _Authorization(true),
  temporaryDirectory: () async => temporaryDirectory,
  share: share,
);

JournalEntry _entry({
  String id = 'entry-1',
  String? localAudioPath,
  String localAudioVaultRef = 'av1:authorized-audio.m4a.enc',
  String attachmentPath = '/private/image.enc',
}) => JournalEntry(
  id: id,
  createdAt: DateTime.utc(2026, 1, 2, 3, 4),
  transcript: 'Exact quote and a full transcript.\n# heading',
  durationSeconds: 42,
  localAudioPath: localAudioPath,
  localAudioVaultRef: localAudioVaultRef,
  reflection: const Reflection(
    mood: 'calm',
    emotionalIntensity: 4,
    recurringThemes: ['Theme *one*'],
    exactLanguagePattern: 'Exact quote',
    concreteObservation: 'Reflection <summary>',
    repeatedSignal: 'A repeated [signal].',
  ),
  syncMetadata: JournalSyncMetadata(
    updatedAt: DateTime.utc(2026, 1, 2),
    sourceDeviceId: 'device-id',
  ),
  mediaAttachments: [
    MediaAttachment(
      id: 'image-id',
      localPath: attachmentPath,
      mimeType: 'image/png',
      caption: 'Caption [safe]',
      createdAt: DateTime.utc(2026, 1, 2),
    ),
  ],
);

Map<String, Uint8List> _decodeZip(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes, verify: true);
  return {
    for (final file in archive.files)
      if (file.isFile) file.name: Uint8List.fromList(file.content as List<int>),
  };
}

final class _Authorization implements MarkdownExportAuthorization {
  _Authorization(this.allowed);

  final bool allowed;
  int calls = 0;

  @override
  Future<bool> reauthenticate() async {
    calls++;
    return allowed;
  }
}

final class _AttachmentSource implements AttachmentExportSource {
  final returnedBytes = Uint8List.fromList([1, 2, 3]);

  @override
  Future<Uint8List?> loadAuthorizedPlaintext(
    AttachmentExportRequest request,
  ) async {
    if (request.kind == AttachmentExportKind.audio) {
      return returnedBytes;
    }
    return Uint8List.fromList([4, 5, 6]);
  }
}

final class _NullAttachmentSource implements AttachmentExportSource {
  @override
  Future<Uint8List?> loadAuthorizedPlaintext(
    AttachmentExportRequest request,
  ) async => null;
}
