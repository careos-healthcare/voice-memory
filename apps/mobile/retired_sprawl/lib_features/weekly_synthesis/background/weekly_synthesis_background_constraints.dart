import 'dart:async';

import 'package:archiveme_mobile/core/hardware/resource_guard.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';

/// OS-aware guardrails for weekly Gemma synthesis in headless tasks.
abstract final class WeeklySynthesisBackgroundConstraints {
  WeeklySynthesisBackgroundConstraints._();

  static const _backgroundBatteryThreshold = 20;

  /// Returns false when the OS/device state should defer inference to a later run.
  static Future<bool> canRunInference({
    ResourceGuard? resourceGuard,
  }) async {
    if (kIsWeb) return false;

    final guard = resourceGuard ?? ResourceGuard.shared;
    final profile = await guard.buildInferenceProfile();
    if (!profile.canExecute) {
      return false;
    }

    final battery = Battery();
    final level = await battery.batteryLevel;
    final state = await battery.batteryState;
    final charging = state == BatteryState.charging || state == BatteryState.full;
    if (level >= 0 && level < _backgroundBatteryThreshold && !charging) {
      return false;
    }

    return true;
  }

  /// Runs [action] but returns null when the soft time budget elapses first.
  static Future<T?> runWithTimeBudget<T>({
    required Duration budget,
    required Future<T> Function() action,
  }) async {
    try {
      return await action().timeout(budget);
    } on TimeoutException {
      return null;
    }
  }
}

enum WeeklySynthesisBackgroundOutcome {
  success,
  skippedAlreadyGenerated,
  skippedNoRecurrentTopics,
  skippedNoDatabase,
  deferredConstraints,
  deferredModelMissing,
  deferredInferenceTimeout,
  failed,
}

extension WeeklySynthesisBackgroundOutcomeX on WeeklySynthesisBackgroundOutcome {
  /// WorkManager should retry deferred/failed outcomes; skip others are success.
  bool get workmanagerSuccess => switch (this) {
        WeeklySynthesisBackgroundOutcome.success ||
        WeeklySynthesisBackgroundOutcome.skippedAlreadyGenerated ||
        WeeklySynthesisBackgroundOutcome.skippedNoRecurrentTopics ||
        WeeklySynthesisBackgroundOutcome.skippedNoDatabase =>
          true,
        WeeklySynthesisBackgroundOutcome.deferredConstraints ||
        WeeklySynthesisBackgroundOutcome.deferredModelMissing ||
        WeeklySynthesisBackgroundOutcome.deferredInferenceTimeout ||
        WeeklySynthesisBackgroundOutcome.failed =>
          false,
      };
}
