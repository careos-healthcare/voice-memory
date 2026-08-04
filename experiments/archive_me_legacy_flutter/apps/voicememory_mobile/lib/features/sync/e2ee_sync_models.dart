import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../models/journal_sync_metadata.dart';
import '../../services/security/sync_identity_service.dart';

enum CrdtEntityKind {
  node,
  edge,
  transcript,
  confidence,
  semanticCluster,
  actionPlan,
  mediaManifest,
  mediaChunk,
}

enum CrdtMutation { upsert, delete }

class CrdtOperation {
  CrdtOperation({
    required this.id,
    required this.deviceId,
    required this.entityKind,
    required this.entityId,
    required this.mutation,
    required Map<String, int> vectorClock,
    required DateTime timestamp,
    required Map<String, dynamic> payload,
  }) : timestamp = timestamp.toUtc(),
       vectorClock = Map.unmodifiable(vectorClock),
       payload = Map.unmodifiable(payload);

  final String id;
  final String deviceId;
  final CrdtEntityKind entityKind;
  final String entityId;
  final CrdtMutation mutation;
  final Map<String, int> vectorClock;
  final DateTime timestamp;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => {
    'id': id,
    'deviceId': deviceId,
    'entityKind': entityKind.name,
    'entityId': entityId,
    'mutation': mutation.name,
    'vectorClock': vectorClock,
    'timestamp': timestamp.toIso8601String(),
    'payload': payload,
  };

  factory CrdtOperation.fromJson(Map<String, dynamic> json) => CrdtOperation(
    id: '${json['id']}',
    deviceId: '${json['deviceId']}',
    entityKind: CrdtEntityKind.values.byName('${json['entityKind']}'),
    entityId: '${json['entityId']}',
    mutation: CrdtMutation.values.byName('${json['mutation']}'),
    vectorClock: _clock(json['vectorClock']),
    timestamp:
        DateTime.tryParse('${json['timestamp']}') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    payload: json['payload'] is Map
        ? Map<String, dynamic>.from(json['payload'] as Map)
        : const {},
  );

  /// Positive means [left] deterministically wins.
  static int compare(CrdtOperation left, CrdtOperation right) {
    switch (compareVectorClocks(left.vectorClock, right.vectorClock)) {
      case VectorClockRelation.dominates:
        return 1;
      case VectorClockRelation.isDominated:
        return -1;
      case VectorClockRelation.equal:
      case VectorClockRelation.concurrent:
        final time = left.timestamp.compareTo(right.timestamp);
        if (time != 0) return time;
        final device = left.deviceId.compareTo(right.deviceId);
        if (device != 0) return device;
        return left.id.compareTo(right.id);
    }
  }
}

class E2EESyncEnvelope {
  E2EESyncEnvelope({
    required this.id,
    required this.deviceId,
    required Map<String, int> vectorClock,
    required this.encryptedBlob,
    required this.nonce,
    required this.keyEpoch,
    required DateTime createdAt,
  }) : vectorClock = Map.unmodifiable(vectorClock),
       createdAt = createdAt.toUtc();

  final String id;
  final String deviceId;
  final Map<String, int> vectorClock;
  final String encryptedBlob;
  final String nonce;
  final int keyEpoch;
  final DateTime createdAt;

  Map<String, dynamic> toRelayBlob() => {
    'id': id,
    'type': 'crdt_operations',
    'deviceId': deviceId,
    'vectorClock': vectorClock,
    'keyEpoch': keyEpoch,
    'encrypted': {'ciphertext': encryptedBlob, 'iv': nonce, 'version': 1},
    'updatedAt': createdAt.toIso8601String(),
    'byteLength': encryptedBlob.length,
  };

  factory E2EESyncEnvelope.fromRelayBlob(Map<String, dynamic> json) {
    final encrypted = Map<String, dynamic>.from(json['encrypted'] as Map);
    return E2EESyncEnvelope(
      id: '${json['id']}',
      deviceId: '${json['deviceId']}',
      vectorClock: _clock(json['vectorClock']),
      encryptedBlob: '${encrypted['ciphertext']}',
      nonce: '${encrypted['iv']}',
      keyEpoch: (json['keyEpoch'] as num?)?.toInt() ?? 1,
      createdAt:
          DateTime.tryParse('${json['updatedAt']}') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

class E2EESyncCipher {
  const E2EESyncCipher();

  static const _aadPrefix = 'ArchiveMe.E2EE.CRDT.v1';

  Future<E2EESyncEnvelope> encrypt({
    required String id,
    required String deviceId,
    required Map<String, int> vectorClock,
    required List<CrdtOperation> operations,
    required SyncEncryptionKey key,
    required int keyEpoch,
    DateTime? createdAt,
  }) async {
    final aad = utf8.encode(_aad(deviceId, vectorClock, keyEpoch));
    final cleartext = Uint8List.fromList(
      utf8.encode(jsonEncode(operations.map((item) => item.toJson()).toList())),
    );
    try {
      final box = await AesGcm.with256bits().encrypt(
        cleartext,
        secretKey: SecretKey(key.bytes),
        aad: aad,
      );
      return E2EESyncEnvelope(
        id: id,
        deviceId: deviceId,
        vectorClock: vectorClock,
        encryptedBlob: base64Encode([...box.cipherText, ...box.mac.bytes]),
        nonce: base64Encode(box.nonce),
        keyEpoch: keyEpoch,
        createdAt: createdAt ?? DateTime.now(),
      );
    } finally {
      cleartext.fillRange(0, cleartext.length, 0);
    }
  }

  Future<List<CrdtOperation>> decrypt(
    E2EESyncEnvelope envelope, {
    required SyncEncryptionKey key,
  }) async {
    final combined = base64Decode(envelope.encryptedBlob);
    if (combined.length <= 16) {
      throw SecretBoxAuthenticationError();
    }
    final cleartext = Uint8List.fromList(
      await AesGcm.with256bits().decrypt(
        SecretBox(
          combined.sublist(0, combined.length - 16),
          nonce: base64Decode(envelope.nonce),
          mac: Mac(combined.sublist(combined.length - 16)),
        ),
        secretKey: SecretKey(key.bytes),
        aad: utf8.encode(
          _aad(envelope.deviceId, envelope.vectorClock, envelope.keyEpoch),
        ),
      ),
    );
    try {
      final decoded = jsonDecode(utf8.decode(cleartext));
      if (decoded is! List) throw const FormatException('Invalid CRDT batch.');
      return decoded
          .whereType<Map>()
          .map(
            (item) => CrdtOperation.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false);
    } finally {
      cleartext.fillRange(0, cleartext.length, 0);
    }
  }

  String _aad(String deviceId, Map<String, int> clock, int epoch) {
    final ordered = clock.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return '$_aadPrefix|$deviceId|$epoch|'
        '${ordered.map((item) => '${item.key}:${item.value}').join(',')}';
  }
}

Map<String, int> _clock(Object? raw) {
  if (raw is! Map) return const {};
  return Map.unmodifiable({
    for (final item in raw.entries)
      if (item.value is num) '${item.key}': (item.value as num).toInt(),
  });
}
