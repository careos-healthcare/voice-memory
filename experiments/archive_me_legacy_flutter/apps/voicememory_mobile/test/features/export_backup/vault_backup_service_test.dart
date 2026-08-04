import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/export_backup/export_backup.dart';

void main() {
  late Directory root;
  late Directory sourceRoot;
  late Directory restoreRoot;
  late VaultSourceCatalog sourceCatalog;
  late VaultSourceCatalog restoreCatalog;
  late _Lifecycle lifecycle;
  late _KeyProvider provider;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('memoryvault_test_');
    sourceRoot = Directory('${root.path}/source')..createSync();
    restoreRoot = Directory('${root.path}/restore')..createSync();
    Directory('${sourceRoot.path}/encrypted_media').createSync();
    await File(
      '${sourceRoot.path}/journal_entries.enc',
    ).writeAsBytes([0, 1, 2, 3, 254, 255]);
    await File(
      '${sourceRoot.path}/encrypted_media/clip.vault',
    ).writeAsBytes(List<int>.generate(4096, (index) => index % 256));
    sourceCatalog = _catalog(sourceRoot);
    restoreCatalog = _catalog(restoreRoot);
    lifecycle = _Lifecycle();
    provider = _KeyProvider();
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('preserves every source byte through password round trip', () async {
    final backup = await _backup(
      root,
      sourceCatalog,
      lifecycle,
      provider,
      VaultCredential.password('correct horse battery'),
      includeSyncPhrase: true,
    );
    final installer = _Installer();
    final notifier = _Notifier();

    final result =
        await VaultRestoreService(
          catalog: restoreCatalog,
          keyInstaller: installer,
          lifecycle: lifecycle,
          notifier: notifier,
        ).restore(
          input: backup,
          credential: VaultCredential.password('correct horse battery'),
        );

    expect(result.restoredFiles, 2);
    expect(
      await File('${restoreRoot.path}/journal_entries.enc').readAsBytes(),
      [0, 1, 2, 3, 254, 255],
    );
    expect(
      await File(
        '${restoreRoot.path}/encrypted_media/clip.vault',
      ).readAsBytes(),
      List<int>.generate(4096, (index) => index % 256),
    );
    expect(installer.installs, 1);
    expect(installer.copiedKeys[VaultPortableKey.privateDataEncryption], [
      7,
      8,
      9,
    ]);
    expect(installer.copiedSyncPhrase, 'portable sync phrase');
    expect(notifier.resets, 1);
    expect(notifier.notifications, 1);
    expect(lifecycle.quiesces, 2);
    expect(lifecycle.resumes, 2);
  });

  test('round trips with a validated 12-word BIP39 phrase', () async {
    const phrase =
        'abandon abandon abandon abandon abandon abandon abandon abandon '
        'abandon abandon abandon about';
    final backup = await _backup(
      root,
      sourceCatalog,
      lifecycle,
      provider,
      VaultCredential.bip39(phrase),
    );

    await VaultRestoreService(
      catalog: restoreCatalog,
      keyInstaller: _Installer(),
      lifecycle: lifecycle,
      notifier: _Notifier(),
    ).restore(input: backup, credential: VaultCredential.bip39(phrase));

    expect(
      await File('${restoreRoot.path}/journal_entries.enc').readAsBytes(),
      [0, 1, 2, 3, 254, 255],
    );
  });

  test('rejects wrong password before key installation or staging', () async {
    final backup = await _backup(
      root,
      sourceCatalog,
      lifecycle,
      provider,
      VaultCredential.password('correct horse battery'),
    );
    final installer = _Installer();

    await expectLater(
      VaultRestoreService(
        catalog: restoreCatalog,
        keyInstaller: installer,
        lifecycle: lifecycle,
        notifier: _Notifier(),
      ).restore(
        input: backup,
        credential: VaultCredential.password('incorrect horse battery'),
      ),
      throwsA(isA<VaultBackupAuthenticationException>()),
    );
    expect(installer.installs, 0);
    expect(await restoreRoot.list().toList(), isEmpty);
  });

  test('rejects authenticated envelope tampering', () async {
    final backup = await _backup(
      root,
      sourceCatalog,
      lifecycle,
      provider,
      VaultCredential.password('correct horse battery'),
    );
    final json = Map<String, Object?>.from(
      jsonDecode(await backup.readAsString()) as Map,
    );
    final ciphertext = base64Decode(json['ciphertext']! as String);
    ciphertext[ciphertext.length ~/ 2] ^= 1;
    json['ciphertext'] = base64Encode(ciphertext);
    await backup.writeAsString(jsonEncode(json));

    await expectLater(
      VaultRestoreService(
        catalog: restoreCatalog,
        keyInstaller: _Installer(),
        lifecycle: lifecycle,
        notifier: _Notifier(),
      ).restore(
        input: backup,
        credential: VaultCredential.password('correct horse battery'),
      ),
      throwsA(isA<VaultBackupAuthenticationException>()),
    );
  });

  test('rejects post-ZIP checksum mismatch', () async {
    final codec = _TransformingCodec((entries) {
      entries['data/journal_entries.enc']![0] ^= 1;
    });
    final backup = await _backup(
      root,
      sourceCatalog,
      lifecycle,
      provider,
      VaultCredential.password('correct horse battery'),
      codec: codec,
    );

    await expectLater(
      VaultRestoreService(
        catalog: restoreCatalog,
        keyInstaller: _Installer(),
        lifecycle: lifecycle,
        notifier: _Notifier(),
        zipCodec: codec,
      ).restore(
        input: backup,
        credential: VaultCredential.password('correct horse battery'),
      ),
      throwsA(isA<VaultBackupValidationException>()),
    );
  });

  test('rejects traversal returned by ZIP decoder', () async {
    final codec = _TransformingCodec((entries) {
      entries['../escape.enc'] = Uint8List.fromList([1]);
    });
    final backup = await _backup(
      root,
      sourceCatalog,
      lifecycle,
      provider,
      VaultCredential.password('correct horse battery'),
      codec: codec,
    );

    await expectLater(
      VaultRestoreService(
        catalog: restoreCatalog,
        keyInstaller: _Installer(),
        lifecycle: lifecycle,
        notifier: _Notifier(),
        zipCodec: codec,
      ).restore(
        input: backup,
        credential: VaultCredential.password('correct horse battery'),
      ),
      throwsA(isA<VaultBackupValidationException>()),
    );
    expect(await File('${root.path}/escape.enc').exists(), isFalse);
  });

  test(
    'provider notification failure does not roll back live stores',
    () async {
      final original = File('${restoreRoot.path}/journal_entries.enc');
      await original.writeAsBytes([99]);
      final backup = await _backup(
        root,
        sourceCatalog,
        lifecycle,
        provider,
        VaultCredential.password('correct horse battery'),
      );
      final installer = _Installer();
      final restoreLifecycle = _RestoreLifecycle();

      final result =
          await VaultRestoreService(
            catalog: restoreCatalog,
            keyInstaller: installer,
            lifecycle: restoreLifecycle,
            notifier: _Notifier(failNotification: true),
          ).restore(
            input: backup,
            credential: VaultCredential.password('correct horse battery'),
          );

      expect(result.restoredFiles, 2);
      expect(await original.readAsBytes(), [0, 1, 2, 3, 254, 255]);
      expect(
        await File('${restoreRoot.path}/encrypted_media/clip.vault').exists(),
        isTrue,
      );
      expect(installer.rollbacks, 0);
      expect(restoreLifecycle.storesOpen, isTrue);
      expect(restoreLifecycle.events, [
        'quiesce',
        'close',
        'reopen:true',
        'resume',
      ]);
    },
  );

  test('failed reopen closes partial stores before raw rollback', () async {
    final original = File('${restoreRoot.path}/journal_entries.enc');
    await original.writeAsBytes([99]);
    final backup = await _backup(
      root,
      sourceCatalog,
      lifecycle,
      provider,
      VaultCredential.password('correct horse battery'),
    );
    final restoreLifecycle = _RestoreLifecycle(failSuccessfulReopen: true);
    final installer = _Installer(
      onRollback: () {
        expect(restoreLifecycle.storesOpen, isFalse);
        restoreLifecycle.events.add('rollback-keys');
      },
    );

    await expectLater(
      VaultRestoreService(
        catalog: restoreCatalog,
        keyInstaller: installer,
        lifecycle: restoreLifecycle,
        notifier: _Notifier(),
      ).restore(
        input: backup,
        credential: VaultCredential.password('correct horse battery'),
      ),
      throwsA(isA<VaultRestoreException>()),
    );

    expect(await original.readAsBytes(), [99]);
    expect(
      await File('${restoreRoot.path}/encrypted_media/clip.vault').exists(),
      isFalse,
    );
    expect(installer.rollbacks, 1);
    expect(restoreLifecycle.storesOpen, isTrue);
    expect(restoreLifecycle.events, [
      'quiesce',
      'close',
      'reopen:true',
      'close-after-failed-reopen',
      'rollback-keys',
      'reopen:false',
      'resume',
    ]);
  });

  test('merge policy preserves rejected paths and unrelated files', () async {
    final original = File('${restoreRoot.path}/journal_entries.enc');
    await original.writeAsBytes([99]);
    final unrelated = File('${restoreRoot.path}/encrypted_media/local.vault');
    await unrelated.parent.create(recursive: true);
    await unrelated.writeAsBytes([42]);
    final backup = await _backup(
      root,
      sourceCatalog,
      lifecycle,
      provider,
      VaultCredential.password('correct horse battery'),
    );

    final result =
        await VaultRestoreService(
          catalog: restoreCatalog,
          keyInstaller: _Installer(),
          lifecycle: lifecycle,
          notifier: _Notifier(),
          mergePolicy: _KeepExistingPolicy(),
        ).restore(
          input: backup,
          credential: VaultCredential.password('correct horse battery'),
          mode: VaultRestoreMode.merge,
        );

    expect(result.skippedFiles, 1);
    expect(await original.readAsBytes(), [99]);
    expect(await unrelated.readAsBytes(), [42]);
  });

  test('rejects symlinked backup sources', () async {
    if (Platform.isWindows) return;
    final outside = File('${root.path}/outside.enc')..writeAsBytesSync([1]);
    final link = Link('${sourceRoot.path}/encrypted_media/link.vault');
    await link.create(outside.path);

    await expectLater(
      _backup(
        root,
        sourceCatalog,
        lifecycle,
        provider,
        VaultCredential.password('correct horse battery'),
      ),
      throwsA(isA<VaultBackupValidationException>()),
    );
  });

  test('enforces credential requirements', () {
    expect(
      () => VaultCredential.password('too-short'),
      throwsA(isA<VaultBackupValidationException>()),
    );
    expect(
      () => VaultCredential.bip39(
        'abandon abandon abandon abandon abandon abandon abandon abandon '
        'abandon abandon abandon abandon',
      ),
      throwsA(isA<VaultBackupValidationException>()),
    );
  });
}

