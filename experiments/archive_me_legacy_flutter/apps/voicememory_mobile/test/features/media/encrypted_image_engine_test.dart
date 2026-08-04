import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/features/media/encrypted_image_engine.dart';
import 'package:voicememory_mobile/features/media/media_attachment.dart';
import 'package:voicememory_mobile/features/media/media_picker_gateway.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/local_storage/encrypted_storage_engine.dart';
import 'package:voicememory_mobile/services/security/biometric_vault_service.dart';

void main() {
  late Directory root;
  late BiometricVaultService vault;
  late EncryptedImageEngine engine;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('encrypted-media-test-');
    vault = await _unlockedVault();
    engine = EncryptedImageEngine(
      storageDirectory: Directory('${root.path}/media'),
      vault: vault,
      idFactory: () => 'attachment-1',
      clock: () => DateTime.utc(2026, 7, 27),
    );
  });

  tearDown(() async {
    vault.dispose();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test(
    'encrypted JPEG and thumbnail roundtrip entirely through memory',
    () async {
      final source = File('${root.path}/gallery.png');
      await source.writeAsBytes(_testPng());

      final attachment = await engine.importPickedSource(
        PickedMediaSource(
          path: source.path,
          cleanupOwnership: MediaSourceCleanupOwnership.externalOriginal,
        ),
      );

      expect(await source.exists(), isTrue);
      expect(await File(attachment.encryptedFilePath).exists(), isTrue);
      expect(await File(attachment.encryptedThumbnailPath).exists(), isTrue);
      expect(
        await File(attachment.encryptedFilePath).readAsString(),
        isNot(contains('PNG')),
      );

      Uint8List? retained;
      final dimensions = await engine.withDecryptedFullImage(attachment, (
        bytes,
      ) async {
        retained = bytes;
        final decoded = image.decodeJpg(bytes);
        return (decoded!.width, decoded.height);
      });
      expect(dimensions, (8, 4));
      expect(retained, everyElement(0));

      await engine.withDecryptedThumbnail(attachment, (bytes) async {
        expect(image.decodeJpg(bytes), isNotNull);
      });
    },
  );

  test('rejects an incorrect hash and an incorrect vault key', () async {
    final source = File('${root.path}/gallery.png');
    await source.writeAsBytes(_testPng());
    final attachment = await engine.importPickedSource(
      PickedMediaSource(
        path: source.path,
        cleanupOwnership: MediaSourceCleanupOwnership.externalOriginal,
      ),
    );
    final badHash = _attachmentWith(attachment, encryptedFileSha256: '0' * 64);

    await expectLater(
      engine.withDecryptedFullImage(badHash, (_) async {}),
      throwsA(isA<EncryptedImageException>()),
    );

    final wrongVault = await _unlockedVault();
    addTearDown(wrongVault.dispose);
    final wrongKeyEngine = EncryptedImageEngine(
      storageDirectory: Directory('${root.path}/media'),
      vault: wrongVault,
    );
    await expectLater(
      wrongKeyEngine.withDecryptedFullImage(attachment, (_) async {}),
      throwsA(isA<EncryptedStorageException>()),
    );
  });

  test('always deletes app-owned picker temp sources', () async {
    final source = File('${root.path}/camera-temp.png');
    await source.writeAsBytes(_testPng());

    await engine.importPickedSource(
      PickedMediaSource(
        path: source.path,
        cleanupOwnership: MediaSourceCleanupOwnership.appOwnedTemporary,
      ),
    );

    expect(await source.exists(), isFalse);
  });

  test('deletes app-owned picker temp sources when import fails', () async {
    final source = File('${root.path}/broken-camera-temp.jpg');
    await source.writeAsBytes([1, 2, 3, 4]);

    await expectLater(
      engine.importPickedSource(
        PickedMediaSource(
          path: source.path,
          cleanupOwnership: MediaSourceCleanupOwnership.appOwnedTemporary,
        ),
      ),
      throwsA(isA<EncryptedImageException>()),
    );

    expect(await source.exists(), isFalse);
  });

  test('deletes both encrypted variants', () async {
    final source = File('${root.path}/gallery.png');
    await source.writeAsBytes(_testPng());
    final attachment = await engine.importPickedSource(
      PickedMediaSource(
        path: source.path,
        cleanupOwnership: MediaSourceCleanupOwnership.externalOriginal,
      ),
    );

    await engine.delete(attachment);

    expect(await File(attachment.encryptedFilePath).exists(), isFalse);
    expect(await File(attachment.encryptedThumbnailPath).exists(), isFalse);
    expect(await source.exists(), isTrue);
  });

  test('journal and graph media arrays are immutable and JSON-compatible', () {
    final attachment = MediaAttachment(
      id: 'media-1',
      kind: MediaAttachmentKind.image,
      localPath: '/vault/full',
      mimeType: 'image/jpeg',
      fileSize: 2048,
      encryptedHash: 'a',
      caption: 'Summer project board',
      encryptedThumbnailPath: '/vault/thumb',
      encryptedThumbnailSha256: 'b',
      width: 8,
      height: 4,
      createdAt: DateTime.utc(2026, 7, 27),
    );
    final entry = JournalEntry(
      id: 'entry-1',
      createdAt: DateTime.utc(2026, 7, 27),
      transcript: '',
      durationSeconds: 0,
      reflection: const Reflection(
        mood: '',
        emotionalIntensity: 0,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
      mediaAttachments: [attachment],
    );
    final node = GraphNode(
      type: NodeType.memory,
      label: 'Memory',
      confidence: 0.8,
      mediaAttachments: [attachment],
    );

    expect(
      JournalEntry.fromJson(entry.toJson()).mediaAttachments.single.id,
      'media-1',
    );
    expect(
      JournalEntry.fromJson(entry.toJson()).mediaAttachments.single.caption,
      'Summer project board',
    );
    expect(attachment.toJson()['fileSize'], 2048);
    expect(attachment.toJson()['encryptedHash'], 'a');
    expect(
      GraphNode.fromJson(node.toJson()).mediaAttachments.single.id,
      'media-1',
    );
    expect(
      () => entry.mediaAttachments.add(attachment),
      throwsUnsupportedError,
    );
    expect(node.withoutMediaAttachment('media-1').mediaAttachments, isEmpty);
    expect(JournalEntry.fromJson(const {}).mediaAttachments, isEmpty);
    expect(
      GraphNode.fromJson(
        node.toJson()..remove('mediaAttachments'),
      ).mediaAttachments,
      isEmpty,
    );
  });
}

Future<BiometricVaultService> _unlockedVault() async {
  final vault = BiometricVaultService(
    store: MemoryBiometricVaultSecureStore(),
    authenticator: _AlwaysAuthenticate(),
  );
  await vault.initialize();
  expect(await vault.enable(), isTrue);
  return vault;
}

Uint8List _testPng() {
  final testImage = image.Image(width: 8, height: 4);
  image.fill(testImage, color: image.ColorRgb8(20, 80, 160));
  return Uint8List.fromList(image.encodePng(testImage));
}

MediaAttachment _attachmentWith(
  MediaAttachment source, {
  required String encryptedFileSha256,
}) {
  return MediaAttachment(
    id: source.id,
    kind: source.kind,
    encryptedFilePath: source.encryptedFilePath,
    encryptedThumbnailPath: source.encryptedThumbnailPath,
    encryptedFileSha256: encryptedFileSha256,
    encryptedThumbnailSha256: source.encryptedThumbnailSha256,
    width: source.width,
    height: source.height,
    createdAt: source.createdAt,
    mimeType: source.mimeType,
  );
}

class _AlwaysAuthenticate implements VaultDeviceAuthenticator {
  @override
  Future<bool> authenticate(String reason) async => true;
}
