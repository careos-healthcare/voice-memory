import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

typedef RecoveryClipboardWriter = Future<void> Function(String value);
typedef RecoveryPrintHandoff = Future<void> Function(File file, String subject);
typedef RecoveryTemporaryDirectory = Future<Directory> Function();

/// Handles the two deliberate ways a one-time recovery code may leave memory.
///
/// The printable file exists only for the duration of the platform handoff and
/// is deleted whether that handoff succeeds, is cancelled, or throws.
class SyncRecoveryCodeActions {
  SyncRecoveryCodeActions({
    RecoveryClipboardWriter? clipboardWriter,
    RecoveryPrintHandoff? printHandoff,
    RecoveryTemporaryDirectory? temporaryDirectory,
  }) : _clipboardWriter =
           clipboardWriter ??
           ((value) => Clipboard.setData(ClipboardData(text: value))),
       _printHandoff =
           printHandoff ??
           ((file, subject) async {
             await Share.shareXFiles([XFile(file.path)], subject: subject);
           }),
       _temporaryDirectory =
           temporaryDirectory ?? (() => getTemporaryDirectory());

  final RecoveryClipboardWriter _clipboardWriter;
  final RecoveryPrintHandoff _printHandoff;
  final RecoveryTemporaryDirectory _temporaryDirectory;
  static const String _directoryPrefix = '.archiveme_recovery_print_';

  Future<void> copy(String recoveryCode) => _clipboardWriter(recoveryCode);

  Future<void> printInstructions({
    required String recoveryCode,
    required DateTime createdAt,
    required int envelopeRevision,
  }) async {
    Directory? workDirectory;
    try {
      final temporaryRoot = await _temporaryDirectory();
      await temporaryRoot.create(recursive: true);
      await _cleanupStale(temporaryRoot);
      workDirectory = await temporaryRoot.createTemp(_directoryPrefix);
      final canonicalRoot = await temporaryRoot.resolveSymbolicLinks();
      final canonicalWork = await workDirectory.resolveSymbolicLinks();
      if (!p.isWithin(canonicalRoot, canonicalWork)) {
        throw const FileSystemException(
          'Recovery print directory escaped its private temporary root.',
        );
      }
      final printable = File(
        p.join(workDirectory.path, 'recovery-instructions.txt'),
      );
      if (await FileSystemEntity.type(printable.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw const FileSystemException(
          'Recovery print target already exists.',
        );
      }
      await printable.writeAsString(
        buildPrintableInstructions(
          recoveryCode: recoveryCode,
          createdAt: createdAt,
          envelopeRevision: envelopeRevision,
        ),
        flush: true,
      );
      await _printHandoff(printable, 'ArchiveMe recovery instructions');
    } finally {
      if (workDirectory != null) {
        try {
          if (await workDirectory.exists()) {
            await workDirectory.delete(recursive: true);
          }
        } on Object {
          // Best effort after the platform has taken ownership of the handoff.
        }
      }
    }
  }

  static Future<void> _cleanupStale(Directory temporaryRoot) async {
    await for (final entity in temporaryRoot.list(followLinks: false)) {
      if (entity is! Directory ||
          !p.basename(entity.path).startsWith(_directoryPrefix)) {
        continue;
      }
      await entity.delete(recursive: true);
    }
  }

  static String buildPrintableInstructions({
    required String recoveryCode,
    required DateTime createdAt,
    required int envelopeRevision,
  }) {
    final date = createdAt.toUtc().toIso8601String();
    return '''
ArchiveMe encrypted sync recovery

Recovery code
$recoveryCode

Created: $date
Safe reference: recovery revision $envelopeRevision

How to use it
1. Sign in to the same ArchiveMe account.
2. Open Encrypted sync recovery.
3. Enter the complete recovery code to recover the encrypted sync key.

Warnings
- Recovery requires both the same account and this code.
- Store this page offline, separately from your signed-in devices.
- Anyone with account access and this code may recover the encrypted archive.
- If every device holding the sync key and this code are lost, recovery is permanently impossible.
- Replacing or disabling recovery makes this code unusable.
- Keep an ordinary archive export separately before disabling recovery or deleting your account.
''';
  }
}
