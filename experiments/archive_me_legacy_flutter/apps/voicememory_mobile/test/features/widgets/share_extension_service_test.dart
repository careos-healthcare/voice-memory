import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/widgets/share_extension_service.dart';
import 'package:voicememory_mobile/services/local_storage/shared_vault_storage.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  late Directory directory;
  late SharedVaultStorage storage;
  late _EventPlatformBridge platform;
  late ShareExtensionService service;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('share-service-test');
    final keyStore = InMemoryPrivateDataEncryptionKeyStore();
    await keyStore.ensureKey();
    storage = await SharedVaultStorage.open(
      fallbackDirectory: directory.path,
      keyStore: keyStore,
    );
    platform = _EventPlatformBridge();
    service = ShareExtensionService(storage: storage, platform: platform);
  });

  tearDown(() async {
    await service.dispose();
    await storage.close();
    await platform.close();
    await directory.delete(recursive: true);
  });

  test('foreground handoff event imports and ingests immediately', () async {
    platform.payloads = [
      SharedVaultPayload(
        id: 'foreground-share',
        kind: SharedPayloadKind.text,
        createdAt: DateTime.utc(2026, 7, 28),
        text: 'captured while the app is open',
      ),
    ];
    final ingested = Completer<String>();
    service.startForegroundProcessing((payload) async {
      ingested.complete(payload.id);
      return true;
    });

    platform.emitReady('native-handoff');

    expect(
      await ingested.future.timeout(const Duration(seconds: 2)),
      'foreground-share',
    );
    for (var attempt = 0; attempt < 20 && service.pendingCount > 0; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(service.pendingCount, 0);
    expect(platform.acknowledged.map((payload) => payload.id), [
      'foreground-share',
    ]);
  });

  test('failed ingest remains queued for retry', () async {
    platform.payloads = [
      SharedVaultPayload(
        id: 'retry-share',
        kind: SharedPayloadKind.text,
        createdAt: DateTime.utc(2026, 7, 28),
        text: 'retry me',
      ),
    ];

    await service.importPendingNativeShares();
    expect(await service.drainTo((_) async => false), 0);
    expect((await service.pending()).single.id, 'retry-share');
  });
}

class _EventPlatformBridge
    implements SharedVaultPlatformBridge, SharedVaultPlatformEventSource {
  final _events = StreamController<SharedVaultPlatformEvent>.broadcast();
  List<SharedVaultPayload> payloads = const [];
  List<SharedVaultPayload> acknowledged = const [];

  @override
  Stream<SharedVaultPlatformEvent> get events => _events.stream;

  void emitReady(String id) {
    _events.add(
      SharedVaultPlatformEvent(
        type: SharedVaultPlatformEventType.shareReady,
        handoffId: id,
      ),
    );
  }

  Future<void> close() => _events.close();

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
  Future<Map<String, Object?>> extensionStatus() async => const {};

  @override
  Future<void> publishWidgetSnapshot(Map<String, Object?> snapshot) async {}

  @override
  Future<void> reloadWidgets() async {}

  @override
  Future<String?> sharedContainerPath() async => null;
}
