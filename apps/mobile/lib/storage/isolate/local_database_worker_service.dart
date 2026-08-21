import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archiveme_mobile/models/encrypted_payload_dto.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/storage/isolate/local_database_worker_isolate.dart';
import 'package:archiveme_mobile/storage/isolate/local_database_worker_protocol.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

/// Persistent worker isolate for heavy SQLite batch sync and encryption work.
///
/// Uses SendPort/ReceivePort request/response IPC so the UI isolate can queue
/// multiple operations without spawning a new isolate per call.
class LocalDatabaseWorkerService {
  LocalDatabaseWorkerService._();

  static final LocalDatabaseWorkerService instance =
      LocalDatabaseWorkerService._();

  /// Entry batches at or above this size should prefer this worker on disk DBs.
  static const entryBatchThreshold = 100;

  static bool get _isFlutterTest =>
      Platform.environment.containsKey('FLUTTER_TEST');

  SendPort? _workerPort;
  ReceivePort? _responsePort;
  StreamSubscription<dynamic>? _responseSubscription;
  Isolate? _isolate;
  Future<void>? _starting;
  int _nextRequestId = 1;
  final _pending = <int, Completer<Object?>>{};
  String? _defaultKeyAlias;

  bool get isRunning => _workerPort != null;

  /// Sets the secure-storage alias used when worker requests omit [keyAlias].
  void configure({String? defaultKeyAlias}) {
    _defaultKeyAlias = defaultKeyAlias;
  }

  /// Ensures the persistent worker isolate is spawned and ready.
  Future<void> ensureStarted() {
    if (_workerPort != null) {
      return Future<void>.value();
    }
    return _starting ??= _spawnWorker();
  }

  Future<void> runJournalUpsert({
    required String filePath,
    String? encryptionPassword,
    String? keyAlias,
    required List<JournalEntry> entries,
  }) {
    return _dispatch<void>(
      operation: LocalDatabaseWorkerOperation.journalUpsert,
      payload: _databasePayload(
        filePath: filePath,
        encryptionPassword: encryptionPassword,
        keyAlias: keyAlias,
        extra: {
          'journalEntryMaps': entries.map((entry) => entry.toJson()).toList(),
        },
      ),
    );
  }

  Future<void> runJournalMirror({
    required String filePath,
    String? encryptionPassword,
    String? keyAlias,
    required List<JournalEntry> entries,
  }) {
    return _dispatch<void>(
      operation: LocalDatabaseWorkerOperation.journalMirror,
      payload: _databasePayload(
        filePath: filePath,
        encryptionPassword: encryptionPassword,
        keyAlias: keyAlias,
        extra: {
          'journalEntryMaps': entries.map((entry) => entry.toJson()).toList(),
        },
      ),
    );
  }

  Future<int> runGraphBackfill({
    required String filePath,
    String? encryptionPassword,
    String? keyAlias,
  }) {
    return _dispatch<int>(
      operation: LocalDatabaseWorkerOperation.graphBackfill,
      payload: _databasePayload(
        filePath: filePath,
        encryptionPassword: encryptionPassword,
        keyAlias: keyAlias,
      ),
    );
  }

