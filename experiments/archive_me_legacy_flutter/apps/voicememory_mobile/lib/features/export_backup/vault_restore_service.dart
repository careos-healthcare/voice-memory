import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'vault_backup_models.dart';
import 'vault_format.dart';

final class VaultRestoreResult {
  const VaultRestoreResult({
    required this.restoredFiles,
    required this.skippedFiles,
  });

  final int restoredFiles;
  final int skippedFiles;
}

final class VaultRestoreService {
  VaultRestoreService({
    required this.catalog,
    required this.keyInstaller,
    required this.lifecycle,
    required this.notifier,
    this.mergePolicy = const VaultBackupWinsMergePolicy(),
    this.limits = const VaultBackupLimits(),
    VaultZipCodec? zipCodec,
    VaultCryptography? cryptography,
  }) : _zipCodec = zipCodec ?? const ArchiveVaultZipCodec(),
       _cryptography = cryptography ?? VaultCryptography();

  final VaultSourceCatalog catalog;
  final VaultPortableKeyInstaller keyInstaller;
  final VaultServiceLifecycle lifecycle;
  final VaultRestoreNotifier notifier;
  final VaultFileMergePolicy mergePolicy;
  final VaultBackupLimits limits;
  final VaultZipCodec _zipCodec;
  final VaultCryptography _cryptography;

