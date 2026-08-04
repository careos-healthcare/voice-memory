import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../domain/vault_chunk_payload.dart';

typedef EmergencyVaultDirectoryResolver = Future<Directory> Function();

enum EmergencyVaultIntegrityIssue { missingPayload }

class EmergencyVaultIntegrityException implements Exception {
  const EmergencyVaultIntegrityException({
    required this.issue,
    required this.chunkIds,
  });

  final EmergencyVaultIntegrityIssue issue;
  final List<String> chunkIds;

  @override
  String toString() =>
      'EmergencyVaultIntegrityException($issue, chunks: ${chunkIds.join(', ')})';
}

/// Persists unsynced emergency vault PCM chunks on disk until server ACK.
class EmergencyVaultStorage {
  EmergencyVaultStorage({
    File? manifestFile,
    EmergencyVaultDirectoryResolver? resolveChunkDirectory,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid(),
       _resolveChunkDirectory =
           resolveChunkDirectory ?? _defaultChunkDirectory {
    if (manifestFile != null) {
      _manifestFile = manifestFile;
    }
  }

  static const _manifestFileName = 'emergency_vault_chunk_queue.json';
  static const _chunkDirectoryName = 'live_audio_emergency_chunks';
  static const _sidecarSuffix = '.meta.json';

  final Uuid _uuid;
  final EmergencyVaultDirectoryResolver _resolveChunkDirectory;
  File? _manifestFile;
  Future<void> _operationTail = Future<void>.value();

  Future<File> _manifestPath() async {
    return _manifestFile ??= File(
      '${(await getApplicationSupportDirectory()).path}/$_manifestFileName',
    );
  }

  static Future<Directory> _defaultChunkDirectory() async {
    final supportDir = await getApplicationSupportDirectory();
    final chunkDir = Directory('${supportDir.path}/$_chunkDirectoryName');
    if (!await chunkDir.exists()) {
      await chunkDir.create(recursive: true);
    }
    return chunkDir;
  }

  Future<Directory> chunkDirectory() => _resolveChunkDirectory();

  /// Queues a PCM chunk for background upload with a stamped idempotency envelope.
  Future<VaultChunkPayload> enqueueChunk({
    required String sessionId,
    required List<int> bytes,
    String? idempotencyKey,
    DateTime? recordedAt,
  }) => _serialized(() async {
    final records = await _readAndReconcileRecords();
    final sequence =
        records
            .where((record) => record.sessionId == sessionId)
            .map((record) => record.sequence)
            .fold<int>(0, (max, value) => value > max ? value : max) +
        1;
    final payload = VaultChunkPayload.create(
      sessionId: sessionId,
      bytes: bytes,
      recordedAt: recordedAt,
      idempotencyKey: idempotencyKey,
      uuid: _uuid,
    );

    final chunkDir = await chunkDirectory();
    if (!await chunkDir.exists()) {
      await chunkDir.create(recursive: true);
    }

    final payloadFile = File('${chunkDir.path}/${payload.id}.bin');
    final record = _ChunkRecord(
      id: payload.id,
      sessionId: payload.sessionId,
      sequence: sequence,
      idempotencyKey: payload.idempotencyKey,
      recordedAt: payload.recordedAt,
      payloadPath: payloadFile.path,
      synced: false,
    );

    // The metadata is durable before the payload write starts. A process death
    // after the payload flush but before the queue manifest commit can
    // therefore be reconciled without storing plaintext audio in metadata.
    await _writeSidecar(record);
    await payloadFile.writeAsBytes(bytes, flush: true);
    records.add(record);
    await _writeRecords(records);

    return payload;
  });

  Future<List<VaultChunkPayload>> getUnsyncedChunks() => _serialized(() async {
    final records = await _readAndReconcileRecords();
    final pending = records.where((record) => !record.synced).toList()
      ..sort((a, b) {
        final sessionCompare = a.sessionId.compareTo(b.sessionId);
        if (sessionCompare != 0) {
          return sessionCompare;
        }
        return a.sequence.compareTo(b.sequence);
      });

    final payloads = <VaultChunkPayload>[];
    final missingChunkIds = <String>[];
    for (final record in pending) {
      final file = File(record.payloadPath);
      if (!await file.exists()) {
        missingChunkIds.add(record.id);
        continue;
      }
      payloads.add(
        VaultChunkPayload.fromJson(
          record.toEnvelopeJson(),
          bytes: await file.readAsBytes(),
        ),
      );
    }
    if (missingChunkIds.isNotEmpty) {
      throw EmergencyVaultIntegrityException(
        issue: EmergencyVaultIntegrityIssue.missingPayload,
        chunkIds: List<String>.unmodifiable(missingChunkIds),
      );
    }
    return payloads;
  });

  Future<bool> hasUncommittedChunks() => _serialized(() async {
    final records = await _readAndReconcileRecords();
    return records.any((record) => !record.synced);
  });

  Future<void> markChunkSynced(String chunkId) => _serialized(() async {
    final records = await _readAndReconcileRecords();
    var updated = false;
    for (var i = 0; i < records.length; i++) {
      if (records[i].id == chunkId) {
        records[i] = records[i].copyWith(synced: true);
        await _writeSidecar(records[i]);
        updated = true;
        break;
      }
    }
    if (updated) {
      await _writeRecords(records);
    }
  });

  Future<void> purgeSyncedChunks() => _serialized(() async {
    final records = await _readAndReconcileRecords();
    final retained = <_ChunkRecord>[];
    for (final record in records) {
      if (!record.synced) {
        retained.add(record);
        continue;
      }
      final file = File(record.payloadPath);
      if (await file.exists()) {
        await file.delete();
      }
      final sidecar = _sidecarFor(record);
      if (await sidecar.exists()) {
        await sidecar.delete();
      }
    }
    await _writeRecords(retained);
  });

  /// Removes all emergency audio payloads and recovery metadata.
  Future<void> wipeAll() => _serialized(() async {
    final chunkDir = await chunkDirectory();
    if (await chunkDir.exists()) {
      await chunkDir.delete(recursive: true);
    }
    final manifest = await _manifestPath();
    if (await manifest.exists()) {
      await manifest.delete();
    }
  });

  Future<List<_ChunkRecord>> _readAndReconcileRecords() async {
    final manifest = await _manifestPath();
    var manifestNeedsRewrite = false;
    var records = <_ChunkRecord>[];
    if (!await manifest.exists()) {
      manifestNeedsRewrite = true;
    } else {
      try {
        final decoded = jsonDecode(await manifest.readAsString());
        if (decoded is! List) {
          throw const FormatException('Vault chunk manifest is not a list.');
        }
        records = decoded
            .map(
              (entry) => _ChunkRecord.fromJson(
                Map<String, dynamic>.from(entry as Map),
              ),
            )
            .toList();
      } on Object {
        // Atomic sidecars are the recovery journal for a torn/legacy manifest.
        records = <_ChunkRecord>[];
        manifestNeedsRewrite = true;
      }
    }

    final recordsById = <String, _ChunkRecord>{
      for (final record in records) record.id: record,
    };
    final chunkDir = await chunkDirectory();
    if (await chunkDir.exists()) {
      await for (final entity in chunkDir.list()) {
        if (entity is! File || !entity.path.endsWith(_sidecarSuffix)) {
          continue;
        }
        try {
          final decoded = jsonDecode(await entity.readAsString());
          final sidecarRecord = _ChunkRecord.fromJson(
            Map<String, dynamic>.from(decoded as Map),
          );
          if (!await File(sidecarRecord.payloadPath).exists()) {
            continue;
          }
          final existing = recordsById[sidecarRecord.id];
          if (existing == null || existing.synced != sidecarRecord.synced) {
            recordsById[sidecarRecord.id] = sidecarRecord;
            manifestNeedsRewrite = true;
          }
        } on Object {
          // Preserve malformed sidecars for forensic/backstop recovery.
        }
      }
    }

    final reconciled = recordsById.values.toList();
    if (manifestNeedsRewrite) {
      await _writeRecords(reconciled);
    }
    return reconciled;
  }

  Future<void> _writeRecords(List<_ChunkRecord> records) async {
    final manifest = await _manifestPath();
    final parent = manifest.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    await _atomicWrite(
      manifest,
      utf8.encode(
        jsonEncode(records.map((record) => record.toJson()).toList()),
      ),
    );
  }

  Future<void> _writeSidecar(_ChunkRecord record) {
    return _atomicWrite(
      _sidecarFor(record),
      utf8.encode(jsonEncode(record.toJson())),
    );
  }

  File _sidecarFor(_ChunkRecord record) => File(
    '${File(record.payloadPath).parent.path}/${record.id}$_sidecarSuffix',
  );

  Future<void> _atomicWrite(File destination, List<int> bytes) async {
    final parent = destination.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    final temporary = File('${destination.path}.tmp');
    if (await temporary.exists()) {
      await temporary.delete();
    }
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(destination.path);
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final operation = _operationTail.then((_) => action());
    _operationTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }
}

class _ChunkRecord {
  const _ChunkRecord({
    required this.id,
    required this.sessionId,
    required this.sequence,
    required this.idempotencyKey,
    required this.recordedAt,
    required this.payloadPath,
    required this.synced,
  });

  factory _ChunkRecord.fromJson(Map<String, dynamic> json) {
    final recordedRaw = json['recordedAt'] ?? json['recorded_at'];
    return _ChunkRecord(
      id: json['id'] as String,
      sessionId: json['sessionId'] as String,
      sequence: (json['sequence'] as num?)?.toInt() ?? 0,
      idempotencyKey: json['idempotencyKey'] as String,
      recordedAt: recordedRaw == null
          ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
          : DateTime.parse(recordedRaw as String),
      payloadPath: json['payloadPath'] as String,
      synced: json['synced'] as bool? ?? false,
    );
  }

  final String id;
  final String sessionId;
  final int sequence;
  final String idempotencyKey;
  final DateTime recordedAt;
  final String payloadPath;
  final bool synced;

  Map<String, dynamic> toJson() => {
    'id': id,
    'sessionId': sessionId,
    'sequence': sequence,
    'idempotencyKey': idempotencyKey,
    'recordedAt': recordedAt.toUtc().toIso8601String(),
    'payloadPath': payloadPath,
    'synced': synced,
  };

  Map<String, dynamic> toEnvelopeJson() => {
    'id': id,
    'session_id': sessionId,
    'byte_length': 0,
    'recorded_at': recordedAt.toUtc().toIso8601String(),
    'idempotency_key': idempotencyKey,
    'is_synced': synced,
  };

  _ChunkRecord copyWith({bool? synced}) {
    return _ChunkRecord(
      id: id,
      sessionId: sessionId,
      sequence: sequence,
      idempotencyKey: idempotencyKey,
      recordedAt: recordedAt,
      payloadPath: payloadPath,
      synced: synced ?? this.synced,
    );
  }
}