VaultSourceCatalog _catalog(Directory root) => VaultSourceCatalog(
  restoreRoot: root,
  files: [
    VaultFileSource(
      file: File('${root.path}/journal_entries.enc'),
      relativePath: 'journal_entries.enc',
    ),
  ],
  directories: [
    VaultDirectorySource(
      directory: Directory('${root.path}/encrypted_media'),
      relativeRoot: 'encrypted_media',
    ),
  ],
);

Future<File> _backup(
  Directory root,
  VaultSourceCatalog catalog,
  _Lifecycle lifecycle,
  _KeyProvider provider,
  VaultCredential credential, {
  VaultZipCodec? codec,
  bool includeSyncPhrase = false,
}) async {
  final output = File(
    '${root.path}/backup_${DateTime.now().microsecondsSinceEpoch}.memoryvault',
  );
  await VaultBackupService(
    catalog: catalog,
    keyProvider: provider,
    lifecycle: lifecycle,
    zipCodec: codec,
  ).createBackup(
    output: output,
    credential: credential,
    includeSyncPhrase: includeSyncPhrase,
  );
  return output;
}

final class _Lifecycle implements VaultServiceLifecycle {
  int quiesces = 0;
  int resumes = 0;

  @override
  Future<void> quiesce() async => quiesces++;