  Future<VaultRestoreResult> restore({
    required File input,
    required VaultCredential credential,
    VaultRestoreMode mode = VaultRestoreMode.replace,
  }) async {
    if (!await input.exists()) {
      throw const VaultRestoreException('Backup file does not exist.');
    }
    for (final root in {
      catalog.restoreRoot,
      ...catalog.destinationRoots.values,
    }) {
      if (await FileSystemEntity.type(root.path, followLinks: false) ==
          FileSystemEntityType.link) {
        throw const VaultBackupValidationException(
          'Restore root cannot be a symlink.',
        );
      }
    }
    if (await input.length() > limits.maxEnvelopeBytes) {
      throw const VaultBackupValidationException(
        'Backup envelope exceeds its size limit.',
      );
    }
    Uint8List? envelopeBytes;
    Uint8List? zipBytes;
    Map<String, Uint8List>? archive;
    VaultPortableKeyring? keyring;
    Directory? transactionRoot;
    final restoreLifecycle = lifecycle is VaultRestoreLifecycle
        ? lifecycle as VaultRestoreLifecycle
        : null;
    var quiesced = false;
    var storesClosed = false;
    var reopenAttempted = false;
    var reopenSucceeded = false;
    var installStarted = false;
    var swapsStarted = false;
    var failed = false;
    final movedExisting = <String, File>{};
    final createdDestinations = <File>[];
    try {
      // Phase 1: authenticate and validate without touching live state.
      envelopeBytes = Uint8List.fromList(await input.readAsBytes());
      final envelope = VaultEnvelope.fromBytes(envelopeBytes);
      // GCM authentication completes before any ZIP or manifest bytes parse.
      zipBytes = await _cryptography.decrypt(envelope, credential);
      archive = _zipCodec.decode(zipBytes, limits);
      final validated = _validateArchive(archive);
      keyring = validated.keyring;

      // Phase 2: quiesce writers and close every file-backed store.
      await lifecycle.quiesce();
      quiesced = true;
      if (restoreLifecycle != null) {
        await restoreLifecycle.prepareRestore();
        storesClosed = true;
      }

      // Phase 3: stage, install keys, and swap files while stores are closed.
      transactionRoot = await catalog.restoreRoot.createTemp(
        '.memoryvault-restore-',
      );
      final stagedRoot = Directory(p.join(transactionRoot.path, 'staged'));
      final rollbackRoot = Directory(p.join(transactionRoot.path, 'rollback'));
      await stagedRoot.create(recursive: true);
      await rollbackRoot.create(recursive: true);

      final selected = <VaultManifestEntry>[];
      var skipped = 0;
      for (final entry in validated.manifest.entries) {
        final destination = catalog.destinationFor(entry.relativePath);
        if (mode == VaultRestoreMode.merge && await destination.exists()) {
          final existing = await destination.readAsBytes();
          final replace = await mergePolicy.shouldReplace(
            relativePath: entry.relativePath,
            existingSha256: vaultSha256(existing),
            backupSha256: entry.sha256,
          );
          wipeBytes(existing);
          if (!replace) {
            skipped += 1;
            continue;
          }
        }
        final staged = _childFile(stagedRoot, entry.relativePath);
        await staged.parent.create(recursive: true);
        await staged.writeAsBytes(
          archive['$vaultDataPrefix${entry.relativePath}']!,
          flush: true,
        );
        selected.add(entry);
      }

      installStarted = true;
      await keyInstaller.install(keyring);

      final removals = mode == VaultRestoreMode.replace
          ? await _replaceModeRemovals(
              validated.manifest.entries.map((entry) => entry.relativePath),
            )
          : <String>[];
      swapsStarted = true;
      for (final relativePath in {
        ...selected.map((entry) => entry.relativePath),
        ...removals,
      }) {
        final destination = catalog.destinationFor(relativePath);
        await _rejectSymlinkedDestination(relativePath, destination);
        if (await destination.exists()) {
          final rollback = _childFile(rollbackRoot, relativePath);
          await rollback.parent.create(recursive: true);
          await destination.rename(rollback.path);
          movedExisting[relativePath] = rollback;
        } else {
          createdDestinations.add(destination);
        }
        if (removals.contains(relativePath)) continue;
        final staged = _childFile(stagedRoot, relativePath);
        await destination.parent.create(recursive: true);
        await staged.rename(destination.path);
      }

      // Phase 4: reset sync state and make the installed keys durable.
      await notifier.resetSyncState();
      if (keyInstaller case final VaultTransactionalKeyInstaller installer) {
        await installer.commit();
      }

      // Phase 5: reopen against the restored files. Once this succeeds, raw
      // rollback is forbidden because stores may have live handles.
      if (restoreLifecycle != null) {
        reopenAttempted = true;
        await restoreLifecycle.finishRestore(succeeded: true);
        storesClosed = false;
      }
      reopenSucceeded = true;
      if (keyInstaller
          case final VaultFinalizableTransactionalKeyInstaller installer) {
        await installer.finalizeCommit();
      }

      // Phase 6: provider refresh is best-effort and must never mutate files.
      try {
        await notifier.notifyProviders();
      } on Object {
        // Restored stores are already live; callers can refresh on next launch.
      }
      return VaultRestoreResult(
        restoredFiles: selected.length,
        skippedFiles: skipped,
      );
    } on Object catch (error) {
      failed = true;
      if (!reopenSucceeded) {
        if (restoreLifecycle != null && reopenAttempted) {
          // A failed reopen may have opened only part of AppServices. Close it
          // explicitly before any raw file or key rollback.
          await restoreLifecycle.closeAfterFailedReopen();
          storesClosed = true;
        }
        if (restoreLifecycle == null || storesClosed) {
          if (swapsStarted) {
            try {
              await _rollbackFiles(movedExisting, createdDestinations);
            } on Object {
              // Continue key rollback and preserve the initiating failure.
            }
          }
          if (installStarted) {
            try {
              await keyInstaller.rollback();
            } on Object {
              // Preserve the failure that triggered rollback.
            }
          }
        }
        if (restoreLifecycle != null && storesClosed) {
          await restoreLifecycle.finishRestore(succeeded: false);
          storesClosed = false;
        }
      }
      if (error is VaultBackupAuthenticationException ||
          error is VaultBackupValidationException ||
          error is VaultRestoreException) {
        rethrow;
      }
      throw VaultRestoreException('Restore failed: $error');
    } finally {
      try {
        keyring?.wipe();
        if (archive != null) {
          for (final bytes in archive.values) {
            wipeBytes(bytes);
          }
        }
        wipeBytes(zipBytes);
        wipeBytes(envelopeBytes);
        if (transactionRoot != null) {
          await _wipeTree(transactionRoot);
        }
      } finally {
        if (quiesced) {
          if (failed) {
            try {
              await lifecycle.resume();
            } on Object {
              // Preserve the restore failure.
            }
          } else {
            await lifecycle.resume();
          }
        }
      }
    }
  }

