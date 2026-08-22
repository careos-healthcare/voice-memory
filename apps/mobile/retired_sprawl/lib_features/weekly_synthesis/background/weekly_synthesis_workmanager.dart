import 'dart:io';

import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/features/weekly_synthesis/background/weekly_synthesis_background_constraints.dart';
import 'package:archiveme_mobile/features/weekly_synthesis/background/weekly_synthesis_background_runner.dart';
import 'package:archiveme_mobile/features/weekly_synthesis/weekly_synthesis_config.dart';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

/// Top-level WorkManager entry point — must stay in this library for the VM.
@pragma('vm:entry-point')
void weeklySynthesisCallbackDispatcher() {
  Workmanager().executeTask((taskName, _) async {
    if (taskName != WeeklySynthesisConfig.taskName) {
      return true;
    }
    final outcome = await WeeklySynthesisBackgroundRunner.run();
    return outcome.workmanagerSuccess;
  });
}

/// Registers the weekly headless synthesis task with OS-appropriate constraints.
abstract final class WeeklySynthesisWorkScheduler {
  WeeklySynthesisWorkScheduler._();

  static var _initialized = false;

  static bool get isSupported =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  static Future<void> initialize() async {
    if (!V1CapabilityRegistry.backgroundProcessing ||
        !isSupported ||
        _initialized) {
      return;
    }
    await Workmanager().initialize(weeklySynthesisCallbackDispatcher);
    _initialized = true;
  }

  static Future<void> registerWeeklyTask() async {
    if (!V1CapabilityRegistry.backgroundProcessing ||
        !isSupported ||
        !_initialized) {
      return;
    }

    await Workmanager().registerPeriodicTask(
      WeeklySynthesisConfig.taskUniqueName,
      WeeklySynthesisConfig.taskName,
      frequency: const Duration(days: 7),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: true,
        requiresStorageNotLow: true,
      ),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(hours: 6),
      inputData: const {'pipeline': 'weekly_topic_synthesis_v1'},
    );
  }

  /// Debug-only immediate run — never blocks UI; OS may still defer execution.
  static Future<void> enqueueDebugOneOff() async {
    if (!V1CapabilityRegistry.backgroundProcessing ||
        !isSupported ||
        !_initialized ||
        kReleaseMode) {
      return;
    }
    await Workmanager().registerOneOffTask(
      '${WeeklySynthesisConfig.taskUniqueName}.debug',
      WeeklySynthesisConfig.taskName,
      existingWorkPolicy: ExistingWorkPolicy.replace,
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: true,
      ),
    );
  }
}
