import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/features/live_audio/application/offline_vault_recovery_service.dart';
import 'package:voicememory_mobile/features/live_audio/domain/models/offline_vault_manifest.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/offline_vault_recovery_store.dart';
import 'package:voicememory_mobile/services/capture_attest_service.dart';
import 'package:voicememory_mobile/services/capture_pipeline_service.dart';
import 'package:voicememory_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:voicememory_mobile/security/remote_processing_consent_gate.dart';
import 'package:voicememory_mobile/storage/capture_token_cache.dart';
import 'package:voicememory_mobile/storage/device_id.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

void main() {
  group('OfflineVaultRecoveryService', () {
    late Directory vaultDirectory;
    late File manifestFile;
    late OfflineVaultRecoveryStore store;
    late _RecordingPipeline pipeline;
    late _FakeApiClient api;
    late CaptureAttestService attest;
    late OfflineVaultRecoveryService service;

    late RemoteProcessingConsentGate consentGate;

    setUp(() async {
      vaultDirectory = await Directory.systemTemp.createTemp(
        'offline_vault_service_',
      );
      manifestFile = File('${vaultDirectory.path}/manifests.json');
      store = OfflineVaultRecoveryStore(
        manifestFile: manifestFile,
        resolveVaultDirectory: () async => vaultDirectory,
      );
      api = _FakeApiClient();
      attest = CaptureAttestService(
        api: api,
        deviceIds: _FakeDeviceIdStore(),
        tokenCache: CaptureTokenCache()
          ..setToken('capture-token', expiresInSeconds: 3600),
      );
      final prefsFile = await MobilePrefsStore.open(
        '${vaultDirectory.path}/prefs.json',
      );
      pipeline = _RecordingPipeline(
        api: api,
        attest: attest,
        journalStore: JournalStore(
          file: File('${vaultDirectory.path}/journal.json'),
        ),
        consentStore: RemoteProcessingConsentStore(prefsFile),
      );
      consentGate = RemoteProcessingConsentGate.fromPrefs(prefsFile);
      await RemoteProcessingConsentStore(prefsFile).grant();
      service = OfflineVaultRecoveryService(
        store: store,
        api: api,
        attest: attest,
        pipeline: pipeline,
        consentGate: consentGate,
      );
    });

    tearDown(() async {
      if (vaultDirectory.existsSync()) {
        await vaultDirectory.delete(recursive: true);
      }
    });

    test(
      'recoverVault uploads, saves journal entry, then deletes vault on ack',
      () async {
        final vaultFile = File(
          '${vaultDirectory.path}/audio_vault_session_ack.vault.enc',
        );
        await vaultFile.writeAsBytes([1, 2, 3, 4, 5]);

        final manifest = await store.registerVault(
          sessionId: 'session_ack',
          vaultFile: vaultFile,
          frameCount: 5,
          durationSeconds: 4,
        );

        final result = await service.recoverVault(manifest);
        expect(result.localSaved, isTrue);
        expect(result.entry.transcript, 'recovered transcript');
        expect(await File(manifest.vaultPath).exists(), isFalse);
        expect(await store.listPending(), isEmpty);
        expect(api.uploadCount, 1);
      },
    );

    test(
      'recoverVault without consent retains vault and does not upload',
      () async {
        final noConsentPrefs = await MobilePrefsStore.open(
          '${vaultDirectory.path}/no_consent_prefs.json',
        );
        final noConsentService = OfflineVaultRecoveryService(
          store: store,
          api: api,
          attest: attest,
          pipeline: pipeline,
          consentGate: RemoteProcessingConsentGate.fromPrefs(noConsentPrefs),
        );

        final vaultFile = File(
          '${vaultDirectory.path}/audio_vault_no_consent.vault.enc',
        );
        await vaultFile.writeAsBytes([1, 2, 3]);
        final manifest = await store.registerVault(
          sessionId: 'session_no_consent',
          vaultFile: vaultFile,
          frameCount: 3,
          durationSeconds: 2,
        );

        await expectLater(
          noConsentService.recoverVault(manifest),
          throwsA(isA<RemoteProcessingConsentRequired>()),
        );
        expect(api.uploadCount, 0);
        expect(await File(manifest.vaultPath).exists(), isTrue);
      },
    );

    test('recoverVault sends recovery_secret for offline_* sessions', () async {
      final recoverySecret = List<int>.generate(32, (index) => index + 1);
      final vaultFile = File(
        '${vaultDirectory.path}/audio_vault_offline_1784498962800.vault.enc',
      );
      await vaultFile.writeAsBytes([1, 2, 3, 4, 5]);

      final manifest = await store.registerVault(
        sessionId: 'offline_1784498962800',
        vaultFile: vaultFile,
        frameCount: 5,
        durationSeconds: 4,
        recoverySecretKeyBytes: recoverySecret,
      );

      await service.recoverVault(manifest);

      expect(api.lastRecoverySecretKeyBytes, recoverySecret);
      expect(await File(manifest.vaultPath).exists(), isFalse);
    });

    test(
      'recoverVault rejects offline_* sessions missing recovery_secret',
      () async {
        final vaultFile = File(
          '${vaultDirectory.path}/audio_vault_offline_orphan.vault.enc',
        );
        await vaultFile.writeAsBytes([1, 2, 3]);

        final manifest = await store.registerVault(
          sessionId: 'offline_orphan',
          vaultFile: vaultFile,
          frameCount: 3,
          durationSeconds: 2,
          serverRecoverable: false,
        );

        expect(
          () => service.recoverVault(manifest),
          throwsA(isA<StateError>()),
        );
        expect(api.uploadCount, 0);
      },
    );
  });
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(baseUrl: 'http://test.invalid');

  var uploadCount = 0;
  List<int>? lastRecoverySecretKeyBytes;

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
    uploadCount++;
    lastRecoverySecretKeyBytes = recoverySecretKeyBytes;
    return VaultRecoveryServerResult(
      recoveryAckId: 'ack_$sessionId',
      transcript: 'recovered transcript',
      reflectionJson: const {
        'mood': 'neutral',
        'emotionalIntensity': 1,
        'recurringThemes': <String>[],
        'exactLanguagePattern': 'recovered',
        'concreteObservation': 'transcript',
        'repeatedSignal': 'recovered',
      },
      durationSeconds: durationSeconds,
      duplicate: false,
      frameCount: 5,
    );
  }
}

class _RecordingPipeline extends CapturePipelineService {
  _RecordingPipeline({
    required super.api,
    required super.attest,
    required super.journalStore,
    required super.consentStore,
  });
}

class _FakeDeviceIdStore extends DeviceIdStore {
  @override
  Future<String> getOrCreate() async => '00000000-0000-4000-8000-000000000001';
}
