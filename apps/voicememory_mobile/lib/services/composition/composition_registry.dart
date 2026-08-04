import 'dart:async';

typedef V1ModuleBuilder<T extends Object> = FutureOr<T> Function();

/// Small construction-time registry used to reject duplicate ownership and
/// dependency cycles. It is discarded once the typed composition is built.
final class V1CompositionRegistry {
  final Map<String, Object> _modules = <String, Object>{};
  final List<String> _building = <String>[];

  Future<T> build<T extends Object>(
    String name,
    V1ModuleBuilder<T> builder,
  ) async {
    final existing = _modules[name];
    if (existing != null) {
      throw StateError('V1 module "$name" is already registered.');
    }
    final cycleStart = _building.indexOf(name);
    if (cycleStart != -1) {
      final cycle = [..._building.sublist(cycleStart), name].join(' -> ');
      throw StateError('V1 composition cycle: $cycle');
    }

    _building.add(name);
    try {
      final module = await builder();
      if (_modules.containsKey(name)) {
        throw StateError('V1 module "$name" was registered twice.');
      }
      _modules[name] = module;
      return module;
    } finally {
      _building.removeLast();
    }
  }

  T require<T extends Object>(String name) {
    if (_building.contains(name)) {
      final cycle = [..._building, name].join(' -> ');
      throw StateError('V1 composition cycle: $cycle');
    }
    final module = _modules[name];
    if (module == null) {
      throw StateError('V1 module "$name" has not been registered.');
    }
    if (module is! T) {
      throw StateError(
        'V1 module "$name" is ${module.runtimeType}, expected $T.',
      );
    }
    return module;
  }

  Set<String> get registeredNames => Set.unmodifiable(_modules.keys);
}
