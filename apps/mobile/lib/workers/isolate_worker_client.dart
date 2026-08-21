import 'dart:async';
import 'dart:isolate';

import 'package:flutter/services.dart';

/// Shared startup envelope for persistent worker isolates.
final class IsolateWorkerStartup {
  const IsolateWorkerStartup({
    required this.handshakePort,
    required this.clientResponsePort,
    required this.initializeTestFfi,
    this.rootIsolateToken,
    this.defaultKeyAlias,
  });

  final SendPort handshakePort;
  final SendPort clientResponsePort;
  final bool initializeTestFfi;
  final RootIsolateToken? rootIsolateToken;
  final String? defaultKeyAlias;
}

/// Minimal request/response IPC used by background worker services.
final class IsolateWorkerRequest {
  const IsolateWorkerRequest({
    required this.requestId,
    required this.operation,
    required this.payload,
    this.priority = IsolateWorkerPriority.normal,
  });

  final int requestId;
  final String operation;
  final Map<String, dynamic> payload;
  final int priority;

  Map<String, dynamic> toJson() => {
        'requestId': requestId,
        'operation': operation,
        'payload': payload,
        'priority': priority,
      };

  factory IsolateWorkerRequest.fromJson(Map<String, dynamic> json) {
    return IsolateWorkerRequest(
      requestId: json['requestId'] as int? ?? 0,
      operation: json['operation'] as String? ?? '',
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? const {}),
      priority: json['priority'] as int? ?? IsolateWorkerPriority.normal,
    );
  }
}

/// IPC dispatch priority for worker isolates.
abstract final class IsolateWorkerPriority {
  IsolateWorkerPriority._();

  static const normal = 0;
  static const high = 1;
}

/// Control-plane operations that preempt long-running worker tasks.
abstract final class IsolateWorkerControlOperations {
  IsolateWorkerControlOperations._();

  /// Requests cooperative cancellation of an in-flight generation/inference task.
  static const cancelGenerationRequest = 'cancelGenerationRequest';
}

/// Control-plane signals emitted by workers back to the UI isolate.
abstract final class IsolateWorkerControlSignals {
  IsolateWorkerControlSignals._();

  /// Worker has returned to the Dart event loop after cancelling native work.
  static const cancelAcknowledged = 'cancelAcknowledged';
}

final class IsolateWorkerResponse {
  const IsolateWorkerResponse({
    required this.requestId,
    this.result,
    this.error,
    this.done = true,
    this.controlSignal,
  });

  final int requestId;
  final Object? result;
  final String? error;

  /// When false, more responses for [requestId] may follow (streaming).
  final bool done;

  /// Out-of-band worker control signal (e.g. [IsolateWorkerControlSignals.cancelAcknowledged]).
  final String? controlSignal;

  Map<String, dynamic> toJson() => {
        'requestId': requestId,
        'done': done,
        if (result != null) 'result': result,
        if (error != null) 'error': error,
        if (controlSignal != null) 'controlSignal': controlSignal,
      };

  factory IsolateWorkerResponse.fromJson(Map<String, dynamic> json) {
    return IsolateWorkerResponse(
      requestId: json['requestId'] as int? ?? 0,
      result: json['result'],
      error: json['error'] as String?,
      done: json['done'] as bool? ?? true,
      controlSignal: json['controlSignal'] as String?,
    );
  }
}

/// Error raised when a worker isolate reports a failed operation.
final class IsolateWorkerException implements Exception {
  IsolateWorkerException(this.message);

  final String message;

  @override
  String toString() => 'IsolateWorkerException: $message';
}

/// Base client for a long-lived worker isolate with request/response routing.
abstract class PersistentIsolateWorkerClient {
  SendPort? workerPort;
  ReceivePort? responsePort;
  StreamSubscription<dynamic>? responseSubscription;
  Isolate? isolate;
  Future<void>? starting;
  int nextRequestId = 1;
  final pending = <int, Completer<Object?>>{};
  final streamPending = <int, StreamController<Object?>>{};

  Future<void> ensureStarted();

  Future<void> spawnWorker({
    required void Function(IsolateWorkerStartup startup) entryPoint,
    required IsolateWorkerStartup startup,
  });

  Future<void> disposeWorker({required String shutdownOperation});

  Future<T> dispatch<T>({
    required String operation,
    required Map<String, dynamic> payload,
    Duration timeout = const Duration(minutes: 2),
  });

  Stream<Object?> dispatchStream({
    required String operation,
    required Map<String, dynamic> payload,
  });

