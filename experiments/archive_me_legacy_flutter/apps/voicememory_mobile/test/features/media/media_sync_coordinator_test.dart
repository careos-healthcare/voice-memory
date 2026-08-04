import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph_store.dart';
import 'package:voicememory_mobile/features/media/encrypted_image_engine.dart';
import 'package:voicememory_mobile/features/media/media_attachment.dart';
import 'package:voicememory_mobile/features/media/media_picker_gateway.dart';
import 'package:voicememory_mobile/features/media/media_sync_coordinator.dart';
import 'package:voicememory_mobile/features/sync/e2ee_sync_models.dart';
import 'package:voicememory_mobile/features/sync/encrypted_sync_engine.dart';
import 'package:voicememory_mobile/features/sync/sync_outbox.dart';
import 'package:voicememory_mobile/services/ai/local_semantic_store.dart';
import 'package:voicememory_mobile/services/security/biometric_vault_service.dart';
import 'package:voicememory_mobile/services/security/sync_identity_service.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  late Directory root;
  late _SyncHarness sender;
  late BiometricVaultService senderVault;
  late BiometricVaultService receiverVault;
  late EncryptedImageEngine senderImages;
  late EncryptedImageEngine receiverImages;
  late MediaAttachment sourceAttachment;
  late List<CrdtOperation> operations;
  late Uint8List expectedJpeg;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('media-crdt-test-');
    sender = await _syncHarness(root);
    senderVault = await _unlockedVault();
    receiverVault = await _unlockedVault();
    senderImages = EncryptedImageEngine(
      storageDirectory: Directory('${root.path}/sender-media'),
      vault: senderVault,
      idFactory: () => 'attachment-1',
      clock: () => DateTime.utc(2026, 7, 27),
    );
    receiverImages = EncryptedImageEngine(
      storageDirectory: Directory('${root.path}/receiver-media'),
      vault: receiverVault,
    );
    final source = File('${root.path}/source.png');
    await source.writeAsBytes(_testPng());
    sourceAttachment = await senderImages.importPickedSource(
      PickedMediaSource(
        path: source.path,
        cleanupOwnership: MediaSourceCleanupOwnership.externalOriginal,
      ),
    );
    expectedJpeg = await senderImages.withDecryptedFullImage(
      sourceAttachment,
      (bytes) async => Uint8List.fromList(bytes),
    );
    final coordinator = MediaSyncCoordinator(
      syncEngine: sender.engine,
      imageEngine: senderImages,
      chunkSize: 1024,
    );
    await coordinator.enqueueAttachment(
      journalEntryId: 'entry-1',
      attachment: sourceAttachment,
    );
    final key = await sender.identity.requireKey();
    try {
      operations = await sender.outbox.pending(key: key, limit: 1000);
    } finally {
      key.destroy();
    }
  });

  tearDown(() async {
    expectedJpeg.fillRange(0, expectedJpeg.length, 0);
    senderVault.dispose();
    receiverVault.dispose();
    await sender.dispose();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('chunks at the limit and keeps paths and chunks out of heads', () async {
    final manifest = operations.singleWhere(
      (item) => item.entityKind == CrdtEntityKind.mediaManifest,
    );
    final chunks = operations
        .where((item) => item.entityKind == CrdtEntityKind.mediaChunk)
        .toList();

    expect(manifest.payload.toString(), isNot(contains(root.path)));
    expect(manifest.payload.keys, isNot(contains('localPath')));
    expect(manifest.payload.keys, isNot(contains('encryptedFilePath')));
    expect(chunks, hasLength(manifest.payload['chunkCount'] as int));
    for (final chunk in chunks) {
      expect(
        base64Decode(chunk.payload['bytes'] as String).length,
        lessThanOrEqualTo(1024),
      );
    }

    final key = await sender.identity.requireKey();
    try {
      final heads = await sender.outbox.heads(key: key);
      expect(heads.keys.where((key) => key.startsWith('mediaChunk:')), isEmpty);
      expect(heads, contains('mediaManifest:attachment-1'));
    } finally {
      key.destroy();
    }
  });

  test(
    'accepts duplicate out-of-order chunks and re-encrypts result',
    () async {
      String? linkedEntryId;
      MediaAttachment? linkedAttachment;
      final assembler = MediaSyncAssembler(
        imageEngine: receiverImages,
        onImported: (ownerKind, ownerId, attachment) async {
          expect(ownerKind, 'journalEntry');
          linkedEntryId = ownerId;
          linkedAttachment = attachment;
        },
      );
      final manifest = operations.singleWhere(
        (item) => item.entityKind == CrdtEntityKind.mediaManifest,
      );
      final chunks = operations
          .where((item) => item.entityKind == CrdtEntityKind.mediaChunk)
          .toList()
          .reversed
          .toList();

      await assembler.apply(chunks.first);
      await assembler.apply(chunks.first);
      for (final chunk in chunks.skip(1)) {
        await assembler.apply(chunk);
      }
      final imported = await assembler.apply(manifest);

      expect(imported, isNotNull);
      expect(linkedEntryId, 'entry-1');
      expect(linkedAttachment?.id, sourceAttachment.id);
      await receiverImages.withDecryptedFullImage(imported!, (bytes) async {
        expect(bytes, expectedJpeg);
      });
      expect(
        await File(imported.encryptedFilePath).readAsBytes(),
        isNot(await File(sourceAttachment.encryptedFilePath).readAsBytes()),
      );
    },
  );

  test('rejects corruption when the plaintext hash does not match', () async {
    final assembler = MediaSyncAssembler(imageEngine: receiverImages);
    final manifest = operations.singleWhere(
      (item) => item.entityKind == CrdtEntityKind.mediaManifest,
    );
    final chunks = operations
        .where((item) => item.entityKind == CrdtEntityKind.mediaChunk)
        .toList();
    final last = chunks.removeLast();
    final corruptBytes = base64Decode(last.payload['bytes'] as String);
    corruptBytes[0] ^= 0xff;
    final corrupt = CrdtOperation(
      id: last.id,
      deviceId: last.deviceId,
      entityKind: last.entityKind,
      entityId: last.entityId,
      mutation: last.mutation,
      vectorClock: last.vectorClock,
      timestamp: last.timestamp,
      payload: {...last.payload, 'bytes': base64Encode(corruptBytes)},
    );
    corruptBytes.fillRange(0, corruptBytes.length, 0);

    await assembler.apply(manifest);
    for (final chunk in chunks) {
      await assembler.apply(chunk);
    }
    await expectLater(
      assembler.apply(corrupt),
      throwsA(isA<MediaSyncException>()),
    );
    expect(
      await File(
        '${root.path}/receiver-media/attachment-1.full.vault',
      ).exists(),
      isFalse,
    );
  });
}

class _SyncHarness {
  const _SyncHarness({
    required this.engine,
    required this.identity,
    required this.outbox,
    required this.graphStore,
  });

  final EncryptedSyncEngine engine;
  final SyncIdentityService identity;
  final SyncOutbox outbox;
  final PersonalKnowledgeGraphStore graphStore;

  Future<void> dispose() async {
    await engine.dispose();
    await graphStore.dispose();
    outbox.close();
  }
}

Future<_SyncHarness> _syncHarness(Directory root) async {
  final identity = SyncIdentityService(store: MemorySyncIdentityStore());
  await identity.installRecoveryPhrase(
    'abandon abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon about',
  );
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
  final outbox = SyncOutbox.open(databasePath: '${root.path}/outbox.sqlite');
  final engine = EncryptedSyncEngine(
    deviceId: 'sender',
    identity: identity,
    outbox: outbox,
    transport: _UnusedRelay(),
    graphStore: graphStore,
    semanticStore: semanticStore,
    isOnline: () => false,
    clock: () => DateTime.utc(2026, 7, 27),
  );
  return _SyncHarness(
    engine: engine,
    identity: identity,
    outbox: outbox,
    graphStore: graphStore,
  );
}

class _UnusedRelay implements E2EERelayTransport {
  @override
  Future<List<E2EESyncEnvelope>> pull() async => const [];

  @override
  Future<void> push(E2EESyncEnvelope envelope) async {}
}

Future<BiometricVaultService> _unlockedVault() async {
  final vault = BiometricVaultService(
    store: MemoryBiometricVaultSecureStore(),
    authenticator: _AlwaysAuthenticate(),
  );
  await vault.initialize();
  await vault.enable();
  return vault;
}

class _AlwaysAuthenticate implements VaultDeviceAuthenticator {
  @override
  Future<bool> authenticate(String reason) async => true;
}

Uint8List _testPng() {
  final value = image.Image(width: 80, height: 40);
  for (var y = 0; y < value.height; y++) {
    for (var x = 0; x < value.width; x++) {
      value.setPixelRgb(x, y, x * 3, y * 6, (x + y) * 2);
    }
  }
  return Uint8List.fromList(image.encodePng(value));
}
