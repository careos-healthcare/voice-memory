import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/features/live_audio/application/live_voice_lifecycle_policy.dart';
import 'package:voicememory_mobile/features/live_audio/application/live_voice_lifecycle_ports.dart';
import 'package:voicememory_mobile/features/live_audio/application/offline_vault_recovery_service.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/offline_vault_recovery_store.dart';
import 'package:voicememory_mobile/services/capture_attest_service.dart';
import 'package:voicememory_mobile/services/capture_pipeline_service.dart';
import 'package:voicememory_mobile/storage/capture_token_cache.dart';
import 'package:voicememory_mobile/storage/device_id.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';

void main() {
  group('LiveVoiceLifecyclePolicy', () {
    late Directory vaultDirectory;
    late OfflineVaultRecoveryStore store;
    late OfflineVaultRecoveryService recoveryService;
    late _RecordingCapture capture;
    late _RecordingGateway gateway;
    var vaultSyncProcessCount = 0;
    var hasPendingEmergencyChunks = false;

    setUp(() async {
      vaultDirectory = await Directory.systemTemp.createTemp(
        'live_voice_lifecycle_policy_',
      );
      store = OfflineVaultRecoveryStore(
        manifestFile: File('${vaultDirectory.path}/manifests.json'),
        resolveVaultDirectory: () async => vaultDirectory,
      );
      final api = _FakeApiClient();
      final attest = CaptureAttestService(
        api: api,
        deviceIds: _FakeDeviceIdStore(),
        tokenCache: CaptureTokenCache()
          ..setToken('capture-token', expiresInSeconds: 3600),
      );
      recoveryService = OfflineVaultRecoveryService(
        store: store,
        api: api,
        attest: attest,
        pipeline: CapturePipelineService(
          api: api,
          attest: attest,
          journalStore: JournalStore(
            file: File('${vaultDirectory.path}/journal.json'),
          ),
        ),
      );
      capture = _RecordingCapture();
      gateway = _RecordingGateway();
      vaultSyncProcessCount = 0;
      hasPendingEmergencyChunks = false;
    });

    tearDown(() async {
      if (vaultDirectory.existsSync()) {
        await vaultDirectory.delete(recursive: true);
      }
    });

    LiveVoiceLifecyclePolicy buildPolicy() => LiveVoiceLifecyclePolicy(
      captureProvider: () => capture,
      recoveryGatewayProvider: () => gateway,
      recoveryServiceProvider: () => recoveryService,
      processPendingVaultSync: () async {
        vaultSyncProcessCount++;
      },
      hasPendingEmergencyChunks: () async => hasPendingEmergencyChunks,
      onAppResumedForRecovery: () async {},
    );

    test(
      'hasUncommittedVaultData is true when pending vault manifests exist',
      () async {
        final vaultFile = File(
          '${vaultDirectory.path}/audio_vault_session_pending.vault.enc',
        );
        await vaultFile.writeAsBytes([1, 2, 3]);
        await store.registerVault(
          sessionId: 'session_pending',
          vaultFile: vaultFile,
          frameCount: 1,
          durationSeconds: 1,
        );

        expect(await buildPolicy().hasUncommittedVaultData(), isTrue);
      },
    );

    test('hasUncommittedVaultData is true when capture is active', () async {
      capture.isActive = true;

      expect(await buildPolicy().hasUncommittedVaultData(), isTrue);
    });

    test('hasUncommittedVaultData includes pending emergency chunks', () async {
      hasPendingEmergencyChunks = true;

      expect(await buildPolicy().hasUncommittedVaultData(), isTrue);
    });

    test(
      'onAppBackgrounded deploys vault fallback and pauses active capture',
      () async {
        capture.isActive = true;

        buildPolicy().onAppBackgrounded();
        await Future<void>.delayed(Duration.zero);

        expect(capture.emergencyFallbackCount, 1);
        expect(capture.pauseCount, 1);
      },
    );

    test('onAppResumed triggers recovery sweep and capture resume', () async {
      capture.isActive = true;

      buildPolicy().onAppResumed();
      await Future<void>.delayed(Duration.zero);

      expect(gateway.connectivityNotified, isTrue);
      expect(gateway.sweepCount, 1);
      expect(vaultSyncProcessCount, 1);
      expect(capture.resumeCount, 1);
    });

    test('onAppTerminated terminates active capture session', () async {
      capture.isActive = true;

      buildPolicy().onAppTerminated();
      await Future<void>.delayed(Duration.zero);

      expect(capture.terminateCount, 1);
    });
  });
}

class _RecordingCapture implements LiveVoiceCaptureLifecycle {
  @override
  bool isActive = false;
  @override
  bool isOfflineVaultActive = false;
  var emergencyFallbackCount = 0;
  var pauseCount = 0;
  var resumeCount = 0;
  var terminateCount = 0;

  @override
  Future<void> triggerEmergencyNetworkFallback({String? reason}) async {
    emergencyFallbackCount++;
    isOfflineVaultActive = true;
  }

  @override
  Future<void> pauseLiveCapture() async {
    pauseCount++;
  }

  @override
  Future<void> resumeLiveCaptureIfActive() async {
    resumeCount++;
  }

  @override
  Future<void> terminateActiveSession() async {
    terminateCount++;
    isActive = false;
    isOfflineVaultActive = false;
  }
}

class _RecordingGateway implements LiveVoiceRecoveryLifecycle {
  var connectivityNotified = false;
  var sweepCount = 0;

  @override
  void notifyConnectivityRestored() {
    connectivityNotified = true;
  }

  @override
  Future<void> checkForPendingRecovery() async {
    sweepCount++;
  }
}

class _FakeApiClient extends VoiceCaptureApiClient {
  _FakeApiClient() : super(ApiTransport(baseUrl: 'http://test.invalid'));

  @override
  Future<AttestResult> postCaptureAttest(String deviceId) async {
    return AttestResult.capture(token: 'capture-token', expiresInSeconds: 3600);
  }
}

class _FakeDeviceIdStore extends DeviceIdStore {
  @override
  Future<String> getOrCreate() async => '00000000-0000-4000-8000-000000000001';
}
