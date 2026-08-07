import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/offline_vault_recovery_store.dart';
import 'package:voicememory_mobile/storage/account_namespace.dart';

/// Minimal fake so [OfflineVaultRecoveryStore]'s *default* (unoverridden)
/// manifest-file/vault-directory resolution — the code path every
/// production caller actually uses — can be exercised without a real
/// platform channel.
class _FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProviderPlatform(this.root);

  final Directory root;

  @override
  Future<String?> getApplicationSupportPath() async => root.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;

  setUp(() {
    tempRoot = Directory.systemTemp.createTempSync('vm_offline_vault_ns_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempRoot);
  });

  tearDown(() {
    if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
  });

  test('namespace-scoped stores resolve to separate manifest files under '
      'their own accounts/<namespace> directory', () async {
    final namespaceA = AccountNamespace.forUserId('vault-account-a');
    final namespaceB = AccountNamespace.forUserId('vault-account-b');

    final storeA = OfflineVaultRecoveryStore(namespace: namespaceA);
    final storeB = OfflineVaultRecoveryStore(namespace: namespaceB);

    final vaultDirA = await storeA.vaultDirectory();
    final vaultDirB = await storeB.vaultDirectory();

    expect(vaultDirA.path, contains('accounts/${namespaceA.key}'));
    expect(vaultDirB.path, contains('accounts/${namespaceB.key}'));
    expect(vaultDirA.path, isNot(equals(vaultDirB.path)));
  });

  test('a manifest registered under one namespace is invisible to another '
      'namespace, and to the legacy unscoped store', () async {
    final namespaceA = AccountNamespace.forUserId('vault-account-c');
    final namespaceB = AccountNamespace.forUserId('vault-account-d');

    final storeA = OfflineVaultRecoveryStore(namespace: namespaceA);
    final storeB = OfflineVaultRecoveryStore(namespace: namespaceB);
    final legacyStore = OfflineVaultRecoveryStore();

    final vaultDirA = await storeA.vaultDirectory();
    final sourceFile = File(
      '${vaultDirA.path}/audio_vault_session_a.vault.enc',
    );
    await sourceFile.writeAsBytes([1, 2, 3]);

    await storeA.registerVault(
      sessionId: 'session_a',
      vaultFile: sourceFile,
      frameCount: 4,
      durationSeconds: 3,
    );

    final pendingA = await storeA.listPending();
    expect(pendingA.map((m) => m.sessionId), contains('session_a'));

    final pendingB = await storeB.listPending();
    expect(pendingB, isEmpty);

    final pendingLegacy = await legacyStore.listPending();
    expect(pendingLegacy, isEmpty);
  });

  test(
    'legacy (namespace-less) construction preserves the unscoped path',
    () async {
      final legacyStore = OfflineVaultRecoveryStore();
      final vaultDir = await legacyStore.vaultDirectory();
      expect(vaultDir.path, isNot(contains('accounts/')));
      expect(vaultDir.path, endsWith('live_audio_vaults'));
    },
  );
}