  @override
  Future<void> resume() async => resumes++;
}

final class _KeyProvider implements VaultPortableKeyProvider {
  @override
  Future<VaultPortableKeyring> exportPortableKeys({
    required bool includeSyncPhrase,
  }) async => VaultPortableKeyring(
    keys: {
      VaultPortableKey.privateDataEncryption: Uint8List.fromList([7, 8, 9]),
    },
    syncPhrase: includeSyncPhrase ? 'portable sync phrase' : null,
  );
}

final class _Installer implements VaultPortableKeyInstaller {
  _Installer({this.onRollback});

  final void Function()? onRollback;
  int installs = 0;
  int rollbacks = 0;
  Map<VaultPortableKey, List<int>> copiedKeys = {};
  String? copiedSyncPhrase;

  @override
  Future<void> install(VaultPortableKeyring keyring) async {
    installs++;
    copiedKeys = {
      for (final entry in keyring.keys.entries)
        entry.key: List<int>.from(entry.value),
    };
    copiedSyncPhrase = keyring.syncPhrase;
  }

  @override
  Future<void> rollback() async {
    onRollback?.call();
    rollbacks++;
  }
}

final class _RestoreLifecycle implements VaultRestoreLifecycle {
  _RestoreLifecycle({this.failSuccessfulReopen = false});

