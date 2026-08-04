// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../storage/encrypted_json_file_store.dart';
import 'action_plan_models.dart';

/// Serialized encrypted persistence for action plans and their check-in logs.
final class ActionPlanStore extends ChangeNotifier {
  ActionPlanStore({required EncryptedJsonFileStore storage})
    : _storage = storage;

  final EncryptedJsonFileStore _storage;
  final ValueNotifier<int> _revisionListenable = ValueNotifier(0);
  final StreamController<int> _revisionController =
      StreamController<int>.broadcast();
  Future<void> _tail = Future<void>.value();
  bool _disposed = false;

  int get revision => _revisionListenable.value;
  ValueListenable<int> get revisionListenable => _revisionListenable;
  Stream<int> get revisions => _revisionController.stream;
  Stream<int> get revisionStream => revisions;

  Future<List<ActionPlan>> list() => _serialized(_read);

  Future<ActionPlan?> get(String id) => _serialized(() async {
    final normalized = id.trim();
    if (normalized.isEmpty) return null;
    for (final plan in await _read()) {
      if (plan.id == normalized) return plan;
    }
    return null;
  });

  Future<void> upsert(ActionPlan plan) => _mutate((plans) {
    plans[plan.id] = plan;
  });

  Future<void> remove(String id) => _mutate((plans) {
    plans.remove(id);
  });

  Future<void> replace(Iterable<ActionPlan> plans) => _serialized(() async {
    await _write({for (final plan in plans) plan.id: plan}.values);
    _changed();
  });

  /// Performs an atomic read/modify/write inside this store's serialization
  /// queue and returns a value derived from the committed state.
  Future<T> update<T>(T Function(Map<String, ActionPlan> plans) operation) =>
      _serialized(() async {
        final plans = {for (final plan in await _read()) plan.id: plan};
        final result = operation(plans);
        await _write(plans.values);
        _changed();
        return result;
      });

  Future<void> clear() => _serialized(() async {
    await _storage.writeJson(const {'schemaVersion': 1, 'plans': <Object>[]});
    _changed();
  });

  Future<void> _mutate(
    void Function(Map<String, ActionPlan> plans) operation,
  ) => update<void>(operation);

  Future<List<ActionPlan>> _read() async {
    try {
      final document = await _storage.readJson();
      final rows = document is List
          ? document
          : document is Map
          ? document['plans']
          : null;
      if (rows is! List) return const [];
      final plans = <String, ActionPlan>{};
      for (final row in rows.whereType<Map>()) {
        try {
          final plan = ActionPlan.fromJson(Map<String, dynamic>.from(row));
          plans[plan.id] = plan;
        } on FormatException {
          // Retain valid encrypted rows if one row is corrupt or from the future.
        } on ArgumentError {
          // Constructor invariants fail closed per row.
        }
      }
      final result = plans.values.toList()
        ..sort((left, right) {
          final date = right.createdAt.compareTo(left.createdAt);
          return date != 0 ? date : left.id.compareTo(right.id);
        });
      return List.unmodifiable(result);
    } on Object {
      return const [];
    }
  }

  Future<void> _write(Iterable<ActionPlan> plans) {
    final ordered = plans.toList()
      ..sort((left, right) {
        final date = right.createdAt.compareTo(left.createdAt);
        return date != 0 ? date : left.id.compareTo(right.id);
      });
    return _storage.writeJson({
      'schemaVersion': 1,
      'plans': ordered.map((plan) => plan.toPortableJson()).toList(),
    });
  }

  void _changed() {
    _revisionListenable.value++;
    _revisionController.add(revision);
    notifyListeners();
  }

  Future<T> _serialized<T>(FutureOr<T> Function() operation) {
    if (_disposed) {
      return Future.error(StateError('Action plan store is disposed.'));
    }
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

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _revisionListenable.dispose();
    unawaited(_revisionController.close());
    super.dispose();
  }
}
