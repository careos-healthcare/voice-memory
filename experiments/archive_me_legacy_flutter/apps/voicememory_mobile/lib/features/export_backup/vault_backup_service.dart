import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'vault_backup_models.dart';
import 'vault_format.dart';

final class VaultBackupResult {
  const VaultBackupResult({
    required this.output,
    required this.fileCount,
    required this.totalPlaintextBytes,
  });

  final File output;
  final int fileCount;
  final int totalPlaintextBytes;
}

final class VaultBackupService {
  VaultBackupService({
    required this.catalog,
    required this.keyProvider,
    required this.lifecycle,
    this.limits = const VaultBackupLimits(),
    VaultZipCodec? zipCodec,
    VaultCryptography? cryptography,
    DateTime Function()? clock,
  }) : _zipCodec = zipCodec ?? const ArchiveVaultZipCodec(),
       _cryptography = cryptography ?? VaultCryptography(),
       _clock = clock ?? DateTime.now;

  final VaultSourceCatalog catalog;
  final VaultPortableKeyProvider keyProvider;
  final VaultServiceLifecycle lifecycle;
  final VaultBackupLimits limits;
  final VaultZipCodec _zipCodec;
  final VaultCryptography _cryptography;
  final DateTime Function() _clock;

  Future<VaultBackupResult> createBackup({
    required File output,
    required VaultCredential credential,
    bool includeSyncPhrase = false,
  }) async {
    if (!output.path.toLowerCase().endsWith('.memoryvault')) {
      throw const VaultBackupValidationException(
        'Backup output must use the .memoryvault extension.',
      );
    }
    await _rejectLink(output);
    await output.parent.create(recursive: true);
    final temporary = File(
      '${output.path}.$pid.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    final archiveEntries = SplayTreeMap<String, Uint8List>();
    Uint8List? zipBytes;
    Uint8List? envelopeBytes;
    VaultPortableKeyring? keyring;
    var quiesced = false;
    try {
      await lifecycle.quiesce();
      quiesced = true;
      final files = await _enumerate();
      if (files.length > limits.maxEntries) {
        throw const VaultBackupValidationException(
          'Backup contains too many files.',
        );
      }
      final now = _clock().toUtc();
      var total = 0;
      final manifestEntries = <VaultManifestEntry>[];
      for (final entry in files.entries) {
        final stat = await entry.value.stat();
        if (stat.size > limits.maxEntryBytes) {
          throw VaultBackupValidationException(
            'File exceeds backup size limit: ${entry.key}.',
          );
        }
        total += stat.size;
        if (total > limits.maxTotalBytes) {
          throw const VaultBackupValidationException(
            'Backup exceeds its total size limit.',
          );
        }
        final bytes = Uint8List.fromList(await entry.value.readAsBytes());
        if (bytes.length != stat.size) {
          wipeBytes(bytes);
          throw VaultBackupValidationException(
            'File changed while being backed up: ${entry.key}.',
          );
        }
        archiveEntries['$vaultDataPrefix${entry.key}'] = bytes;
        manifestEntries.add(
          VaultManifestEntry(
            schema: 1,
            relativePath: entry.key,
            size: bytes.length,
            sha256: vaultSha256(bytes),
            createdAt: now,
          ),
        );
      }

      keyring = await keyProvider.exportPortableKeys(
        includeSyncPhrase: includeSyncPhrase,
      );
      final keyringBytes = keyring.toBytes();
      archiveEntries[vaultKeyringPath] = keyringBytes;
      final manifest = VaultManifest(
        schema: VaultManifest.currentSchema,
        createdAt: now,
        entries: List.unmodifiable(manifestEntries),
        hasPortableKeyring: true,
      );
      archiveEntries[vaultManifestPath] = manifest.toBytes();
      zipBytes = _zipCodec.encode(UnmodifiableMapView(archiveEntries));
      if (zipBytes.length > limits.maxTotalBytes + 1024 * 1024) {
        throw const VaultBackupValidationException(
          'Encoded backup exceeds its size limit.',
        );
      }
      final envelope = await _cryptography.encrypt(zipBytes, credential);
      envelopeBytes = envelope.toBytes();
      if (envelopeBytes.length > limits.maxEnvelopeBytes) {
        throw const VaultBackupValidationException(
          'Encrypted backup exceeds its size limit.',
        );
      }
      await temporary.writeAsBytes(envelopeBytes, flush: true);
      await temporary.rename(output.path);
      return VaultBackupResult(
        output: output,
        fileCount: manifestEntries.length,
        totalPlaintextBytes: total,
      );
    } on VaultBackupException {
      await _wipeAndDelete(temporary);
      rethrow;
    } on Object catch (error) {
      await _wipeAndDelete(temporary);
      throw VaultBackupValidationException('Backup failed: $error');
    } finally {
      try {
        keyring?.wipe();
        for (final bytes in archiveEntries.values) {
          wipeBytes(bytes);
        }
        wipeBytes(zipBytes);
        wipeBytes(envelopeBytes);
      } finally {
        if (quiesced) {
          await lifecycle.resume();
        }
      }
    }
  }

  Future<SplayTreeMap<String, File>> _enumerate() async {
    final result = SplayTreeMap<String, File>();
    for (final source in catalog.files) {
      if (!await source.file.exists()) continue;
      await _add(result, source.relativePath, source.file);
    }
    for (final source in catalog.directories) {
      if (!await source.directory.exists()) continue;
      if (await FileSystemEntity.type(
            source.directory.path,
            followLinks: false,
          ) ==
          FileSystemEntityType.link) {
        throw VaultBackupValidationException(
          'Symlinked source root is forbidden: ${source.relativeRoot}.',
        );
      }
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
            'Symlinked backup entry is forbidden: ${entity.path}.',
          );
        }
        if (type != FileSystemEntityType.file) continue;
        if (!source.allowsFile(entity.path)) continue;
        final child = p.relative(entity.path, from: source.directory.path);
        final relativePath = p.posix.join(
          source.relativeRoot,
          p.split(child).join('/'),
        );
        await _add(result, relativePath, File(entity.path));
      }
    }
    return result;
  }

  Future<void> _add(
    SplayTreeMap<String, File> result,
    String relativePath,
    File file,
  ) async {
    validateSafeRelativePath(relativePath);
    await _ensureWithinSourceRoot(file, _rootFor(relativePath));
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw VaultBackupValidationException(
        'Backup source is not a regular file: $relativePath.',
      );
    }
    if (result.containsKey(relativePath)) {
      throw VaultBackupValidationException(
        'Duplicate allowlisted path: $relativePath.',
      );
    }
    result[relativePath] = file;
  }

  Directory _rootFor(String relativePath) {
    for (final source in catalog.files) {
      if (source.relativePath == relativePath) return source.containmentRoot;
    }
    for (final source in catalog.directories) {
      if (p.posix.isWithin(source.relativeRoot, relativePath)) {
        return source.directory;
      }
    }
    throw VaultBackupValidationException(
      'Backup source is not allowlisted: $relativePath.',
    );
  }

  Future<void> _ensureWithinSourceRoot(File file, Directory sourceRoot) async {
    final root = await sourceRoot.resolveSymbolicLinks();
    final resolved = await file.resolveSymbolicLinks();
    if (resolved != root && !p.isWithin(root, resolved)) {
      throw VaultBackupValidationException(
        'Backup source escapes its allowlisted root: ${file.path}.',
      );
    }
  }
}

Future<void> _rejectLink(File file) async {
  if (await FileSystemEntity.type(file.path, followLinks: false) ==
      FileSystemEntityType.link) {
    throw const VaultBackupValidationException(
      'Backup output cannot be a symlink.',
    );
  }
}

Future<void> _wipeAndDelete(File file) async {
  try {
    if (!await file.exists()) return;
    final length = await file.length();
    final handle = await file.open(mode: FileMode.writeOnly);
    try {
      const chunkSize = 64 * 1024;
      final zeroes = Uint8List(chunkSize);
      var remaining = length;
      while (remaining > 0) {
        final count = remaining > chunkSize ? chunkSize : remaining;
        await handle.writeFrom(zeroes, 0, count);
        remaining -= count;
      }
      await handle.flush();
    } finally {
      await handle.close();
    }
    await file.delete();
  } on Object {
    // Best effort after the original failure.
  }
}
