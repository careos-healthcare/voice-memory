import 'dart:async';

/// Serializes async work per key so check-then-act sections cannot race.
class KeyedAsyncLock {
  final _chains = <String, Future<void>>{};

  Future<T> runLocked<T>(String key, Future<T> Function() action) async {
    final previous = _chains[key] ?? Future<void>.value();
    final gate = Completer<void>();
    _chains[key] = gate.future;
    await previous;
    try {
      return await action();
    } finally {
      gate.complete();
      if (identical(_chains[key], gate.future)) {
        _chains.remove(key);
      }
    }
  }
}
