import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';

import 'package:archiveme_mobile/core/execution/cancel_token.dart';
import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:flutter/foundation.dart';

/// A completed isolated job, captured for local debugging and tests.
final class IsolateJobTraceEvent {
  const IsolateJobTraceEvent({
    required this.label,
    required this.duration,
  });

  final String label;
  final Duration duration;
}

/// Debug-only duration log for isolated vector / embedding / LLM jobs.
abstract final class IsolateJobTrace {
  IsolateJobTrace._();

  static final List<IsolateJobTraceEvent> events = <IsolateJobTraceEvent>[];

  /// When true, [events] records every [record] call. Tests should enable this.
  static bool captureEvents = false;

  static void record(String label, Duration elapsed) {
    if (kDebugMode) {
      AppLogger.debug(
        'isolate_job label=$label durationMs=${elapsed.inMilliseconds}',
        name: 'IsolateComputeJob',
      );
    }
    if (captureEvents) {
      events.add(IsolateJobTraceEvent(label: label, duration: elapsed));
    }
  }

  @visibleForTesting
  static void reset() {
    events.clear();
    captureEvents = false;
  }
}

/// Caps concurrent heavy jobs so mobile RAM / thermal state are not flooded.
final class IsolateJobThrottle {
  IsolateJobThrottle({this.maxConcurrent = defaultMaxConcurrent});

  static const defaultMaxConcurrent = 2;

  /// Shared cap for CPU ranking / blob scans.
  static final IsolateJobThrottle shared = IsolateJobThrottle();

  /// One embedding generation at a time (ONNX session + projection weights).
  static final IsolateJobThrottle embedding = IsolateJobThrottle(
    maxConcurrent: 1,
  );

  /// One local GGUF completion at a time.
  static final IsolateJobThrottle llm = IsolateJobThrottle(maxConcurrent: 1);

  final int maxConcurrent;
  var _active = 0;
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();

  int get activeCount => _active;

  int get pendingCount => _waiters.length;

  Future<T> run<T>(
    Future<T> Function() job, {
    ExecutionCancelToken? cancelToken,
  }) async {
    cancelToken?.throwIfCancelled();
    while (_active >= maxConcurrent) {
      cancelToken?.throwIfCancelled();
      final waiter = Completer<void>();
      _waiters.add(waiter);
      await waiter.future;
      cancelToken?.throwIfCancelled();
    }
    _active++;
    try {
      return await job();
    } finally {
      _active--;
      if (_waiters.isNotEmpty) {
        _waiters.removeFirst().complete();
      }
    }
  }

  @visibleForTesting
  void reset() {
    _active = 0;
    for (final waiter in _waiters) {
      if (!waiter.isCompleted) {
        waiter.completeError(StateError('IsolateJobThrottle.reset'));
      }
    }
    _waiters.clear();
  }
}

/// Runs sendable CPU work with [Isolate.run] (or inline for tiny payloads).
///
/// [computeFn] must be a top-level or static function so the isolate can
/// serialize it. Native handles (sqflite [Database], ONNX sessions, llama.cpp
/// parents) stay on the isolate that created them — only Dart-side ranking
/// and projection belong here.
abstract final class IsolateComputeJob {
  IsolateComputeJob._();

  /// Host-VM tests can force the compute body to run on the current isolate.
  @visibleForTesting
  static bool debugForceInline = false;

  static bool get _isFlutterTest =>
      Platform.environment.containsKey('FLUTTER_TEST');

  /// Times [action] and logs duration during local debugging.
  static Future<T> trace<T>(
    String label,
    Future<T> Function() action,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      return await action();
    } finally {
      stopwatch.stop();
      IsolateJobTrace.record(label, stopwatch.elapsed);
    }
  }

  /// Runs [computeFn] off the UI isolate, gated by [throttle] and [cancelToken].
  static Future<R> run<P, R>({
    required String label,
    required P payload,
    required R Function(P payload) computeFn,
    ExecutionCancelToken? cancelToken,
    IsolateJobThrottle? throttle,
    bool forceInline = false,
  }) {
    final gate = throttle ?? IsolateJobThrottle.shared;
    return gate.run(
      () {
        return trace(label, () async {
          cancelToken?.throwIfCancelled();
          if (forceInline || debugForceInline) {
            return computeFn(payload);
          }
          return Isolate.run(() => computeFn(payload));
        });
      },
      cancelToken: cancelToken,
    );
  }

  /// Flutter [compute] entry for the same sendable jobs.
  static Future<R> computeOnBackground<P, R>({
    required String label,
    required P payload,
    required ComputeCallback<P, R> computeFn,
    ExecutionCancelToken? cancelToken,
    IsolateJobThrottle? throttle,
    bool forceInline = false,
  }) {
    final gate = throttle ?? IsolateJobThrottle.shared;
    return gate.run(
      () {
        return trace(label, () async {
          cancelToken?.throwIfCancelled();
          if (forceInline || debugForceInline) {
            return computeFn(payload);
          }
          if (_isFlutterTest) {
            return Isolate.run(() => computeFn(payload));
          }
          return compute(computeFn, payload);
        });
      },
      cancelToken: cancelToken,
    );
  }
}
