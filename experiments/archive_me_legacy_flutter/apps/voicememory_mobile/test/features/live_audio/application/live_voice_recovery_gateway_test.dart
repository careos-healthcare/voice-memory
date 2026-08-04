import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/features/live_audio/application/live_voice_recovery_gateway.dart';
import 'package:voicememory_mobile/features/live_audio/application/offline_vault_recovery_service.dart';
import 'package:voicememory_mobile/features/live_audio/domain/models/offline_vault_manifest.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/local_audio_vault.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/network_connectivity_source.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/offline_vault_recovery_store.dart';
import 'package:voicememory_mobile/services/capture_attest_service.dart';
import 'package:voicememory_mobile/services/capture_pipeline_service.dart';
import 'package:voicememory_mobile/storage/capture_token_cache.dart';
import 'package:voicememory_mobile/storage/device_id.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/vault_key_provider.dart';

void main() {
  group('LiveVoiceRecoveryGateway', () {
    late Directory vaultDirectory;
    late File manifestFile;
    late OfflineVaultRecoveryStore store;
    late _FakeApiClient api;
    late OfflineVaultRecoveryService recoveryService;
    late LocalAudioVault vault;
    late _TestConnectivity connectivity;
    late LiveVoiceRecoveryGateway gateway;

    setUp(() async {
      vaultDirectory = await Directory.systemTemp.createTemp(
        'live_voice_gateway_',
      );
      manifestFile = File('${vaultDirectory.path}/manifests.json');
      store = OfflineVaultRecoveryStore(
        manifestFile: manifestFile,
        resolveVaultDirectory: () async => vaultDirectory,
      );
      api = _FakeApiClient();
      recoveryService = OfflineVaultRecoveryService(
        store: store,
        api: api,
        attest: CaptureAttestService(
          api: api,
          deviceIds: _FakeDeviceIdStore(),
          tokenCache: CaptureTokenCache()
            ..setToken('capture-token', expiresInSeconds: 3600),
        ),
        pipeline: CapturePipelineService(
          api: api,
          attest: CaptureAttestService(
            api: api,
            deviceIds: _FakeDeviceIdStore(),
            tokenCache: CaptureTokenCache()
              ..setToken('capture-token', expiresInSeconds: 3600),
          ),
          journalStore: JournalStore(
            file: File('${vaultDirectory.path}/journal.json'),
          ),
        ),
      );
      vault = LocalAudioVault(
        vaultKeyProvider: VaultKeyProvider.testing(),
        resolveCacheDirectory: () async => vaultDirectory,
      );
      connectivity = _TestConnectivity();
      gateway = LiveVoiceRecoveryGateway(
        vault: vault,
        connectivity: connectivity,
        recoveryStore: store,
        recoveryService: recoveryService,
      );
    });

    tearDown(() async {
      gateway.dispose();
      if (vaultDirectory.existsSync()) {
        await vaultDirectory.delete(recursive: true);
      }
    });

    test(
      'checkForPendingRecovery uploads and deletes vault after connectivity restore',
      () async {
        await vault.initializeVault('session_gateway');
        vault.appendPcm16LeBytes([1, 2, 3, 4]);
        final closed = await vault.closeVault();
        expect(closed, isNotNull);

        await gateway.checkForPendingRecovery();
        expect(await closed!.exists(), isFalse);
        expect(await store.listPending(), isEmpty);
      },
    );

    test('connectivity restored listener triggers directory sweep', () async {
      await vault.initializeVault('session_listener');
      vault.appendPcm16LeBytes([9, 9]);
      await vault.closeVault();

      connectivity.emitRestore();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(await store.listPending(), isEmpty);
    });
  });
}

class _TestConnectivity implements NetworkConnectivitySource {
  final StreamController<void> _controller = StreamController<void>.broadcast();

  @override
  Stream<void> get onConnectivityRestored => _controller.stream;

  void emitRestore() => _controller.add(null);

  @override
  void dispose() => _controller.close();
}

class _FakeApiClient extends VoiceCaptureApiClient {
  _FakeApiClient() : super(ApiTransport(baseUrl: 'http://test.invalid'));

  @override
  Future<AttestResult> postCaptureAttest(String deviceId) async {
    return AttestResult.capture(token: 'capture-token', expiresInSeconds: 3600);
  }

  @override
  Future<VaultRecoveryServerResult> postVaultRecovery({
    required File vaultFile,
    required String sessionId,
    required int durationSeconds,
    required String captureToken,
    required String idempotencyKey,
    List<int>? recoverySecretKeyBytes,
  }) async {
    return VaultRecoveryServerResult(
      recoveryAckId: 'ack_$sessionId',
      transcript: 'gateway transcript',
      reflectionJson: const {
        'mood': 'neutral',
        'emotionalIntensity': 1,
        'recurringThemes': <String>[],
        'exactLanguagePattern': 'test',
        'concreteObservation': 'test',
        'repeatedSignal': 'test',
      },
      durationSeconds: durationSeconds,
      duplicate: false,
      frameCount: 1,
    );
  }
}

class _FakeDeviceIdStore extends DeviceIdStore {
  @override
  Future<String> getOrCreate() async => '00000000-0000-4000-8000-000000000001';
}
