import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph_store.dart';
import 'package:voicememory_mobile/features/memory_graph/models/manual_graph_models.dart';
import 'package:voicememory_mobile/features/memory_graph/models/manual_graph_service.dart';
import 'package:voicememory_mobile/features/memory_graph/ui/manual_node_sheet.dart';
import 'package:voicememory_mobile/features/media/media_attachment.dart';
import 'package:voicememory_mobile/features/media/encrypted_image_engine.dart';
import 'package:voicememory_mobile/features/media/media_picker_gateway.dart';
import 'package:voicememory_mobile/services/ai/local_semantic_store.dart';
import 'package:voicememory_mobile/services/security/biometric_vault_service.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';
import 'package:voicememory_mobile/ui/screens/life_os/interactive_knowledge_graph_widget.dart';

void main() {
  test(
    'manual nodes and edges are locked truth anchors and survive reconcile',
    () async {
      final root = await Directory.systemTemp.createTemp('manual-graph-');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      EncryptedJsonFileStore storage(String name) => EncryptedJsonFileStore(
        file: File('${root.path}/$name.enc'),
        keyStore: InMemoryPrivateDataEncryptionKeyStore(),
      );
      final graphStore = PersonalKnowledgeGraphStore(storage: storage('graph'));
      final semanticStore = LocalSemanticStore(storage: storage('semantic'));
      final service = ManualGraphService(
        graphStore: graphStore,
        semanticStore: semanticStore,
        clock: () => DateTime.utc(2026, 7, 27),
      );
      final attachment = MediaAttachment(
        id: 'manual-photo',
        encryptedFilePath: '/private/manual-photo.full.vault',
        encryptedThumbnailPath: '/private/manual-photo.thumb.vault',
        createdAt: DateTime.utc(2026, 7, 27),
      );

      final first = await service.createNode(
        ManualNodeDraft(
          label: 'Starting Keto',
          category: ManualNodeCategory.habit,
          note: 'I chose this deliberately.',
          mediaAttachments: [attachment],
        ),
      );
      final second = await service.createNode(
        const ManualNodeDraft(
          label: 'Health',
          category: ManualNodeCategory.goal,
        ),
      );
      final edge = await service.connect(source: first, target: second);

      expect(first.origin, NodeOrigin.manual);
      expect(first.confidence, 1);
      expect(first.mediaAttachments.single.id, 'manual-photo');
      expect(edge.origin, NodeOrigin.manual);
      expect(edge.weight, 1);
      expect((await semanticStore.manualTruthAnchorsJson()), hasLength(3));
      expect(await semanticStore.search('Starting Keto'), isEmpty);
      expect((await graphStore.reconcile(const [])).nodes, hasLength(2));
    },
  );

  testWidgets('manual node sheet validates and submits a truth anchor', (
    tester,
  ) async {
    ManualNodeDraft? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ManualNodeSheet(onSave: (draft) => submitted = draft),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('manual-node-label')),
      'Starting Keto',
    );
    await tester.enterText(
      find.byKey(const Key('manual-node-note')),
      'A deliberate commitment',
    );
    await tester.tap(find.byKey(const Key('manual-node-save')));
    await tester.pump();

    expect(submitted?.label, 'Starting Keto');
    expect(submitted?.category, ManualNodeCategory.idea);
  });

  testWidgets('manual node sheet submits encrypted attachments', (
    tester,
  ) async {
    ManualNodeDraft? submitted;
    final attachment = MediaAttachment(
      id: 'sheet-photo',
      encryptedFilePath: '/private/sheet-photo.full.vault',
      encryptedThumbnailPath: '/private/sheet-photo.thumb.vault',
      createdAt: DateTime.utc(2026, 7, 27),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ManualNodeSheet(
            imageEngine: _FakeImageEngine(attachment),
            mediaPicker: _FakePicker(),
            onSave: (draft) => submitted = draft,
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('manual-node-label')),
      'A visual truth',
    );
    await tester.tap(find.byKey(const Key('media-gallery-action')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('manual-node-save')));
    await tester.pump();

    expect(submitted?.mediaAttachments.single.id, 'sheet-photo');
  });

  testWidgets('canvas long press creates a draft and drag connects nodes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final graph = _graph();
    Map<String, Offset> positions = const {};
    var draftRequested = false;
    (GraphNode, GraphNode)? connection;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InteractiveKnowledgeGraphWidget(
            graph: graph,
            height: 520,
            onLayoutComputed: (_, value) => positions = value,
            onEmptySpaceLongPress: (_) => draftRequested = true,
            onManualConnection: (source, target) {
              connection = (source, target);
            },
          ),
        ),
      ),
    );
    await tester.pump();
    final canvas = find.byKey(const Key('interactive-knowledge-graph-canvas'));
    final topLeft = tester.getTopLeft(canvas);

    await tester.longPressAt(topLeft + const Offset(700, 480));
    await tester.pump();
    expect(draftRequested, isTrue);

    final source = topLeft + positions['node-a']!;
    final target = topLeft + positions['node-b']!;
    final gesture = await tester.startGesture(source);
    await gesture.moveTo(target);
    await tester.pump();
    expect(find.byKey(const Key('manual-edge-preview')), findsOneWidget);
    await gesture.up();
    await tester.pump();
    expect(connection?.$1.id, 'node-a');
    expect(connection?.$2.id, 'node-b');
  });
}

PersonalKnowledgeGraph _graph() {
  final observedAt = DateTime.utc(2026, 7, 27);
  GraphNode node(String id, String label) => GraphNode(
    id: id,
    type: NodeType.topic,
    label: label,
    confidence: .7,
    evidence: [
      GraphNodeEvidence(
        entryId: 'entry-$id',
        observedAt: observedAt,
        confidence: .7,
        excerpt: label,
        startUtf16: 0,
        endUtf16: label.length,
      ),
    ],
  );
  return PersonalKnowledgeGraph(
    nodes: [node('node-a', 'Alpha'), node('node-b', 'Beta')],
  );
}

class _FakePicker implements MediaPickerGateway {
  @override
  Future<PickedMediaSource?> pickImage(MediaPickSource source) async =>
      const PickedMediaSource(
        path: '/temporary/source.png',
        cleanupOwnership: MediaSourceCleanupOwnership.externalOriginal,
      );
}

class _FakeImageEngine extends EncryptedImageEngine {
  _FakeImageEngine(this.result)
    : super(
        storageDirectory: Directory.systemTemp,
        vault: BiometricVaultService(store: MemoryBiometricVaultSecureStore()),
      );

  final MediaAttachment result;

  @override
  Future<MediaAttachment?> pickAndImport({
    required MediaPickerGateway picker,
    required MediaPickSource source,
  }) async {
    await picker.pickImage(source);
    return result;
  }

  @override
  Future<T> withDecryptedThumbnail<T>(
    MediaAttachment attachment,
    Future<T> Function(Uint8List jpegBytes) operation,
  ) => operation(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    ),
  );

  @override
  Future<void> delete(MediaAttachment attachment) async {}
}
