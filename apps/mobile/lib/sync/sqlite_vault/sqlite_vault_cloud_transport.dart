import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/sync/sqlite_vault/sqlite_vault_config.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:icloud_storage/icloud_storage.dart';

/// Cloud transport for encrypted SQLite vault blobs.
///
/// Only ciphertext files are ever passed to implementations.
abstract class SqliteVaultCloudTransport {
  Future<bool> isAvailable();

  Future<void> uploadEncryptedVault({
    required String localEncryptedFilePath,
    required String cloudRelativePath,
    void Function(double progress)? onProgress,
  });

  Future<void> downloadEncryptedVault({
    required String cloudRelativePath,
    required String localDestinationFilePath,
    void Function(double progress)? onProgress,
  });
}

/// Uploads sealed vault blobs to a private iCloud ubiquity container.
final class ICloudSqliteVaultTransport implements SqliteVaultCloudTransport {
  ICloudSqliteVaultTransport({
    this.containerId = SqliteVaultConfig.iCloudContainerId,
  });

  final String containerId;

  @override
  Future<bool> isAvailable() async {
    if (kIsWeb || !(Platform.isIOS || Platform.isMacOS)) {
      return false;
    }

    try {
      await ICloudStorage.gather(containerId: containerId);
      return true;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> downloadEncryptedVault({
    required String cloudRelativePath,
    required String localDestinationFilePath,
    void Function(double progress)? onProgress,
  }) async {
    await ICloudStorage.download(
      containerId: containerId,
      relativePath: cloudRelativePath,
      destinationFilePath: localDestinationFilePath,
      onProgress: onProgress == null
          ? null
          : (stream) => _listenProgress(stream, onProgress),
    );
  }

  @override
  Future<void> uploadEncryptedVault({
    required String localEncryptedFilePath,
    required String cloudRelativePath,
    void Function(double progress)? onProgress,
  }) async {
    await ICloudStorage.upload(
      containerId: containerId,
      filePath: localEncryptedFilePath,
      destinationRelativePath: cloudRelativePath,
      onProgress: onProgress == null
          ? null
          : (stream) => _listenProgress(stream, onProgress),
    );
  }

  void _listenProgress(Stream<double> stream, void Function(double) onProgress) {
    stream.listen(onProgress, onError: (_) {});
  }
}

/// In-memory transport for unit tests — no network or iCloud required.
final class InMemorySqliteVaultCloudTransport implements SqliteVaultCloudTransport {
  final Map<String, List<int>> _objects = {};

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> downloadEncryptedVault({
    required String cloudRelativePath,
    required String localDestinationFilePath,
    void Function(double progress)? onProgress,
  }) async {
    final bytes = _objects[cloudRelativePath];
    if (bytes == null) {
      throw SqliteVaultCloudTransportException('VAULT_NOT_FOUND');
    }
    await File(localDestinationFilePath).writeAsBytes(bytes, flush: true);
    onProgress?.call(1);
  }

  @override
  Future<void> uploadEncryptedVault({
    required String localEncryptedFilePath,
    required String cloudRelativePath,
    void Function(double progress)? onProgress,
  }) async {
    final bytes = await File(localEncryptedFilePath).readAsBytes();
    _objects[cloudRelativePath] = bytes;
    onProgress?.call(1);
  }

  bool hasObject(String cloudRelativePath) =>
      _objects.containsKey(cloudRelativePath);
}

class SqliteVaultCloudTransportException implements Exception {
  SqliteVaultCloudTransportException(this.code);
  final String code;

  @override
  String toString() => 'SqliteVaultCloudTransportException($code)';
}
