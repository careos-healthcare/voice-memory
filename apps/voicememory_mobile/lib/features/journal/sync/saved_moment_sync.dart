import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../../models/journal_entry.dart';

enum SavedMomentSyncMutation { upsert, tombstone }

class SavedMomentSyncRecord {
  const SavedMomentSyncRecord({
    required this.ownerArchiveId,
    required this.entryId,
    required this.revision,
    required this.updatedAt,
    required this.sourceDeviceId,
    required this.mutation,
    required this.payload,
  });

  final String ownerArchiveId;
  final String entryId;
  final int revision;
  final DateTime updatedAt;
  final String sourceDeviceId;
  final SavedMomentSyncMutation mutation;
  final Map<String, dynamic> payload;

  factory SavedMomentSyncRecord.fromMoment(
    SavedMoment moment, {
    required String ownerArchiveId,
    required int revision,
    required String sourceDeviceId,
  }) => SavedMomentSyncRecord(
    ownerArchiveId: ownerArchiveId,
    entryId: moment.id,
    revision: revision,
    updatedAt: moment.updatedAt,
    sourceDeviceId: sourceDeviceId,
    mutation: moment.isDeleted
        ? SavedMomentSyncMutation.tombstone
        : SavedMomentSyncMutation.upsert,
    payload: moment.toJson(includeLocalContext: false)
      ..remove('localAudioPath')
      ..remove('localAudioVaultRef')
      ..remove('mediaAttachments'),
  );

  Map<String, dynamic> toJson() => {
    'ownerArchiveId': ownerArchiveId,
    'entryId': entryId,
    'revision': revision,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'sourceDeviceId': sourceDeviceId,
    'mutation': mutation.name,
    'payload': payload,
  };

  factory SavedMomentSyncRecord.fromJson(Map<String, dynamic> json) =>
      SavedMomentSyncRecord(
        ownerArchiveId: json['ownerArchiveId']?.toString() ?? '',
        entryId: json['entryId']?.toString() ?? '',
        revision: (json['revision'] as num?)?.toInt() ?? 0,
        updatedAt:
            DateTime.tryParse(json['updatedAt']?.toString() ?? '')?.toUtc() ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        sourceDeviceId: json['sourceDeviceId']?.toString() ?? '',
        mutation: SavedMomentSyncMutation.values.byName(
          json['mutation']?.toString() ?? 'upsert',
        ),
        payload: json['payload'] is Map
            ? Map<String, dynamic>.from(json['payload'] as Map)
            : const {},
      );
}

class EncryptedSavedMomentEnvelope {
  const EncryptedSavedMomentEnvelope({
    required this.ownerArchiveId,
    required this.entryId,
    required this.revision,
    required this.ciphertextAndMac,
    required this.nonce,
  });

  final String ownerArchiveId;
  final String entryId;
  final int revision;
  final String ciphertextAndMac;
  final String nonce;

  Map<String, dynamic> toSyncBlob({required DateTime updatedAt}) => {
    'id': entryId,
    'type': 'journal_snapshot',
    'encrypted': {'ciphertext': ciphertextAndMac, 'iv': nonce, 'version': 1},
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'byteLength': base64Decode(ciphertextAndMac).length,
  };

  factory EncryptedSavedMomentEnvelope.fromSyncBlob(
    Map<String, dynamic> blob, {
    required String ownerArchiveId,
  }) {
    final encrypted = blob['encrypted'];
    if (encrypted is! Map || encrypted['version'] != 1) {
      throw StateError('Unsupported encrypted journal envelope.');
    }
    return EncryptedSavedMomentEnvelope(
      ownerArchiveId: ownerArchiveId,
      entryId: blob['id']?.toString() ?? '',
      revision: 0,
      ciphertextAndMac: encrypted['ciphertext']?.toString() ?? '',
      nonce: encrypted['iv']?.toString() ?? '',
    );
  }
}

class SavedMomentSyncCipher {
  const SavedMomentSyncCipher();

  Future<EncryptedSavedMomentEnvelope> encrypt(
    SavedMomentSyncRecord record, {
    required List<int> keyBytes,
  }) async {
    final box = await AesGcm.with256bits().encrypt(
      utf8.encode(jsonEncode(record.toJson())),
      secretKey: SecretKey(keyBytes),
      aad: utf8.encode(_aad(record.ownerArchiveId, record.entryId)),
    );
    return EncryptedSavedMomentEnvelope(
      ownerArchiveId: record.ownerArchiveId,
      entryId: record.entryId,
      revision: record.revision,
      ciphertextAndMac: base64Encode([...box.cipherText, ...box.mac.bytes]),
      nonce: base64Encode(box.nonce),
    );
  }

  Future<SavedMomentSyncRecord> decrypt(
    EncryptedSavedMomentEnvelope envelope, {
    required String expectedOwnerArchiveId,
    required List<int> keyBytes,
  }) async {
    if (envelope.ownerArchiveId != expectedOwnerArchiveId) {
      throw StateError('Cross-account sync envelope rejected.');
    }
    final combined = base64Decode(envelope.ciphertextAndMac);
    if (combined.length <= 16) {
      throw StateError('Encrypted journal envelope is truncated.');
    }
    final cleartext = Uint8List.fromList(
      await AesGcm.with256bits().decrypt(
        SecretBox(
          combined.sublist(0, combined.length - 16),
          nonce: base64Decode(envelope.nonce),
          mac: Mac(combined.sublist(combined.length - 16)),
        ),
        secretKey: SecretKey(keyBytes),
        aad: utf8.encode(_aad(expectedOwnerArchiveId, envelope.entryId)),
      ),
    );
    try {
      final record = SavedMomentSyncRecord.fromJson(
        Map<String, dynamic>.from(jsonDecode(utf8.decode(cleartext)) as Map),
      );
      if (record.ownerArchiveId != expectedOwnerArchiveId ||
          record.entryId != envelope.entryId) {
        throw StateError(
          'Encrypted sync metadata does not match its envelope.',
        );
      }
      return record;
    } finally {
      cleartext.fillRange(0, cleartext.length, 0);
    }
  }

  static String _aad(String ownerArchiveId, String entryId) =>
      'ArchiveMe.SavedMoment.v1|$ownerArchiveId|$entryId';
}
