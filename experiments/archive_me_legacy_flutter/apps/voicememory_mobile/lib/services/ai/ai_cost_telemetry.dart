import 'dart:async';

import '../../storage/encrypted_json_file_store.dart';

enum AiExecutionRoute { local, cloud, offlineFallback, cloudSkipped }

class AiCostEvent {
  const AiCostEvent({
    required this.id,
    required this.operation,
    required this.route,
    required this.latencyMs,
    required this.estimatedCloudTokens,
    required this.estimatedTokensSaved,
    required this.occurredAt,
  });

  final String id;
  final String operation;
  final AiExecutionRoute route;
  final int latencyMs;
  final int estimatedCloudTokens;
  final int estimatedTokensSaved;
  final DateTime occurredAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'operation': operation,
    'route': route.name,
    'latencyMs': latencyMs,
    'estimatedCloudTokens': estimatedCloudTokens,
    'estimatedTokensSaved': estimatedTokensSaved,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
  };

  static AiCostEvent? fromJson(Map raw) {
    final json = Map<String, dynamic>.from(raw);
    final id = json['id'];
    final operation = json['operation'];
    final routeName = json['route'];
    final occurredAt = DateTime.tryParse(json['occurredAt']?.toString() ?? '');
    if (id is! String ||
        operation is! String ||
        routeName is! String ||
        occurredAt == null) {
      return null;
    }
    final route = AiExecutionRoute.values
        .where((candidate) => candidate.name == routeName)
        .firstOrNull;
    if (route == null) return null;
    return AiCostEvent(
      id: id,
      operation: operation,
      route: route,
      latencyMs: (json['latencyMs'] as num?)?.round() ?? 0,
      estimatedCloudTokens:
          (json['estimatedCloudTokens'] as num?)?.round() ?? 0,
      estimatedTokensSaved:
          (json['estimatedTokensSaved'] as num?)?.round() ?? 0,
      occurredAt: occurredAt,
    );
  }
}

class AiCostTelemetrySnapshot {
  const AiCostTelemetrySnapshot({
    required this.localRequests,
    required this.cloudRequests,
    required this.skippedCloudRequests,
    required this.estimatedCloudTokens,
    required this.estimatedTokensSaved,
    required this.averageLocalLatencyMs,
    required this.averageCloudLatencyMs,
  });

  final int localRequests;
  final int cloudRequests;
  final int skippedCloudRequests;
  final int estimatedCloudTokens;
  final int estimatedTokensSaved;
  final double averageLocalLatencyMs;
  final double averageCloudLatencyMs;

  int get routedRequests => localRequests + cloudRequests;
  double get localRequestRatio =>
      routedRequests == 0 ? 0 : localRequests / routedRequests;
  double get cloudRequestRatio =>
      routedRequests == 0 ? 0 : cloudRequests / routedRequests;
}

/// Privacy-safe local ledger for routing efficiency and estimated savings.
///
/// It records no prompts, transcripts, node labels, user IDs, or API payloads.
class AiCostTelemetry {
  AiCostTelemetry({
    EncryptedJsonFileStore? storage,
    DateTime Function()? clock,
    this.maxEvents = 500,
  }) : // Public named parameters cannot initialize private fields directly.
       // ignore: prefer_initializing_formals
       _storage = storage,
       _clock = clock ?? DateTime.now;

  final EncryptedJsonFileStore? _storage;
  final DateTime Function() _clock;
  final int maxEvents;
  final List<AiCostEvent> _events = [];
  Future<void> _writeTail = Future<void>.value();
  bool _loaded = false;
  int _sequence = 0;

  Future<void> record({
    required String operation,
    required AiExecutionRoute route,
    required Duration latency,
    int estimatedCloudTokens = 0,
    int estimatedTokensSaved = 0,
  }) => _serialized(() async {
    await _load();
    final now = _clock().toUtc();
    _events.add(
      AiCostEvent(
        id: '${now.microsecondsSinceEpoch}-${_sequence++}',
        operation: operation,
        route: route,
        latencyMs: latency.inMilliseconds.clamp(0, 1 << 31),
        estimatedCloudTokens: estimatedCloudTokens.clamp(0, 1 << 31),
        estimatedTokensSaved: estimatedTokensSaved.clamp(0, 1 << 31),
        occurredAt: now,
      ),
    );
    if (_events.length > maxEvents) {
      _events.removeRange(0, _events.length - maxEvents);
    }
    await _persist();
  });

  Future<AiCostTelemetrySnapshot> snapshot() async {
    await _writeTail.catchError((Object _) {});
    await _load();
    final local = _events
        .where(
          (event) =>
              event.route == AiExecutionRoute.local ||
              event.route == AiExecutionRoute.offlineFallback,
        )
        .toList();
    final cloud = _events
        .where((event) => event.route == AiExecutionRoute.cloud)
        .toList();
    return AiCostTelemetrySnapshot(
      localRequests: local.length,
      cloudRequests: cloud.length,
      skippedCloudRequests: _events
          .where((event) => event.route == AiExecutionRoute.cloudSkipped)
          .length,
      estimatedCloudTokens: cloud.fold(
        0,
        (sum, event) => sum + event.estimatedCloudTokens,
      ),
      estimatedTokensSaved: _events.fold(
        0,
        (sum, event) => sum + event.estimatedTokensSaved,
      ),
      averageLocalLatencyMs: _averageLatency(local),
      averageCloudLatencyMs: _averageLatency(cloud),
    );
  }

  Future<void> clear() => _serialized(() async {
    _events.clear();
    _loaded = true;
    final storage = _storage;
    if (storage != null && await storage.file.exists()) {
      await storage.file.delete();
    }
  });

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _writeTail = _writeTail.catchError((Object _) {}).then((_) async {
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    final storage = _storage;
    if (storage == null) return;
    try {
      final raw = await storage.readJson();
      if (raw is! Map || raw['events'] is! List) return;
      _events.addAll(
        (raw['events'] as List)
            .whereType<Map>()
            .map(AiCostEvent.fromJson)
            .whereType<AiCostEvent>(),
      );
    } on Object {
      _events.clear();
    }
  }

  Future<void> _persist() async {
    final storage = _storage;
    if (storage == null) return;
    await storage.writeJson({
      'schemaVersion': 1,
      'events': _events.map((event) => event.toJson()).toList(growable: false),
    });
  }

  static double _averageLatency(List<AiCostEvent> events) {
    if (events.isEmpty) return 0;
    return events.fold<int>(0, (sum, event) => sum + event.latencyMs) /
        events.length;
  }
}