  /// Encrypts [payloadMaps] with [masterKeyBytes] off the UI thread.
  Future<List<EncryptedPayload>> encryptJsonBatch({
    required Uint8List masterKeyBytes,
    required List<Map<String, dynamic>> payloadMaps,
  }) async {
    final result = await _dispatch<List<dynamic>>(
      operation: LocalDatabaseWorkerOperation.encryptJsonBatch,
      payload: {
        'masterKeyBytes': masterKeyBytes,
        'payloadMaps': payloadMaps,
      },
    );

    return result
        .whereType<Map>()
        .map((item) => EncryptedPayload.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  /// Decrypts [encryptedPayloadMaps] with [masterKeyBytes] off the UI thread.
  Future<List<Map<String, dynamic>>> decryptJsonBatch({
    required Uint8List masterKeyBytes,
    required List<Map<String, dynamic>> encryptedPayloadMaps,
  }) async {
    final result = await _dispatch<List<dynamic>>(
      operation: LocalDatabaseWorkerOperation.decryptJsonBatch,
      payload: {
        'masterKeyBytes': masterKeyBytes,
        'encryptedPayloadMaps': encryptedPayloadMaps,
      },
    );

    return result
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  /// Stops the worker isolate and closes its SQLite connections.
  Future<void> dispose() async {
    final workerPort = _workerPort;
    if (workerPort != null) {
      try {
        await _dispatch<void>(
          operation: LocalDatabaseWorkerOperation.shutdown,
          payload: const {},
          timeout: const Duration(seconds: 5),
        );
      } on Object {
        // Best-effort shutdown before killing the isolate.
      }
    }

    await _responseSubscription?.cancel();
    _responsePort?.close();
    _responseSubscription = null;
    _responsePort = null;
    _workerPort = null;

    for (final pending in _pending.values) {
      if (!pending.isCompleted) {
        pending.completeError(StateError('Local database worker disposed.'));
      }
    }
    _pending.clear();

    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _starting = null;
  }

  static bool shouldUseBackgroundWorker({
    required String filePath,
    required int entryCount,
  }) {
    if (entryCount < entryBatchThreshold) {
      return false;
    }
    return filePath != ':memory:' && filePath != inMemoryDatabasePath;
  }

  Future<void> _spawnWorker() async {
    final handshakePort = ReceivePort();
    final responsePort = ReceivePort();

    _responseSubscription = responsePort.listen(_handleWorkerResponse);
    _responsePort = responsePort;

    _isolate = await Isolate.spawn(
      localDatabaseWorkerIsolateEntry,
      LocalDatabaseWorkerStartup(
        handshakePort: handshakePort.sendPort,
        clientResponsePort: responsePort.sendPort,
        initializeTestFfi: _isFlutterTest,
        rootIsolateToken: _isFlutterTest ? null : RootIsolateToken.instance,
        defaultKeyAlias: _defaultKeyAlias,
      ),
    );

    final workerPort = await handshakePort.first;
    handshakePort.close();
    if (workerPort is! SendPort) {
      throw StateError('Local database worker failed handshake.');
    }
    _workerPort = workerPort;
  }

  void _handleWorkerResponse(Object? message) {
    if (message is! Map) {
      return;
    }

    final response = LocalDatabaseWorkerResponse.fromJson(
      message.map((key, value) => MapEntry(key.toString(), value)),
    );
    final completer = _pending.remove(response.requestId);
    if (completer == null || completer.isCompleted) {
      return;
    }

    if (response.error != null) {
      completer.completeError(
        LocalDatabaseWorkerException(response.error!),
      );
      return;
    }

    completer.complete(response.result);
  }

  Future<T> _dispatch<T>({
    required LocalDatabaseWorkerOperation operation,
    required Map<String, dynamic> payload,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    await ensureStarted();
    final workerPort = _workerPort;
    if (workerPort == null) {
      throw StateError('Local database worker is not running.');
    }

    final requestId = _nextRequestId++;
    final completer = Completer<Object?>();
    _pending[requestId] = completer;

    workerPort.send(
      LocalDatabaseWorkerRequest(
        requestId: requestId,
        operation: operation,
        payload: payload,
      ).toJson(),
    );

    final result = await completer.future.timeout(
      timeout,
      onTimeout: () {
        _pending.remove(requestId);
        throw TimeoutException(
          'Local database worker timed out for ${operation.name}.',
        );
      },
    );
    return result as T;
  }

  Map<String, dynamic> _databasePayload({
    required String filePath,
    String? encryptionPassword,
    String? keyAlias,
    Map<String, dynamic>? extra,
  }) {
    return {
      'filePath': filePath,
      if (encryptionPassword != null) 'encryptionPassword': encryptionPassword,
      if (keyAlias != null) 'keyAlias': keyAlias,
      ...?extra,
    };
  }
}

/// Error raised when the worker isolate reports a failed operation.
final class LocalDatabaseWorkerException implements Exception {
  LocalDatabaseWorkerException(this.message);

  final String message;

  @override
  String toString() => 'LocalDatabaseWorkerException: $message';
}
