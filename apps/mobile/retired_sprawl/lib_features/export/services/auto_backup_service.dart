import 'dart:io';
import 'dart:math';

import 'package:archiveme_mobile/core/config/launch_profile.dart';
import 'package:archiveme_mobile/core/crypto/account_sync_key.dart';
import 'package:archiveme_mobile/features/export/services/archive_transfer_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Writes a passphrase-sealed journal zip when a week has passed since the
/// last copy, and keeps the three newest files.
class AutoBackupService {
  AutoBackupService({
    required this.readEnabled,
    required this.readLastBackup,
    required this.writeLastBackup,
    required this.loadEntries,
    required this.exportZip,
    required this.destinationDirectory,
    this.now,
  });

  static const preferenceKey = 'auto_encrypted_backup_weekly';
  static const lastBackupKey = 'auto_encrypted_backup_last_at';
  static const passphraseKey = 'auto_encrypted_backup_passphrase';
  static const interval = Duration(days: 7);
  static const retainedBackups = 4;
  static const folderPreferenceKey = 'auto_encrypted_backup_folder';
  static const filePrefix = 'thoughtprint-backup-';

  final Future<bool> Function() readEnabled;
  final Future<DateTime?> Function() readLastBackup;
  final Future<void> Function(DateTime at) writeLastBackup;
  final Future<List<JournalEntry>> Function() loadEntries;
  final Future<List<int>> Function(List<JournalEntry> entries) exportZip;
  final Future<Directory> Function() destinationDirectory;
  final DateTime Function()? now;

  /// Silent check used when the app opens or returns to the foreground.
  static Future<bool> runScheduled({bool force = false}) async {
    if (!LaunchProfile.AUTO_ENCRYPTED_BACKUP || !AppServices.isInitialized) {
      return false;
    }
    try {
      final prefs = AppServices.instance.prefs;
      final service = AutoBackupService(
        readEnabled: () async => await prefs.readBool(preferenceKey) ?? true,
        readLastBackup: () async {
          final raw = await prefs.readString(lastBackupKey);
          return raw == null ? null : DateTime.tryParse(raw);
        },
        writeLastBackup: (at) => prefs.writeString(lastBackupKey, at.toUtc().toIso8601String()),
        loadEntries: () => AppServices.instance.journal.loadAll(),
        exportZip: (entries) async {
          final passphrase = await _passphrase();
          final existing = await AccountSyncKey.readBundle();
          final bundle = existing ??
              await AccountSyncKey.wrap(
                accountKey: AccountSyncKey.generate(),
                passphrase: passphrase,
                recoveryPhrase: AccountSyncKey.recoveryPhrase(),
              );
          if (existing == null) {
            await AccountSyncKey.storeBundle(bundle);
          }
          final accountKey = await AccountSyncKey.unwrap(
            wrapped: bundle.wrappedByPassphrase,
            secret: passphrase,
          );
          return ArchiveTransferService.exportZip(
            accountKey: accountKey,
            entries: entries,
          );
        },
        destinationDirectory: backupDirectory,
      );
      return service.runIfDue(force: force);
    } on Object {
      return false;
    }
  }

  static String statusLabel(DateTime? last, DateTime now) {
    if (last == null) return 'Not backed up yet';
    final days = now.toUtc().difference(last.toUtc()).inDays;
    if (days <= 0) return 'Backed up today';
    if (days == 1) return 'Backed up 1 day ago';
    return 'Backed up $days days ago';
  }

  /// Documents on iOS, so Files and iCloud Drive can show the zip.
  /// On Android, a folder chosen with the system picker is used when set.
  static Future<Directory> backupDirectory() async {
    if (AppServices.isInitialized) {
      final chosen = await AppServices.instance.prefs.readString(
        folderPreferenceKey,
      );
      if (chosen != null && chosen.trim().isNotEmpty) {
        return Directory(chosen.trim());
      }
    }
    if (!kIsWeb && Platform.isAndroid) {
      final external = await getExternalStorageDirectory();
      final root = external ?? await getApplicationDocumentsDirectory();
      return Directory('${root.path}/ThoughtprintBackups');
    }
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/ThoughtprintBackups');
  }

  Future<bool> runIfDue({bool force = false}) async {
    if (!LaunchProfile.AUTO_ENCRYPTED_BACKUP) return false;
    if (!await readEnabled()) return false;
    final clock = (now ?? DateTime.now)().toUtc();
    final last = await readLastBackup();
    if (!force &&
        last != null &&
        clock.difference(last.toUtc()) < interval) {
      return false;
    }
    final bytes = await exportZip(await loadEntries());
    final directory = await destinationDirectory();
    await directory.create(recursive: true);
    final stamp = clock.toIso8601String().replaceAll(':', '');
    final file = File('${directory.path}/$filePrefix$stamp.zip');
    await file.writeAsBytes(bytes, flush: true);
    await prune(directory);
    await writeLastBackup(clock);
    return true;
  }

  static Future<void> prune(Directory directory) async {
    if (!await directory.exists()) return;
    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) {
          final name = file.uri.pathSegments.last;
          return name.startsWith(filePrefix) && name.endsWith('.zip');
        })
        .toList();
    files.sort(
      (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
    );
    for (final extra in files.skip(retainedBackups)) {
      await extra.delete();
    }
  }

  static Future<String> _passphrase() async {
    final box = AppServices.instance.secureStorage;
    final stored = await box.read(passphraseKey);
    if (stored != null && stored.trim().length >= 8) return stored.trim();
    final generated = _randomPassphrase();
    await box.write(passphraseKey, generated);
    return generated;
  }

  static String _randomPassphrase() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}
