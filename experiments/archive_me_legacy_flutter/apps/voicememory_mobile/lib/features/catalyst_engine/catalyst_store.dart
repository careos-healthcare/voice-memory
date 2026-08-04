import 'dart:async';

import '../../storage/encrypted_json_file_store.dart';
import 'catalyst_models.dart';

final class CatalystState {
  const CatalystState({
    this.recipes = const [],
    this.runs = const [],
    this.pendingEvents = const [],
    this.approvals = const [],
    this.processedEventIds = const {},
    this.bridgeNodeIds = const {},
    this.lastFirstUnlockDay,
  });

  final List<CatalystRecipe> recipes;
  final List<CatalystRunLog> runs;
  final List<CatalystEvent> pendingEvents;
  final List<CatalystApproval> approvals;
  final Set<String> processedEventIds;
  final Set<String> bridgeNodeIds;
  final String? lastFirstUnlockDay;

  CatalystState copyWith({
    List<CatalystRecipe>? recipes,
    List<CatalystRunLog>? runs,
    List<CatalystEvent>? pendingEvents,
    List<CatalystApproval>? approvals,
    Set<String>? processedEventIds,
    Set<String>? bridgeNodeIds,
    String? lastFirstUnlockDay,
  }) => CatalystState(
    recipes: recipes ?? this.recipes,
    runs: runs ?? this.runs,
    pendingEvents: pendingEvents ?? this.pendingEvents,
    approvals: approvals ?? this.approvals,
    processedEventIds: processedEventIds ?? this.processedEventIds,
    bridgeNodeIds: bridgeNodeIds ?? this.bridgeNodeIds,
    lastFirstUnlockDay: lastFirstUnlockDay ?? this.lastFirstUnlockDay,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'recipes': recipes.map((item) => item.toJson()).toList(),
    'runs': runs.map((item) => item.toJson()).toList(),
    'pendingEvents': pendingEvents.map((item) => item.toJson()).toList(),
    'approvals': approvals.map((item) => item.toJson()).toList(),
    'processedEventIds': processedEventIds.toList(),
    'bridgeNodeIds': bridgeNodeIds.toList(),
    'lastFirstUnlockDay': lastFirstUnlockDay,
  };

  factory CatalystState.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported Catalyst store schema.');
    }
    return CatalystState(
      recipes: _maps(json['recipes']).map(CatalystRecipe.fromJson).toList(),
      runs: _maps(json['runs']).map(CatalystRunLog.fromJson).toList(),
      pendingEvents: _maps(
        json['pendingEvents'],
      ).map(CatalystEvent.fromJson).toList(),
      approvals: _maps(
        json['approvals'],
      ).map(CatalystApproval.fromJson).toList(),
      processedEventIds: (json['processedEventIds'] as List? ?? const [])
          .whereType<String>()
          .toSet(),
      bridgeNodeIds: (json['bridgeNodeIds'] as List? ?? const [])
          .whereType<String>()
          .toSet(),
      lastFirstUnlockDay: json['lastFirstUnlockDay'] as String?,
    );
  }
}

Iterable<Map<String, Object?>> _maps(Object? value) =>
    (value as List? ?? const []).whereType<Map>().map(
      (item) => Map<String, Object?>.from(item),
    );

final class CatalystStore {
  CatalystStore(this.storage);

  static const maximumRuns = 200;
  static const maximumProcessedEvents = 500;
  static const maximumPendingEvents = 100;

  final EncryptedJsonFileStore storage;
  Future<void> _tail = Future.value();
  final StreamController<CatalystState> _changes = StreamController.broadcast();

  Stream<CatalystState> get changes => _changes.stream;

  Future<CatalystState> read() => _serialized(_read);

  Future<CatalystState> _read() async {
    try {
      final value = await storage.readJson();
      if (value is! Map) return const CatalystState();
      return CatalystState.fromJson(Map<String, Object?>.from(value));
    } on FormatException {
      return const CatalystState();
    }
  }

  Future<CatalystState> update(
    CatalystState Function(CatalystState current) operation,
  ) => _serialized(() async {
    final next = operation(await _read());
    await storage.writeJson(next.toJson());
    _changes.add(next);
    return next;
  });

  Future<void> saveRecipe(CatalystRecipe recipe) async {
    await update((state) {
      final recipes = [...state.recipes];
      final index = recipes.indexWhere((item) => item.id == recipe.id);
      if (index < 0) {
        recipes.add(recipe);
      } else {
        recipes[index] = recipe;
      }
      return state.copyWith(recipes: recipes);
    });
  }

  Future<void> appendRun(CatalystRunLog run) async {
    await update(
      (state) => state.copyWith(
        runs: [
          ...state.runs,
          run,
        ].takeLast(maximumRuns).toList(growable: false),
      ),
    );
  }

  Future<void> queueEvent(CatalystEvent event) async {
    await update(
      (state) => state.copyWith(
        pendingEvents: [
          ...state.pendingEvents,
          event,
        ].takeLast(maximumPendingEvents).toList(growable: false),
      ),
    );
  }

  Future<void> clear() => _serialized(() => storage.writeJson(const {}));

  Future<T> _serialized<T>(FutureOr<T> Function() operation) {
    final completer = Completer<T>();
    _tail = _tail.catchError((_) {}).then((_) async {
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<void> dispose() async {
    await _tail.catchError((_) {});
    await _changes.close();
  }
}

extension<T> on Iterable<T> {
  Iterable<T> takeLast(int count) {
    final values = toList();
    return values.skip((values.length - count).clamp(0, values.length));
  }
}
