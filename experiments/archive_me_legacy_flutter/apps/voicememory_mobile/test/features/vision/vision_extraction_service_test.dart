import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph_store.dart';
import 'package:voicememory_mobile/features/media/encrypted_image_engine.dart';
import 'package:voicememory_mobile/features/media/media_attachment.dart';
import 'package:voicememory_mobile/features/vision/local_vision_ocr.dart';
import 'package:voicememory_mobile/features/vision/vision_extraction_models.dart';
import 'package:voicememory_mobile/features/vision/vision_extraction_service.dart';
import 'package:voicememory_mobile/features/vision/vision_graph_fusion_service.dart';
import 'package:voicememory_mobile/services/ai/local_semantic_store.dart';
import 'package:voicememory_mobile/services/security/biometric_vault_service.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  late Directory root;
  late BiometricVaultService vault;
  late EncryptedImageEngine imageEngine;
  late MediaAttachment attachment;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('vision-extraction-test-');
    vault = BiometricVaultService(
      store: MemoryBiometricVaultSecureStore(),
      authenticator: _AlwaysAuthenticate(),
    );
    await vault.initialize();
    expect(await vault.enable(), isTrue);
    imageEngine = EncryptedImageEngine(
      storageDirectory: Directory('${root.path}/media'),
      vault: vault,
    );
    final source = image.Image(width: 12, height: 7);
    image.fill(source, color: image.ColorRgb8(10, 20, 30));
    final jpeg = Uint8List.fromList(image.encodeJpg(source));
    attachment = await imageEngine.importBytes(
      jpeg,
      attachmentId: 'photo-1',
      createdAt: DateTime.utc(2026, 7, 27),
    );
    jpeg.fillRange(0, jpeg.length, 0);
  });

  tearDown(() async {
    vault.dispose();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('strictly parses backend vision contract', () {
    final extraction = VisionExtraction.fromJson(_cloudJson());
    expect(extraction.sceneSummary, 'A notebook on a desk.');
    expect(extraction.entities.first.kind, VisionEntityKind.object);
    expect(extraction.relationships.single.confidence, 0.6);

    expect(
      () => VisionExtraction.fromJson({..._cloudJson(), 'extra': true}),
      throwsFormatException,
    );
    expect(
      () => VisionExtraction.fromJson({
        ..._cloudJson(),
        'relationships': [
          {
            'source': 'unknown',
            'target': 'Desk',
            'relationship': 'on',
            'confidence': 0.6,
          },
        ],
      }),
      throwsFormatException,
    );
  });

  test('falls back to fake local OCR when fake cloud fails', () async {
    final local = _FakeLocalExtractor();
    final cloud = _FakeCloudExtractor(error: StateError('offline'));
    final service = VisionExtractionService(
      imageEngine: imageEngine,
      localExtractor: local,
      cloudExtractor: cloud,
    );

    final result = await service.extract(attachment);

    expect(local.calls, 1);
    expect(cloud.calls, 1);
    expect(result.usedCloud, isFalse);
    expect(result.extraction.visibleText, ['Project Atlas']);
    expect(result.local.width, 12);
    expect(cloud.retainedBytes, everyElement(0));
    expect(
      Directory(
        root.path,
      ).listSync(recursive: true).whereType<File>().map((file) => file.path),
      everyElement(endsWith('.vault')),
    );
  });

  test('fuses media graph confidence and deduplicates both stores', () async {
    final keyStore = InMemoryPrivateDataEncryptionKeyStore();
    final graphStore = PersonalKnowledgeGraphStore(
      storage: EncryptedJsonFileStore(
        file: File('${root.path}/graph.enc'),
        keyStore: keyStore,
      ),
    );
    final semanticStore = LocalSemanticStore(
      storage: EncryptedJsonFileStore(
        file: File('${root.path}/semantic.enc'),
        keyStore: keyStore,
      ),
    );
    final fusion = VisionGraphFusionService(
      graphStore: graphStore,
      semanticStore: semanticStore,
    );
    final result = VisionExtractionResult(
      local: LocalVisionExtraction(
        width: 12,
        height: 7,
        mimeType: 'image/jpeg',
        visibleText: const ['Project Atlas'],
        tags: const {'vision', 'ocr'},
      ),
      extraction: VisionExtraction.fromJson(_cloudJson()),
      usedCloud: true,
    );

    final first = await fusion.fuse(attachment: attachment, result: result);
    final second = await fusion.fuse(attachment: attachment, result: result);
    final graph = await graphStore.load();

    expect(second.sourceNodeId, first.sourceNodeId);
    expect(graph.nodes.map((node) => node.id).toSet().length, 3);
    expect(graph.edges.map((edge) => edge.id).toSet().length, 3);
    final source = graph.nodes.singleWhere(
      (node) => node.id == first.sourceNodeId,
    );
    expect(source.type, NodeType.memory);
    expect(source.origin, NodeOrigin.media);
    expect(source.confidence, 1);
    expect(source.mediaAttachments.single.id, attachment.id);
    expect(
      graph.nodes
          .where((node) => node.id != source.id)
          .map((node) => node.type),
      containsAll({NodeType.object, NodeType.place}),
    );
    expect(
      graph.edges.every((edge) => edge.origin == NodeOrigin.media),
      isTrue,
    );
    expect(
      graph.edges.map((edge) => edge.weight),
      containsAll({0.6, 0.7, 0.9}),
    );
    expect(await semanticStore.count(), 1);
    final hits = await semanticStore.search(
      'notebook',
      requiredTags: const {'origin:media'},
    );
    expect(hits.single.entryId, first.sourceNodeId);
    expect(hits.single.nodeIds.toSet().length, 3);
  });
}

Map<String, dynamic> _cloudJson() => {
  'sceneSummary': 'A notebook on a desk.',
  'visibleText': ['Project Atlas'],
  'entities': [
    {'kind': 'object', 'label': 'Notebook', 'confidence': 0.9},
    {'kind': 'place', 'label': 'Desk', 'confidence': 0.7},
  ],
  'relationships': [
    {
      'source': 'Notebook',
      'target': 'Desk',
      'relationship': 'on',
      'confidence': 0.6,
    },
  ],
};

class _FakeLocalExtractor implements VisionLocalExtractor {
  int calls = 0;

  @override
  Future<LocalVisionExtraction> extract(MediaAttachment attachment) async {
    calls++;
    return LocalVisionExtraction(
      width: attachment.width,
      height: attachment.height,
      mimeType: attachment.mimeType,
      visibleText: const ['Project Atlas'],
      tags: const {'vision', 'ocr'},
    );
  }
}

class _FakeCloudExtractor implements VisionCloudExtractor {
  _FakeCloudExtractor({this.error});

  final Object? error;
  int calls = 0;
  Uint8List? retainedBytes;

  @override
  Future<VisionExtraction> extract({
    required Uint8List imageBytes,
    required String mimeType,
    required String attachmentId,
  }) async {
    calls++;
    retainedBytes = imageBytes;
    if (error case final error?) throw error;
    return VisionExtraction.fromJson(_cloudJson());
  }
}

class _AlwaysAuthenticate implements VaultDeviceAuthenticator {
  @override
  Future<bool> authenticate(String reason) async => true;
}
