import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/live_audio/domain/models/offline_vault_manifest.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/offline_vault_recovery_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineVaultRecoveryStore', () {
    late Directory vaultDirectory;
    late File manifestFile;
    late OfflineVaultRecoveryStore store;

    setUp(() async {
      vaultDirectory =
          await Directory.systemTemp.createTemp('offline_vault_recovery_');
      manifestFile = File('${vaultDirectory.path}/manifests.json');
      store = OfflineVaultRecoveryStore(
        manifestFile: manifestFile,
        resolveVaultDirectory: () async => vaultDirectory,
      );
    });

    tearDown(() async {
      if (vaultDirectory.existsSync()) {
        await vaultDirectory.delete(recursive: true);
      }
    });

    test('registerVault keeps encrypted file until server ack completes', () async {
      final source = File('${vaultDirectory.path}/audio_vault_session_1.vault.enc');
      await source.writeAsBytes([1, 2, 3, 4]);

      final manifest = await store.registerVault(
        sessionId: 'session_1',
        vaultFile: source,
        frameCount: 12,
        durationSeconds: 8,
      );

      expect(await File(manifest.vaultPath).exists(), isTrue);
      expect(manifest.uploadState, OfflineVaultUploadState.pending);
      expect(manifest.idempotencyKey, 'vault_recovery:session_1');
    });

    test('markCompleted deletes vault file after recovery ack', () async {
      final source = File('${vaultDirectory.path}/audio_vault_session_2.vault.enc');
      await source.writeAsBytes([9, 8, 7]);

      final manifest = await store.registerVault(
        sessionId: 'session_2',
        vaultFile: source,
        frameCount: 3,
        durationSeconds: 2,
      );
      final vaultPath = manifest.vaultPath;

      await store.markCompleted(manifest, recoveryAckId: 'ack_test_123');

      expect(await File(vaultPath).exists(), isFalse);
      final pending = await store.listPending();
      expect(pending, isEmpty);
    });

    test('discoverOrphans registers unknown vault.enc files as pending jobs', () async {
      final orphan = File('${vaultDirectory.path}/audio_vault_session_3.vault.enc');
      await orphan.writeAsBytes([5, 5, 5]);

      final orphans = await store.discoverOrphans();
      expect(orphans, hasLength(1));
      expect(orphans.first.sessionId, 'session_3');
      expect(orphans.first.isPending, isTrue);

      final pending = await store.listPending();
      expect(pending.map((entry) => entry.sessionId), contains('session_3'));
    });

    test('registerVault marks offline_* recoverable only when recovery secret present', () async {
      final source = File(
        '${vaultDirectory.path}/audio_vault_offline_123.vault.enc',
      );
      await source.writeAsBytes([1, 2, 3]);

      final withoutSecret = await store.registerVault(
        sessionId: 'offline_123',
        vaultFile: source,
        frameCount: 2,
        durationSeconds: 1,
      );
      expect(withoutSecret.serverRecoverable, isFalse);
      expect(withoutSecret.recoverySecretKeyBytes, isNull);

      final withSecret = await store.registerVault(
        sessionId: 'offline_456',
        vaultFile: source,
        frameCount: 2,
        durationSeconds: 1,
        recoverySecretKeyBytes: List<int>.generate(32, (index) => index),
      );
      expect(withSecret.serverRecoverable, isTrue);
      expect(withSecret.recoverySecretKeyBytes, hasLength(32));
    });

    test('discard removes vault artifacts without server ack', () async {
      final source = File('${vaultDirectory.path}/audio_vault_session_4.vault.enc');
      await source.writeAsBytes([1]);

      final manifest = await store.registerVault(
        sessionId: 'session_4',
        vaultFile: source,
        frameCount: 1,
        durationSeconds: 1,
      );

      await store.discard(manifest);
      expect(await File(manifest.vaultPath).exists(), isFalse);
      expect(await store.listPending(), isEmpty);
    });
  });
}