  final bool failSuccessfulReopen;
  final events = <String>[];
  bool storesOpen = true;

  @override
  Future<void> quiesce() async => events.add('quiesce');

  @override
  Future<void> prepareRestore() async {
    storesOpen = false;
    events.add('close');
  }

  @override
  Future<void> finishRestore({required bool succeeded}) async {
    storesOpen = true;
    events.add('reopen:$succeeded');
    if (succeeded && failSuccessfulReopen) {
      throw StateError('injected reopen failure');
    }
  }

  @override
  Future<void> closeAfterFailedReopen() async {
    storesOpen = false;
    events.add('close-after-failed-reopen');
  }

  @override
  Future<void> resume() async => events.add('resume');
}

final class _Notifier implements VaultRestoreNotifier {
  _Notifier({this.failNotification = false});

  final bool failNotification;
  int resets = 0;
  int notifications = 0;

  @override
  Future<void> notifyProviders() async {
    notifications++;
    if (failNotification) throw StateError('injected notification failure');
  }

  @override
  Future<void> resetSyncState() async => resets++;
}

final class _KeepExistingPolicy implements VaultFileMergePolicy {
  @override
  Future<bool> shouldReplace({
    required String relativePath,
    required String existingSha256,
    required String backupSha256,
  }) async => false;
}

final class _TransformingCodec implements VaultZipCodec {
  _TransformingCodec(this.transform);

  final void Function(Map<String, Uint8List>) transform;
  final ArchiveVaultZipCodec delegate = const ArchiveVaultZipCodec();

  @override
  Map<String, Uint8List> decode(Uint8List bytes, VaultBackupLimits limits) {
    final entries = delegate.decode(bytes, limits);
    transform(entries);
    return entries;
  }

  @override
  Uint8List encode(Map<String, Uint8List> entries) => delegate.encode(entries);
}
