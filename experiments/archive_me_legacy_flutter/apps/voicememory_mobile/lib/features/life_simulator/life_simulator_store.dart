// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import '../../storage/encrypted_json_file_store.dart';
import 'life_simulator_models.dart';

/// Encrypted local persistence for counterfactual simulations.
///
/// Reads and writes share one queue so an upsert can never race a prior write
/// or overwrite a concurrently appended scenario.
final class LifeSimulatorStore {
  LifeSimulatorStore({required EncryptedJsonFileStore storage})
    : _storage = storage;

  final EncryptedJsonFileStore _storage;
  Future<void> _tail = Future<void>.value();

  Future<List<CounterfactualScenario>> list() => _serialized(_read);

  Future<CounterfactualScenario?> get(String id) => _serialized(() async {
    final normalized = id.trim();
    if (normalized.isEmpty) return null;
    for (final scenario in await _read()) {
      if (scenario.id == normalized) return scenario;
    }
    return null;
  });

  Future<void> upsert(CounterfactualScenario scenario) => _serialized(() async {
    final scenarios = {
      for (final item in await _read()) item.id: item,
      scenario.id: scenario,
    };
    await _write(scenarios.values);
  });

  Future<void> replace(Iterable<CounterfactualScenario> scenarios) =>
      _serialized(() async {
        await _write(
          {for (final scenario in scenarios) scenario.id: scenario}.values,
        );
      });

  Future<void> remove(String id) => _serialized(() async {
    final scenarios = {for (final item in await _read()) item.id: item};
    scenarios.remove(id);
    await _write(scenarios.values);
  });

  Future<void> clear() => _serialized(
    () =>
        _storage.writeJson(const {'schemaVersion': 1, 'scenarios': <Object>[]}),
  );

  Future<List<CounterfactualScenario>> _read() async {
    try {
      final document = await _storage.readJson();
      final rows = document is List
          ? document
          : document is Map
          ? document['scenarios']
          : null;
      if (rows is! List) return const [];
      final scenarios = <String, CounterfactualScenario>{};
      for (final row in rows) {
        if (row is! Map) continue;
        try {
          final scenario = CounterfactualScenario.fromJson(
            Map<String, dynamic>.from(row),
          );
          scenarios[scenario.id] = scenario;
        } on FormatException {
          // Keep valid encrypted rows when a legacy/corrupt row fails closed.
        } on ArgumentError {
          // Constructor invariants also fail closed per row.
        }
      }
      final result = scenarios.values.toList()
        ..sort((a, b) => a.id.compareTo(b.id));
      return List.unmodifiable(result);
    } on Object {
      return const [];
    }
  }

  Future<void> _write(Iterable<CounterfactualScenario> scenarios) {
    final ordered = scenarios.toList()..sort((a, b) => a.id.compareTo(b.id));
    return _storage.writeJson({
      'schemaVersion': 1,
      'scenarios': ordered.map((item) => item.toJson()).toList(),
    });
  }

  Future<T> _serialized<T>(FutureOr<T> Function() operation) {
    final completer = Completer<T>();
    _tail = _tail.catchError((Object _) {}).then((_) async {
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}
