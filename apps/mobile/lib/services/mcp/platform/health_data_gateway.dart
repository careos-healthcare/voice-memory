import 'package:health/health.dart';

/// Normalized local health metric sample.
class McpHealthMetricSample {
  const McpHealthMetricSample({
    required this.type,
    required this.value,
    required this.unit,
    required this.recordedAt,
    this.sourceName,
  });

  final String type;
  final double value;
  final String unit;
  final DateTime recordedAt;
  final String? sourceName;

  Map<String, dynamic> toJson() => {
    'type': type,
    'value': value,
    'unit': unit,
    'recordedAt': recordedAt.toUtc().toIso8601String(),
    if (sourceName != null) 'sourceName': sourceName,
  };
}

/// Query window for local health reads.
class McpHealthQuery {
  const McpHealthQuery({
    required this.start,
    required this.end,
    this.metricTypes,
  });

  factory McpHealthQuery.fromJson(Map<String, dynamic> json) {
    final startRaw = json['start'];
    final endRaw = json['end'];
    final metricTypesRaw = json['metricTypes'];

    return McpHealthQuery(
      start: startRaw is String
          ? DateTime.parse(startRaw).toUtc()
          : DateTime.now().toUtc().subtract(const Duration(days: 7)),
      end: endRaw is String
          ? DateTime.parse(endRaw).toUtc()
          : DateTime.now().toUtc(),
      metricTypes: metricTypesRaw is List
          ? metricTypesRaw.whereType<String>().toList()
          : null,
    );
  }

  final DateTime start;
  final DateTime end;
  final List<String>? metricTypes;

  List<HealthDataType> resolveDataTypes() {
    final requested = metricTypes ?? defaultMetricTypeNames;
    final resolved = <HealthDataType>[];
    for (final name in requested) {
      final type = _healthDataTypeFromName(name);
      if (type != null) resolved.add(type);
    }
    return resolved.isEmpty ? defaultHealthDataTypes : resolved;
  }

  static const defaultMetricTypeNames = [
    'steps',
    'heart_rate',
    'sleep_asleep',
    'active_energy',
  ];

  static const defaultHealthDataTypes = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];
}

HealthDataType? _healthDataTypeFromName(String raw) => switch (raw) {
  'steps' => HealthDataType.STEPS,
  'heart_rate' => HealthDataType.HEART_RATE,
  'sleep_asleep' => HealthDataType.SLEEP_ASLEEP,
  'active_energy' => HealthDataType.ACTIVE_ENERGY_BURNED,
  'resting_heart_rate' => HealthDataType.RESTING_HEART_RATE,
  'distance_walking_running' => HealthDataType.DISTANCE_WALKING_RUNNING,
  _ => null,
};

String _healthDataTypeName(HealthDataType type) => switch (type) {
  HealthDataType.STEPS => 'steps',
  HealthDataType.HEART_RATE => 'heart_rate',
  HealthDataType.SLEEP_ASLEEP => 'sleep_asleep',
  HealthDataType.ACTIVE_ENERGY_BURNED => 'active_energy',
  HealthDataType.RESTING_HEART_RATE => 'resting_heart_rate',
  HealthDataType.DISTANCE_WALKING_RUNNING => 'distance_walking_running',
  _ => type.name,
};

/// Platform health reads — injectable for tests.
abstract class HealthDataGateway {
  Future<List<McpHealthMetricSample>> fetchMetrics(McpHealthQuery query);
}

class HealthKitGateway implements HealthDataGateway {
  HealthKitGateway({Health? health}) : _health = health ?? Health();

  final Health _health;

  @override
  Future<List<McpHealthMetricSample>> fetchMetrics(McpHealthQuery query) async {
    await _health.configure();
    final types = query.resolveDataTypes();
    final authorized = await _health.requestAuthorization(types);
    if (!authorized) return const [];

    final points = await _health.getHealthDataFromTypes(
      types: types,
      startTime: query.start,
      endTime: query.end,
    );

    final samples = <McpHealthMetricSample>[];
    for (final point in points) {
      final numeric = _numericValue(point.value);
      if (numeric == null) continue;

      samples.add(
        McpHealthMetricSample(
          type: _healthDataTypeName(point.type),
          value: numeric,
          unit: point.unit.name,
          recordedAt: point.dateFrom.toUtc(),
          sourceName: point.sourceName,
        ),
      );
    }

    samples.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return samples;
  }

  double? _numericValue(HealthValue value) {
    if (value is NumericHealthValue) {
      return value.numericValue.toDouble();
    }
    return null;
  }
}

class FakeHealthDataGateway implements HealthDataGateway {
  FakeHealthDataGateway({this.samples = const []});

  List<McpHealthMetricSample> samples;
  int fetchCallCount = 0;
  McpHealthQuery? lastQuery;

  @override
  Future<List<McpHealthMetricSample>> fetchMetrics(McpHealthQuery query) async {
    fetchCallCount++;
    lastQuery = query;
    return List<McpHealthMetricSample>.of(samples);
  }
}