  void handleWorkerResponse(Object? message);

  Future<void> closeClientState();
}

extension PersistentIsolateWorkerClientOps on PersistentIsolateWorkerClient {
  Future<void> spawnWorkerImpl({
    required void Function(IsolateWorkerStartup startup) entryPoint,
    required IsolateWorkerStartup startup,
  }) async {
    final handshakePort = ReceivePort();
    final clientResponsePort = ReceivePort();

    responsePort = clientResponsePort;
    responseSubscription = clientResponsePort.listen(handleWorkerResponse);

    isolate = await Isolate.spawn(entryPoint, startup);

    final port = await handshakePort.first;
    handshakePort.close();
    if (port is! SendPort) {
      throw StateError('Worker isolate failed handshake.');
    }
    workerPort = port;
  }

  Future<T> dispatchImpl<T>({
    required String operation,
    required Map<String, dynamic> payload,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    await ensureStarted();
    final port = workerPort;
    if (port == null) {
      throw StateError('Worker isolate is not running.');
    }

    final requestId = nextRequestId++;
    final completer = Completer<Object?>();
    pending[requestId] = completer;

    port.send(
      IsolateWorkerRequest(
        requestId: requestId,
        operation: operation,
        payload: payload,
      ).toJson(),
    );

    final result = await completer.future.timeout(
      timeout,
      onTimeout: () {
        pending.remove(requestId);
        throw TimeoutException('Worker timed out for $operation.');
      },
    );
    return result as T;
  }

  Stream<Object?> dispatchStreamImpl({
    required String operation,
    required Map<String, dynamic> payload,
  }) {
    late final StreamController<Object?> controller;
    controller = StreamController<Object?>(
      onCancel: () {
        streamPending.removeWhere((_, value) => identical(value, controller));
      },
    );

    ensureStarted().then((_) {
      final port = workerPort;
      if (port == null) {
        controller.addError(StateError('Worker isolate is not running.'));
        unawaited(controller.close());
        return;
      }

      final requestId = nextRequestId++;
      streamPending[requestId] = controller;

      port.send(
        IsolateWorkerRequest(
          requestId: requestId,
          operation: operation,
          payload: payload,
        ).toJson(),
      );
    }).catchError((Object error, StackTrace stackTrace) {
      if (!controller.isClosed) {
        controller.addError(error, stackTrace);
        unawaited(controller.close());
      }
    });

    return controller.stream;
  }

  void handleWorkerResponseImpl(Object? message) {
    if (message is! Map) {
      return;
    }

    final response = IsolateWorkerResponse.fromJson(
      message.map((key, value) => MapEntry(key.toString(), value)),
    );

    if (response.controlSignal == IsolateWorkerControlSignals.cancelAcknowledged) {
      final completer = pending.remove(response.requestId);
      if (completer != null && !completer.isCompleted) {
        completer.complete(IsolateWorkerControlSignals.cancelAcknowledged);
      }
      return;
    }

    final streamController = streamPending[response.requestId];
    if (streamController != null) {
      if (response.error != null) {
        streamController.addError(IsolateWorkerException(response.error!));
        if (response.done) {
          streamPending.remove(response.requestId);
          unawaited(streamController.close());
        }
        return;
      }

      if (response.result != null) {
        streamController.add(response.result);
      }
      if (response.done) {
        streamPending.remove(response.requestId);
        unawaited(streamController.close());
      }
      return;
    }

    final completer = pending.remove(response.requestId);
    if (completer == null || completer.isCompleted) {
      return;
    }

    if (response.error != null) {
      completer.completeError(IsolateWorkerException(response.error!));
      return;
    }

    completer.complete(response.result);
  }

  Future<void> disposeWorkerImpl({
    required String shutdownOperation,
  }) async {
    final port = workerPort;
    if (port != null) {
      try {
        await dispatchImpl<void>(
          operation: shutdownOperation,
          payload: const {},
          timeout: const Duration(seconds: 5),
        );
      } on Object {
        // Best-effort shutdown before killing the isolate.
      }
    }

    await responseSubscription?.cancel();
    responsePort?.close();
    responseSubscription = null;
    responsePort = null;
    workerPort = null;

    for (final completer in pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Worker disposed.'));
      }
    }
    pending.clear();

    for (final controller in streamPending.values) {
      if (!controller.isClosed) {
        controller.addError(StateError('Worker disposed.'));
        unawaited(controller.close());
      }
    }
    streamPending.clear();

    isolate?.kill(priority: Isolate.immediate);
    isolate = null;
    starting = null;
  }
}
