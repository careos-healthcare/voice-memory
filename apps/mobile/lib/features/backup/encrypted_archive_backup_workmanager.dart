import 'dart:io';

import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

const encryptedArchiveBackupTaskName = 'encrypted_archive_weekly_backup';
const encryptedArchiveBackupUniqueName = 'com.voicememory.mobile.weeklyBackup';

/// Top-level WorkManager entry. The task body is [encryptedArchiveBackupRunner].
@pragma('vm:entry-point')
void encryptedArchiveBackupCallbackDispatcher() {
  Workmanager().executeTask((taskName, _) async {
    if (taskName != encryptedArchiveBackupTaskName) return true;
    if (!V1CapabilityRegistry.encryptedBackup) return true;
    final runner = encryptedArchiveBackupRunner;
    if (runner == null) return true;
    return runner();
  });
}

/// Set by the app isolate before the weekly task is registered.
Future<bool> Function()? encryptedArchiveBackupRunner;

abstract final class EncryptedArchiveBackupScheduler {
  EncryptedArchiveBackupScheduler._();

  static var _initialized = false;

  static bool get isSupported =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  static Future<void> registerWeekly({
    required Future<bool> Function() runner,
  }) async {
    if (!V1CapabilityRegistry.encryptedBackup || !isSupported) return;
    encryptedArchiveBackupRunner = runner;
    if (!_initialized) {
      await Workmanager().initialize(encryptedArchiveBackupCallbackDispatcher);
      _initialized = true;
    }
    await Workmanager().registerPeriodicTask(
      encryptedArchiveBackupUniqueName,
      encryptedArchiveBackupTaskName,
      frequency: const Duration(days: 7),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: true,
        requiresStorageNotLow: true,
      ),
    );
  }
}
