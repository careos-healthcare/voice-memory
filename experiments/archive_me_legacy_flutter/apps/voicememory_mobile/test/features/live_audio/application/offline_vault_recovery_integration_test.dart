import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/api/api_exceptions.dart';
import 'package:voicememory_mobile/features/live_audio/application/offline_vault_recovery_service.dart';
import 'package:voicememory_mobile/features/live_audio/domain/models/offline_vault_manifest.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/offline_vault_recovery_store.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/capture_attest_service.dart';
import 'package:voicememory_mobile/services/capture_pipeline_service.dart';
import 'package:voicememory_mobile/storage/capture_token_cache.dart';
import 'package:voicememory_mobile/storage/device_id.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late Directory vaultDirectory;
  late File manifestFile;
  late InMemoryPrivateDataEncryptionKeyStore keyStore;
  late JournalStore journal;
  late _VaultApi api;
  late _FakeAttest attest;

  setUp(() async {
    root = await Directory.systemTemp.createTemp(
      'offline_vault_recovery_integration_',
    );
    vaultDirectory = Directory('${root.path}/vaults');
    await vaultDirectory.create(recursive: true);
    manifestFile = File('${root.path}/offline_vault_manifests.json');
    keyStore = InMemoryPrivateDataEncryptionKeyStore(
      seedKey: List<int>.generate(32, (index) => 255 - index),
    );
    journal = await JournalStore.open(
      '${root.path}/journal.json',
      keyStore: keyStore,
    );
    api = _VaultApi();
    attest = _FakeAttest(api);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  OfflineVaultRecoveryStore createStore() => OfflineVaultRecoveryStore(
    manifestFile: manifestFile,
    resolveVaultDirectory: () async => vaultDirectory,
  );

  OfflineVaultRecoveryService createService(OfflineVaultRecoveryStore store) =>
      OfflineVaultRecoveryService(
        store: store,
        api: api,
        attest: attest,
        pipeline: CapturePipelineService(
          api: api,
          attest: attest,
          journalStore: journal,
        ),
      );

  test(
    'failed upload remains byte-exact and recovers once after restart',
    () async {
      final encryptedBytes = List<int>.generate(
        8192,
        (index) => (index * 17) % 256,
      );
      final incoming = File('${root.path}/interrupted.vault.enc');
      await incoming.writeAsBytes(encryptedBytes, flush: true);
      final firstStore = createStore();
      final registered = await firstStore.registerVault(
        sessionId: 'server_session_42',
        vaultFile: incoming,
        frameCount: 40,
        durationSeconds: 8,
      );
      api.online = false;

      await expectLater(
        createService(firstStore).recoverVault(registered),
        throwsA(isA<ConnectivityException>()),
      );

      final failed = (await firstStore.listPending()).single;
      expect(failed.uploadState, OfflineVaultUploadState.failed);
      expect(failed.lastError, isNotEmpty);
      expect(
        failed.idempotencyKey,
        OfflineVaultRecoveryStore.stableIdempotencyKey(failed.sessionId),
      );
      expect(await File(failed.vaultPath).readAsBytes(), encryptedBytes);
      expect(await journal.loadAll(), isEmpty);
      expect(api.uploadedBytes, [encryptedBytes]);
      expect(api.idempotencyKeys, [failed.idempotencyKey]);

      journal = await JournalStore.open(
        '${root.path}/journal.json',
        keyStore: keyStore,
      );
      final restartedStore = createStore();
      final restartedService = createService(restartedStore);
      api.online = false;
      final pendingOffline = await restartedService.scanPendingVaults();
      expect(pendingOffline.single.uploadState, OfflineVaultUploadState.failed);
      expect(await File(failed.vaultPath).readAsBytes(), encryptedBytes);

      api.online = true;
      final recovered = await restartedService.recoverVault(
        pendingOffline.single,
      );

      expect(recovered.localSaved, isTrue);
      final entries = await journal.loadAll();
      expect(entries, hasLength(1));
      expect(entries.single.id, recovered.entry.id);
      expect(entries.single.transcript, 'server recovered transcript');
      expect(
        entries.single.reflection.concreteObservation,
        'Your words include “server recovered transcript”.',
      );
      expect(api.uploadedBytes, [encryptedBytes, encryptedBytes]);
      expect(api.idempotencyKeys, [
        failed.idempotencyKey,
        failed.idempotencyKey,
      ]);
      expect(await restartedStore.listManifests(), isEmpty);
      expect(await File(failed.vaultPath).exists(), isFalse);
    },
  );

  test('restart discovers and recovers server-recoverable orphan', () async {
    final encryptedBytes = List<int>.generate(
      2048,
      (index) => (index * 29) % 256,
    );
    const sessionId = 'server_orphan_after_crash';
    final orphan = File(
      '${vaultDirectory.path}/audio_vault_$sessionId.vault.enc',
    );
    await orphan.writeAsBytes(encryptedBytes, flush: true);
    api.online = true;

    final restartedStore = createStore();
    final restartedService = createService(restartedStore);
    final pending = await restartedService.scanPendingVaults();

    expect(pending, hasLength(1));
    expect(pending.single.sessionId, sessionId);
    expect(pending.single.serverRecoverable, isTrue);
    expect(await orphan.readAsBytes(), encryptedBytes);
    await restartedService.recoverVault(pending.single);

    expect(api.uploadedBytes.single, encryptedBytes);
    expect(api.idempotencyKeys.single, 'vault_recovery:$sessionId');
    expect(
      (await journal.loadAll()).single.transcript,
      'server recovered transcript',
    );
    expect(await orphan.exists(), isFalse);
    expect(await restartedStore.listManifests(), isEmpty);
  });
}

final class _VaultApi extends VoiceCaptureApiClient {
  _VaultApi() : super(ApiTransport(baseUrl: 'https://example.test'));

  bool online = true;
  final uploadedBytes = <List<int>>[];
  final idempotencyKeys = <String>[];

  @override
  Future<VaultRecoveryServerResult> postVaultRecovery({
    required File vaultFile,
    required String sessionId,
    required int durationSeconds,
    required String captureToken,
    required String idempotencyKey,
    List<int>? recoverySecretKeyBytes,
  }) async {
    uploadedBytes.add(await vaultFile.readAsBytes());
    idempotencyKeys.add(idempotencyKey);
    if (!online) throw ConnectivityException();
    return VaultRecoveryServerResult(
      recoveryAckId: 'ack-$sessionId',
      transcript: 'server recovered transcript',
      reflectionJson: _vaultReflection.toJson(),
      durationSeconds: durationSeconds,
      duplicate: false,
      frameCount: 40,
    );
  }
}

const _vaultReflection = Reflection(
  mood: 'steady',
  emotionalIntensity: 2,
  recurringThemes: ['recovery'],
  exactLanguagePattern: 'server recovered transcript',
  concreteObservation: 'vault recovered reflection',
  repeatedSignal: '',
);

final class _FakeAttest extends CaptureAttestService {
  _FakeAttest(VoiceCaptureApiClient api)
    : super(
        api: api,
        deviceIds: _FakeDeviceIdStore(),
        tokenCache: CaptureTokenCache(),
      );

  @override
  Future<String> ensureCaptureToken({bool forceRefresh = false}) async =>
      'capture-token';
}

final class _FakeDeviceIdStore extends DeviceIdStore {
  @override
  Future<String> getOrCreate() async => 'device-id';
}
