import 'dart:async';
import 'dart:isolate';
import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/models/encrypted_payload_dto.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/storage/isolate/local_database_worker_protocol.dart';
import 'package:archiveme_mobile/storage/sqlite/isolate_safe_sqlite_database_initializer.dart';
import 'package:archiveme_mobile/storage/sqlite/journal_sqlite_bulk_sync.dart';
import 'package:archiveme_mobile/storage/sqlite/reflection_graph_backfill.dart';
import 'package:archiveme_mobile/sync/sync_crypto.dart';
import 'package:sqflite/sqflite.dart';

/// Top-level entry for the persistent local database worker isolate.
Future<void> localDatabaseWorkerIsolateEntry(
  LocalDatabaseWorkerStartup startup,
) async {
  IsolateSafeSqliteDatabaseInitializer.ensureWorkerRuntime(
    initializeTestFfi: startup.initializeTestFfi,
    rootIsolateToken: startup.rootIsolateToken,
  );

  final worker = _LocalDatabaseWorkerRuntime(
    defaultKeyAlias: startup.defaultKeyAlias,
  );
  final serverPort = ReceivePort();
  startup.handshakePort.send(serverPort.sendPort);

  await for (final message in serverPort) {
    if (message is! Map) {
      continue;
    }

    final request = LocalDatabaseWorkerRequest.fromJson(
      message.map((key, value) => MapEntry(key.toString(), value)),
    );

    if (request.operation == LocalDatabaseWorkerOperation.shutdown) {
      await worker.dispose();
      serverPort.close();
      break;
    }

    try {
      final result = await worker.handle(request);
      startup.clientResponsePort.send(
        LocalDatabaseWorkerResponse(
          requestId: request.requestId,
          result: result,
        ).toJson(),
      );
    } on Object catch (error, stackTrace) {
      startup.clientResponsePort.send(
        LocalDatabaseWorkerResponse(
          requestId: request.requestId,
          error: '$error',
        ).toJson(),
      );
    }
  }
}

final class _LocalDatabaseWorkerRuntime {
  _LocalDatabaseWorkerRuntime({this.defaultKeyAlias});

  final String? defaultKeyAlias;
  final _connections = <String, Database>{};

  Future<Object?> handle(LocalDatabaseWorkerRequest request) async {
    switch (request.operation) {
      case LocalDatabaseWorkerOperation.journalUpsert:
        await JournalSqliteBulkSync.upsertEntries(
          await _databaseFor(request.payload),
          _decodeEntries(request.payload['journalEntryMaps']),
        );
        return null;
      case LocalDatabaseWorkerOperation.journalMirror:
        await JournalSqliteBulkSync.mirrorEntireRemoteState(
          await _databaseFor(request.payload),
          _decodeEntries(request.payload['journalEntryMaps']),
        );
        return null;
      case LocalDatabaseWorkerOperation.graphBackfill:
        return await ReflectionGraphBackfill.fromJournalEntries(
          await _databaseFor(request.payload),
        );
      case LocalDatabaseWorkerOperation.encryptJsonBatch:
        return _encryptJsonBatch(request.payload);
      case LocalDatabaseWorkerOperation.decryptJsonBatch:
        return _decryptJsonBatch(request.payload);
      case LocalDatabaseWorkerOperation.shutdown:
        return null;
    }
  }

  Future<Database> _databaseFor(Map<String, dynamic> payload) async {
    final filePath = payload['filePath'] as String? ?? '';
    if (filePath.isEmpty) {
      throw ArgumentError('filePath is required for database operations.');
    }
    final passwordOverride = payload['encryptionPassword'] as String?;
    final keyAlias =
        payload['keyAlias'] as String? ?? defaultKeyAlias;
    final cacheKey = '$filePath|${keyAlias ?? passwordOverride ?? ''}';

    final cached = _connections[cacheKey];
    if (cached != null && cached.isOpen) {
      return cached;
    }

    final db = await IsolateSafeSqliteDatabaseInitializer.openWorkerConnection(
      filePath: filePath,
      passwordOverride: passwordOverride,
      keyAlias: keyAlias,
    );
    _connections[cacheKey] = db;
    return db;
  }

  List<JournalEntry> _decodeEntries(Object? rawMaps) {
    if (rawMaps is! List) {
      return const [];
    }
    return rawMaps
        .whereType<Map>()
        .map((entry) => JournalEntry.fromJson(Map<String, dynamic>.from(entry)))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _encryptJsonBatch(
    Map<String, dynamic> payload,
  ) async {
    final crypto = SyncCrypto(_readMasterKeyBytes(payload));
    final items = payload['payloadMaps'];
    if (items is! List) {
      return const [];
    }

    final encrypted = <Map<String, dynamic>>[];
    for (final item in items) {
      if (item is! Map) {
        continue;
      }
      final envelope = await crypto.encryptJson(Map<String, dynamic>.from(item));
      encrypted.add(envelope.toJson());
    }
    return encrypted;
  }

  Future<List<Map<String, dynamic>>> _decryptJsonBatch(
    Map<String, dynamic> payload,
  ) async {
    final crypto = SyncCrypto(_readMasterKeyBytes(payload));
    final items = payload['encryptedPayloadMaps'];
    if (items is! List) {
      return const [];
    }

    final decrypted = <Map<String, dynamic>>[];
    for (final item in items) {
      if (item is! Map) {
        continue;
      }
      final envelope = EncryptedPayload.fromJson(Map<String, dynamic>.from(item));
      decrypted.add(await crypto.decryptJson(envelope));
    }
    return decrypted;
  }

  Uint8List _readMasterKeyBytes(Map<String, dynamic> payload) {
    final raw = payload['masterKeyBytes'];
    if (raw is Uint8List) {
      return raw;
    }
    if (raw is List<int>) {
      return Uint8List.fromList(raw);
    }
    throw ArgumentError('masterKeyBytes must be a Uint8List or List<int>.');
  }

  Future<void> dispose() async {
    for (final db in _connections.values) {
      if (db.isOpen) {
        await db.close();
      }
    }
    _connections.clear();
  }
}