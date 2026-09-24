import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/sync/sqlite_vault/sqlite_vault_cloud_transport.dart';
import 'package:archiveme_mobile/sync/sqlite_vault/sqlite_vault_config.dart';

/// Where a sealed archive is written. Implementations receive ciphertext only.
abstract class EncryptedArchiveBackupDestination {
  Future<void> write(Uint8List sealed);

  Future<Uint8List> read();
}

/// iCloud Drive ubiquity container `iCloud.com.voicememory.mobile`.
class ICloudEncryptedArchiveBackupDestination
    implements EncryptedArchiveBackupDestination {
  ICloudEncryptedArchiveBackupDestination({
    SqliteVaultCloudTransport? transport,
    this.relativePath = 'backups/thoughtprint-archive.vmab',
  }) : _transport = transport ?? ICloudSqliteVaultTransport();

  final SqliteVaultCloudTransport _transport;
  final String relativePath;

  @override
  Future<Uint8List> read() async {
    final temp = File(
      '${Directory.systemTemp.path}/thoughtprint-archive-download.vmab',
    );
    await _transport.downloadEncryptedVault(
      cloudRelativePath: relativePath,
      localDestinationFilePath: temp.path,
    );
    return temp.readAsBytes();
  }

  @override
  Future<void> write(Uint8List sealed) async {
    final temp = File(
      '${Directory.systemTemp.path}/thoughtprint-archive-upload.vmab',
    );
    await temp.writeAsBytes(sealed, flush: true);
    await _transport.uploadEncryptedVault(
      localEncryptedFilePath: temp.path,
      cloudRelativePath: relativePath,
    );
  }
}

/// Android Storage Access Framework / Google Drive location the user picked.
class FileEncryptedArchiveBackupDestination
    implements EncryptedArchiveBackupDestination {
  FileEncryptedArchiveBackupDestination(this.file);

  final File file;

  @override
  Future<Uint8List> read() => file.readAsBytes();

  @override
  Future<void> write(Uint8List sealed) async {
    await file.parent.create(recursive: true);
    await file.writeAsBytes(sealed, flush: true);
  }
}

/// Confirms the iCloud container id used by the destination.
const String encryptedArchiveICloudContainerId =
    SqliteVaultConfig.iCloudContainerId;
