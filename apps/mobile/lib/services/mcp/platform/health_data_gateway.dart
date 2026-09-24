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

  static const defaultMetricTypeNames = [
    'steps',
    'heart_rate',
    'sleep_asleep',
    'active_energy',
  ];
}

/// Platform health reads — injectable for tests.
///
/// The native HealthKit / Health Connect package is not linked. This gateway
/// returns no samples so the store binary does not request health permissions.
abstract class HealthDataGateway {
  Future<List<McpHealthMetricSample>> fetchMetrics(McpHealthQuery query);
}

class HealthKitGateway implements HealthDataGateway {
  const HealthKitGateway();

  @override
  Future<List<McpHealthMetricSample>> fetchMetrics(McpHealthQuery query) async {
    return const [];
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
