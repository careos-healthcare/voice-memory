import 'dart:async';

import 'package:flutter/foundation.dart';

/// Cold-start work the Record surface does not need in order to accept a tap.
///
/// Every step here still runs — it runs after the first frame, or earlier if
/// something asks for it first. Nothing is dropped.
enum DeferredStartupStep {
  /// `ProductAnalytics.initialize()`. Events recorded before this are queued by
  /// the facade and flushed on activation.
  analyticsProvider,

  /// Billing SDK start-up, cached-entitlement hydration, store subscription.
  monetization,

  /// The journal sync service and its offline journey store.
  sync,

  /// Semantic archive index and explainability history on-disk state.
  archiveDerivedStores,
}

typedef DeferredStartupAction = Future<void> Function();

/// Runs each registered deferred step at most once, and never lets a failure
/// in one of them reach the capture surface.
final class DeferredStartupCoordinator {
  final Map<DeferredStartupStep, DeferredStartupAction> _actions =
      <DeferredStartupStep, DeferredStartupAction>{};
  final Map<DeferredStartupStep, Future<void>> _inFlight =
      <DeferredStartupStep, Future<void>>{};
  final Set<DeferredStartupStep> _completed = <DeferredStartupStep>{};
  final Map<DeferredStartupStep, Object> _failures =
      <DeferredStartupStep, Object>{};

  void register(DeferredStartupStep step, DeferredStartupAction action) {
    _actions[step] = action;
  }

  bool isComplete(DeferredStartupStep step) => _completed.contains(step);

  Set<DeferredStartupStep> get registeredSteps =>
      Set<DeferredStartupStep>.unmodifiable(_actions.keys);

  Set<DeferredStartupStep> get completedSteps =>
      Set<DeferredStartupStep>.unmodifiable(_completed);

  Set<DeferredStartupStep> get pendingSteps =>
      Set<DeferredStartupStep>.unmodifiable(
        _actions.keys.where((step) => !_completed.contains(step)),
      );

  /// Steps whose activation threw. A recorded failure can be retried.
  Map<DeferredStartupStep, Object> get failures =>
      Map<DeferredStartupStep, Object>.unmodifiable(_failures);

  Future<void> run(DeferredStartupStep step) async {
    if (_completed.contains(step)) return;
    final inFlight = _inFlight[step];
    if (inFlight != null) return inFlight;
    final action = _actions[step];
    if (action == null) return;
    final future = action();
    _inFlight[step] = future;
    try {
      await future;
      _completed.add(step);
      _failures.remove(step);
    } on Object catch (error, stackTrace) {
      // A deferred service must never be able to take capture down with it.
      _failures[step] = error;
      if (kDebugMode) {
        debugPrint('ARCHIVEME_DEFERRED_STARTUP failed step=${step.name}');
        debugPrintStack(stackTrace: stackTrace);
      }
    } finally {
      _inFlight.remove(step);
    }
  }

  /// Runs every registered step. Safe to call repeatedly.
  Future<void> runAll() async {
    for (final step in DeferredStartupStep.values) {
      await run(step);
    }
  }
}
