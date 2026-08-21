import 'dart:isolate';

import 'package:flutter/services.dart';

/// IPC operation kinds handled by [LocalDatabaseWorkerService].
enum LocalDatabaseWorkerOperation {
  journalUpsert,
  journalMirror,
  graphBackfill,
  encryptJsonBatch,
  decryptJsonBatch,
  shutdown,
}

/// Startup payload for the persistent database worker isolate.
final class LocalDatabaseWorkerStartup {
  const LocalDatabaseWorkerStartup({
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

  /// Default secure-storage alias for worker-owned SQLCipher opens.
  final String? defaultKeyAlias;
}

/// Request envelope sent from the UI isolate to the worker.
final class LocalDatabaseWorkerRequest {
  const LocalDatabaseWorkerRequest({
    required this.requestId,
    required this.operation,
    required this.payload,
  });

  final int requestId;
  final LocalDatabaseWorkerOperation operation;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => {
        'requestId': requestId,
        'operation': operation.name,
        'payload': payload,
      };

  factory LocalDatabaseWorkerRequest.fromJson(Map<String, dynamic> json) {
    return LocalDatabaseWorkerRequest(
      requestId: json['requestId'] as int? ?? 0,
      operation: LocalDatabaseWorkerOperation.values.byName(
        json['operation'] as String? ??
            LocalDatabaseWorkerOperation.shutdown.name,
      ),
      payload: Map<String, dynamic>.from(
        json['payload'] as Map? ?? const {},
      ),
    );
  }
}

/// Response envelope returned from the worker to the UI isolate.
final class LocalDatabaseWorkerResponse {
  const LocalDatabaseWorkerResponse({
    required this.requestId,
    this.result,
    this.error,
  });

  final int requestId;
  final Object? result;
  final String? error;

  Map<String, dynamic> toJson() => {
        'requestId': requestId,
        if (result != null) 'result': result,
        if (error != null) 'error': error,
      };

  factory LocalDatabaseWorkerResponse.fromJson(Map<String, dynamic> json) {
    return LocalDatabaseWorkerResponse(
      requestId: json['requestId'] as int? ?? 0,
      result: json['result'],
      error: json['error'] as String?,
    );
  }
}
