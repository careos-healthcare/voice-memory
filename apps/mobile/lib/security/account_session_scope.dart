import 'dart:async';

import 'package:archiveme_mobile/storage/account_namespace.dart';

/// Active account execution scope — async work must verify [generation]
/// before mutating namespaced storage.
class AccountSessionScope {
  AccountSessionScope({
    required this.namespace,
    required this.userId,
    required this.generation,
  }) : cancelled = false;

  final AccountNamespace namespace;
  final String? userId;
  final int generation;

  bool cancelled;
  final Completer<void> _cancelCompleter = Completer<void>();

  /// Future that completes when this scope is invalidated.
  Future<void> get onCancelled => _cancelCompleter.future;

  bool get isActive => !cancelled;

  void cancel() {
    if (cancelled) return;
    cancelled = true;
    if (!_cancelCompleter.isCompleted) {
      _cancelCompleter.complete();
    }
  }

  /// Throws if [generation] no longer matches the live scope.
  void assertActive(AccountSessionScope live) {
    if (cancelled ||
        live.generation != generation ||
        live.namespace != namespace) {
      throw StaleAccountSessionException(
        expectedGeneration: generation,
        liveGeneration: live.generation,
      );
    }
  }
}

/// Thrown when async work completes after account switch/sign-out.
class StaleAccountSessionException implements Exception {
  StaleAccountSessionException({
    required this.expectedGeneration,
    required this.liveGeneration,
  });

  final int expectedGeneration;
  final int liveGeneration;

  @override
  String toString() =>
      'StaleAccountSessionException(expected=$expectedGeneration, live=$liveGeneration)';
}

/// Tracks monotonic session generations per process.
class AccountSessionRegistry {
  AccountSessionRegistry._();
  static final AccountSessionRegistry instance = AccountSessionRegistry._();

  AccountSessionScope _current = AccountSessionScope(
    namespace: AccountNamespace.guest,
    userId: null,
    generation: 0,
  );

  AccountSessionScope get current => _current;

  AccountSessionScope activate({
    required AccountNamespace namespace,
    required String? userId,
  }) {
    _current.cancel();
    _current = AccountSessionScope(
      namespace: namespace,
      userId: userId,
      generation: _current.generation + 1,
    );
    return _current;
  }
}