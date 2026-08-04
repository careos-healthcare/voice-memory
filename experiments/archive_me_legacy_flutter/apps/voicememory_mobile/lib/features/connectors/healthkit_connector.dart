import 'package:health/health.dart';
import 'package:workmanager/workmanager.dart';

import '../../storage/mobile_prefs_store.dart';
import 'external_data_adapters.dart';
import 'external_graph_service.dart';

abstract interface class HealthDataSource {
  Future<bool> authorize();
  Future<HealthDailySample> readDay(DateTime day);
}

class PlatformHealthDataSource implements HealthDataSource {
  PlatformHealthDataSource({Health? health}) : _health = health ?? Health();

  final Health _health;
  static const _types = [
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.STEPS,
    HealthDataType.RESTING_HEART_RATE,
  ];

  @override
  Future<bool> authorize() async {
    await _health.configure();
    return _health.requestAuthorization(
      _types,
      permissions: List.filled(_types.length, HealthDataAccess.READ),
    );
  }

  @override
  Future<HealthDailySample> readDay(DateTime day) async {
    await _health.configure();
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final points = await _health.getHealthDataFromTypes(
      types: _types,
      startTime: start,
      endTime: end,
    );
    var sleepMinutes = 0.0;
    var steps = 0;
    final restingRates = <double>[];
    for (final point in points) {
      switch (point.type) {
        case HealthDataType.SLEEP_ASLEEP:
          sleepMinutes += point.dateTo.difference(point.dateFrom).inMinutes;
          continue;
        case HealthDataType.STEPS:
          final value = point.value;
          if (value is NumericHealthValue) {
            steps += value.numericValue.round();
          }
          continue;
        case HealthDataType.RESTING_HEART_RATE:
          final value = point.value;
          if (value is NumericHealthValue) {
            restingRates.add(value.numericValue.toDouble());
          }
          continue;
        default:
          break;
      }
    }
    return HealthDailySample(
      day: start.toUtc(),
      sleepHours: sleepMinutes == 0 ? null : sleepMinutes / 60,
      steps: steps == 0 ? null : steps,
      restingHeartRate: restingRates.isEmpty
          ? null
          : restingRates.reduce((a, b) => a + b) / restingRates.length,
    );
  }
}

abstract interface class HealthConnectorController {
  bool get enabled;
  DateTime? get lastSyncAt;
  Future<bool> enable();
  Future<void> disable();
  Future<void> syncNow();
}

class HealthKitConnector implements HealthConnectorController {
  HealthKitConnector({
    required this.dataSource,
    required this.graphService,
    this.adapter = const HealthKitAdapter(),
    this.prefs,
    this.scheduler,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final HealthDataSource dataSource;
  final ExternalGraphService graphService;
  final HealthKitAdapter adapter;
  final DateTime Function() _clock;
  final MobilePrefsStore? prefs;
  final HealthConnectorScheduler? scheduler;
  static const enabledPreferenceKey = 'external_health_enabled_v1';
  static const _lastSyncPreferenceKey = 'external_health_last_sync_v1';

  @override
  bool enabled = false;
  @override
  DateTime? lastSyncAt;

  @override
  Future<bool> enable() async {
    enabled = await dataSource.authorize();
    if (enabled) {
      await prefs?.writeBool(enabledPreferenceKey, true);
      await scheduler?.schedule();
      await syncNow();
    }
    return enabled;
  }

  Future<void> restore() async {
    enabled = await prefs?.readBool(enabledPreferenceKey) ?? false;
    lastSyncAt = DateTime.tryParse(
      await prefs?.readString(_lastSyncPreferenceKey) ?? '',
    );
  }

  @override
  Future<void> disable() async {
    enabled = false;
    await prefs?.writeBool(enabledPreferenceKey, false);
    await scheduler?.cancel();
  }

  @override
  Future<void> syncNow() async {
    if (!enabled) return;
    final now = _clock();
    final sample = await dataSource.readDay(now);
    await graphService.upsert(adapter.adapt(sample));
    lastSyncAt = now.toUtc();
    await prefs?.writeString(
      _lastSyncPreferenceKey,
      lastSyncAt!.toIso8601String(),
    );
  }
}

abstract interface class HealthConnectorScheduler {
  Future<void> schedule();
  Future<void> cancel();
}

class WorkmanagerHealthConnectorScheduler implements HealthConnectorScheduler {
  static const taskName = 'archiveMe.external.health.sync';
  static const uniqueName = 'com.voicememory.mobile.external.health';

  @override
  Future<void> schedule() => Workmanager().registerPeriodicTask(
    uniqueName,
    taskName,
    frequency: const Duration(hours: 12),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    constraints: Constraints(requiresBatteryNotLow: true),
  );

  @override
  Future<void> cancel() => Workmanager().cancelByUniqueName(uniqueName);
}
