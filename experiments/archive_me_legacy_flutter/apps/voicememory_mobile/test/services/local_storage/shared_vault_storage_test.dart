import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/services/local_storage/shared_vault_storage.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  late Directory directory;
  late InMemoryPrivateDataEncryptionKeyStore keyStore;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('shared-vault-test');
    keyStore = InMemoryPrivateDataEncryptionKeyStore();
    await keyStore.ensureKey();
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('encrypts extension handoffs before SQLite persistence', () async {
    final storage = await SharedVaultStorage.open(
      fallbackDirectory: directory.path,
      keyStore: keyStore,
    );
    const secret = 'private shared selection that must not appear on disk';
    await storage.enqueue(
      SharedVaultPayload(
        id: 'payload-1',
        kind: SharedPayloadKind.text,
        createdAt: DateTime.utc(2026, 7, 27),
        text: secret,
      ),
    );
    storage.checkpoint();

    expect((await storage.pending()).single.text, secret);
    await storage.close();
    final databaseBytes = await File(
      '${directory.path}/shared_vault_outbox.db',
    ).readAsBytes();
    expect(String.fromCharCodes(databaseBytes), isNot(contains(secret)));
  });

  test('serializes concurrent writers with a shared process lock', () async {
    final first = await SharedVaultStorage.open(
      fallbackDirectory: directory.path,
      keyStore: keyStore,
    );
    final second = await SharedVaultStorage.open(
      fallbackDirectory: directory.path,
      keyStore: keyStore,
    );

    await Future.wait([
      for (var index = 0; index < 24; index++)
        (index.isEven ? first : second).enqueue(
          SharedVaultPayload(
            id: 'payload-$index',
            kind: SharedPayloadKind.text,
            createdAt: DateTime.utc(2026, 7, 27, 0, index),
            text: 'encrypted payload $index',
          ),
        ),
    ]);

    expect(first.pendingCount, 24);
    expect(await first.pending(limit: 24), hasLength(24));
    await first.close();
    await second.close();
  });

  test('imports parsed native text, URL, and file handoffs', () async {
    final storage = await SharedVaultStorage.open(
      fallbackDirectory: directory.path,
      keyStore: keyStore,
    );
    final bridge = _FakePlatformBridge([
      SharedVaultPayload(
        id: 'text-1',
        kind: SharedPayloadKind.text,
        createdAt: DateTime.utc(2026, 7, 27),
        text: 'selected text',
      ),
      SharedVaultPayload(
        id: 'url-1',
        kind: SharedPayloadKind.url,
        createdAt: DateTime.utc(2026, 7, 27),
        text: 'https://example.com/private',
      ),
      SharedVaultPayload(
        id: 'image-1',
        kind: SharedPayloadKind.image,
        createdAt: DateTime.utc(2026, 7, 27),
        mimeType: 'image/jpeg',
        displayName: 'photo.jpg',
        bytes: Uint8List.fromList([1, 2, 3, 4]),
      ),
    ]);

    expect(await storage.importNativeInbox(bridge), 3);
    expect(bridge.acknowledged, hasLength(3));
    final pending = await storage.pending();
    expect(
      pending.map((payload) => payload.kind),
      containsAll([
        SharedPayloadKind.text,
        SharedPayloadKind.url,
        SharedPayloadKind.image,
      ]),
    );
    await storage.close();
  });

  test(
    'imports only remaining capacity and acknowledges persisted rows',
    () async {
      final storage = await SharedVaultStorage.open(
        fallbackDirectory: directory.path,
        keyStore: keyStore,
      );
      for (
        var index = 0;
        index < SharedVaultStorage.maxPendingPayloads - 1;
        index++
      ) {
        await storage.enqueue(
          SharedVaultPayload(
            id: 'existing-$index',
            kind: SharedPayloadKind.text,
            createdAt: DateTime.utc(2026, 7, 27, 0, index % 60),
            text: 'existing encrypted payload $index',
          ),
        );
      }
      final bridge = _FakePlatformBridge([
        SharedVaultPayload(
          id: 'native-first',
          kind: SharedPayloadKind.text,
          createdAt: DateTime.utc(2026, 7, 28),
          text: 'first native share',
        ),
        SharedVaultPayload(
          id: 'native-second',
          kind: SharedPayloadKind.text,
          createdAt: DateTime.utc(2026, 7, 28, 0, 1),
          text: 'second native share',
        ),
      ]);

      expect(await storage.importNativeInbox(bridge), 1);
      expect(storage.pendingCount, SharedVaultStorage.maxPendingPayloads);
      expect(bridge.acknowledged.map((payload) => payload.id), [
        'native-first',
      ]);
      expect(
        (await storage.pending(
          limit: SharedVaultStorage.maxPendingPayloads,
        )).map((payload) => payload.id),
        isNot(contains('native-second')),
      );
      await storage.close();
    },
  );

  test(
    'retains generic files encrypted after outbox acknowledgement',
    () async {
      final storage = await SharedVaultStorage.open(
        fallbackDirectory: directory.path,
        keyStore: keyStore,
      );
      final bytes = Uint8List.fromList('private document bytes'.codeUnits);
      await storage.enqueue(
        SharedVaultPayload(
          id: 'file-1',
          kind: SharedPayloadKind.file,
          createdAt: DateTime.utc(2026, 7, 27),
          mimeType: 'application/pdf',
          displayName: 'notes.pdf',
          bytes: bytes,
        ),
      );

      await storage.retainFile('file-1');
      await storage.markProcessed('file-1');

      expect(storage.pendingCount, 0);
      final retained = await storage.retainedFile('file-1');
      expect(retained?.displayName, 'notes.pdf');
      expect(retained?.bytes, bytes);
      storage.checkpoint();
      expect(
        String.fromCharCodes(
          await File('${directory.path}/shared_vault_outbox.db').readAsBytes(),
        ),
        isNot(contains('private document bytes')),
      );
      await storage.close();
    },
  );
}

class _FakePlatformBridge implements SharedVaultPlatformBridge {
  _FakePlatformBridge(this.payloads);

  final List<SharedVaultPayload> payloads;
  List<SharedVaultPayload> acknowledged = const [];

  @override
  Future<void> acknowledgeNativeInbox(
    Iterable<SharedVaultPayload> imported,
  ) async {
    acknowledged = imported.toList(growable: false);
  }

  @override
  Future<List<SharedVaultPayload>> drainNativeInbox() async => payloads;

  @override
  Future<List<Map<String, Object?>>> drainWidgetActions() async => const [];

  @override
  Future<Map<String, Object?>> extensionStatus() async => const {
    'shareExtensionAvailable': true,
    'widgetExtensionAvailable': true,
    'sharedContainerAvailable': true,
  };

  @override
  Future<void> publishWidgetSnapshot(Map<String, Object?> snapshot) async {}

  @override
  Future<void> reloadWidgets() async {}

  @override
  Future<String?> sharedContainerPath() async => null;
}
