import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/sync/encrypted_graph_sync_engine.dart';
import 'package:voicememory_mobile/core/sync/encrypted_graph_sync_queue.dart';
import 'package:voicememory_mobile/core/sync/platform_encrypted_graph_sync_transport.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/local_audio_vault.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/vault_key_provider.dart';
import 'package:voicememory_mobile/services/app_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppServices vault key wiring', () {
    tearDown(AppServices.disposeForTest);

    test(
      'resetForTest shares one VaultKeyProvider across liveAudioVault',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'app_services_vault_wiring_',
        );
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });

        await AppServices.resetForTest(
          journalPath: '${tempDir.path}/journal.json',
          prefsPath: '${tempDir.path}/prefs.json',
          skipRevenueCat: true,
        );

        final services = AppServices.instance;
        expect(services.vaultKeyProvider, isA<VaultKeyProvider>());

        // Boot pre-warm: key is cached before any vault frame write.
        final warmedKey = await services.vaultKeyProvider
            .getOrCreateMasterKey();
        expect(await warmedKey.extractBytes(), hasLength(32));

        services.vaultKeyProvider.clearCache();
        final reloadedKey = await services.vaultKeyProvider
            .getOrCreateMasterKey();
        expect(
          await reloadedKey.extractBytes(),
          await warmedKey.extractBytes(),
          reason:
              'testing provider should reload stable bytes after cache clear',
        );

        expect(services.liveAudioVault, isA<LocalAudioVault>());
        expect(services.liveVoiceCapture, isNotNull);
        expect(
          services.encryptedGraphSyncQueue,
          isA<EncryptedGraphSyncQueue>(),
        );
        expect(
          services.encryptedGraphSyncEngine,
          isA<EncryptedGraphSyncEngine>(),
        );
        expect(
          await services.encryptedGraphSyncCapability.capability(
            EncryptedGraphSyncTarget.googleDrive,
          ),
          EncryptedGraphSyncCapabilityState.unavailable,
        );
        expect(services.supportsInteractiveGraphSyncAuthorization, isFalse);
        expect(services.encryptedGraphSyncPlatformTransport, isNull);
        expect(
          File('${tempDir.path}/encrypted_graph_sync_queue.enc').existsSync(),
          isFalse,
          reason: 'test setup must not start a live queue drain',
        );
      },
    );

    test(
      'LocalAudioVault uses injected provider without redundant secure reads',
      () async {
        final vaultDirectory = await Directory.systemTemp.createTemp(
          'app_services_vault_wiring_',
        );
        addTearDown(() async {
          if (vaultDirectory.existsSync()) {
            await vaultDirectory.delete(recursive: true);
          }
        });

        final vaultKeyProvider = VaultKeyProvider.testing();
        final warmedKey = await vaultKeyProvider.getOrCreateMasterKey();

        final vault = LocalAudioVault(
          vaultKeyProvider: vaultKeyProvider,
          resolveCacheDirectory: () async => vaultDirectory,
        );
        await vault.initializeVault('session_wiring');

        expect(vault.isActive, isTrue);
        expect(await warmedKey.extractBytes(), isNotEmpty);

        vaultKeyProvider.clearCache();
        final reloadedKey = await vaultKeyProvider.getOrCreateMasterKey();
        expect(
          await reloadedKey.extractBytes(),
          await warmedKey.extractBytes(),
        );

        await vault.closeVault();
      },
    );

    test('resetForTest isolates and cleans runtime storage', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'app_services_runtime_isolation_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/first_journal.json',
        prefsPath: '${tempDir.path}/first_prefs.json',
        skipRevenueCat: true,
      );
      final firstRoot = AppServices.instance.testRuntimeRoot!;
      expect(
        File(
          '${firstRoot.path}/transcription_queue/transcription_jobs.sqlite3',
        ).existsSync(),
        isTrue,
      );

      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/second_journal.json',
        prefsPath: '${tempDir.path}/second_prefs.json',
        skipRevenueCat: true,
      );
      final secondRoot = AppServices.instance.testRuntimeRoot!;

      expect(secondRoot.path, isNot(firstRoot.path));
      expect(await firstRoot.exists(), isFalse);
      expect(await secondRoot.exists(), isTrue);
      expect(await File('${tempDir.path}/first_journal.json').exists(), isTrue);
    });
  });
}