  _ValidatedVault _validateArchive(Map<String, Uint8List> archive) {
    for (final archivePath in archive.keys) {
      validateSafeRelativePath(archivePath);
    }
    final manifestBytes = archive[vaultManifestPath];
    if (manifestBytes == null) {
      throw const VaultBackupValidationException('Manifest is missing.');
    }
    final manifest = VaultManifest.fromBytes(manifestBytes);
    if (manifest.entries.length > limits.maxEntries) {
      throw const VaultBackupValidationException('Too many manifest entries.');
    }
    var total = 0;
    final expected = <String>{vaultManifestPath};
    for (final entry in manifest.entries) {
      if (!catalog.allows(entry.relativePath)) {
        throw VaultBackupValidationException(
          'Path is not in the restore allowlist: ${entry.relativePath}.',
        );
      }
      if (entry.size > limits.maxEntryBytes) {
        throw VaultBackupValidationException(
          'Manifest entry exceeds its size limit: ${entry.relativePath}.',
        );
      }
      total += entry.size;
      if (total > limits.maxTotalBytes) {
        throw const VaultBackupValidationException(
          'Manifest exceeds its total size limit.',
        );
      }
      final archivePath = '$vaultDataPrefix${entry.relativePath}';
      if (!expected.add(archivePath)) {
        throw const VaultBackupValidationException(
          'Duplicate manifest archive path.',
        );
      }
      final bytes = archive[archivePath];
      if (bytes == null ||
          bytes.length != entry.size ||
          vaultSha256(bytes) != entry.sha256) {
        throw VaultBackupValidationException(
          'Checksum or size mismatch: ${entry.relativePath}.',
        );
      }
    }
    if (!manifest.hasPortableKeyring || archive[vaultKeyringPath] == null) {
      throw const VaultBackupValidationException(
        'Portable encryption keyring is missing.',
      );
    }
    expected.add(vaultKeyringPath);
    if (archive.keys.toSet().length != expected.length ||
        !archive.keys.toSet().containsAll(expected)) {
      throw const VaultBackupValidationException(
        'ZIP contains unlisted entries.',
      );
    }
    return _ValidatedVault(
      manifest: manifest,
      keyring: VaultPortableKeyring.fromBytes(archive[vaultKeyringPath]!),
    );
  }

  Future<List<String>> _replaceModeRemovals(
    Iterable<String> incomingPaths,
  ) async {
    final incoming = incomingPaths.toSet();
    final existing = <String>{};
    for (final source in catalog.files) {
      if (await source.file.exists()) existing.add(source.relativePath);
    }
    for (final source in catalog.directories) {
      if (!await source.directory.exists()) continue;
      await for (final entity in source.directory.list(
        recursive: true,
        followLinks: false,
      )) {
        final type = await FileSystemEntity.type(
          entity.path,
          followLinks: false,
        );
        if (type == FileSystemEntityType.link) {
          throw VaultBackupValidationException(
            'Symlink in restore target: ${entity.path}.',
          );
        }
        if (type != FileSystemEntityType.file) continue;
        if (!source.allowsFile(entity.path)) continue;
        final child = p.relative(entity.path, from: source.directory.path);
        existing.add(
          p.posix.join(source.relativeRoot, p.split(child).join('/')),
        );
      }
    }
    return existing.difference(incoming).toList()..sort();
  }

  Future<void> _rejectSymlinkedDestination(
    String relativePath,
    File destination,
  ) async {
    final root = p.canonicalize(
      catalog.destinationRootFor(relativePath).absolute.path,
    );
    var current = destination.parent;
    while (p.canonicalize(current.absolute.path) != root) {
      final type = await FileSystemEntity.type(
        current.path,
        followLinks: false,
      );
      if (type == FileSystemEntityType.link) {
        throw VaultBackupValidationException(
          'Symlinked restore directory: ${current.path}.',
        );
      }
      current = current.parent;
    }
    if (await FileSystemEntity.type(destination.path, followLinks: false) ==
        FileSystemEntityType.link) {
      throw VaultBackupValidationException(
        'Symlinked restore file: ${destination.path}.',
      );
    }
  }

  Future<void> _rollbackFiles(
    Map<String, File> movedExisting,
    List<File> created,
  ) async {
    for (final destination in created.reversed) {
      if (await destination.exists()) await destination.delete();
    }
    for (final entry in movedExisting.entries.toList().reversed) {
      final destination = catalog.destinationFor(entry.key);
      if (await destination.exists()) await destination.delete();
      await destination.parent.create(recursive: true);
      await entry.value.rename(destination.path);
    }
  }
}

final class _ValidatedVault {
  const _ValidatedVault({required this.manifest, required this.keyring});

  final VaultManifest manifest;
  final VaultPortableKeyring keyring;
}

File _childFile(Directory root, String relativePath) {
  validateSafeRelativePath(relativePath);
  return File(p.joinAll([root.path, ...p.posix.split(relativePath)]));
}

Future<void> _wipeTree(Directory root) async {
  try {
    if (!await root.exists()) return;
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (type != FileSystemEntityType.file) continue;
      final length = await entity.length();
      final handle = await entity.open(mode: FileMode.writeOnly);
      try {
        final zeroes = Uint8List(64 * 1024);
        var remaining = length;
        while (remaining > 0) {
          final count = remaining > zeroes.length ? zeroes.length : remaining;
          await handle.writeFrom(zeroes, 0, count);
          remaining -= count;
        }
        await handle.flush();
      } finally {
        await handle.close();
      }
    }
    await root.delete(recursive: true);
  } on Object {
    // Best-effort secure cleanup must not mask the primary result.
  }
}
