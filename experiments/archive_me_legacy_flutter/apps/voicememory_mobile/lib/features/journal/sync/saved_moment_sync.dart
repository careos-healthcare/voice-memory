import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../../models/journal_entry.dart';

enum SavedMomentSyncMutation { upsert, tombstone }

class SavedMomentSyncRecord {
  SavedMomentSyncRecord({
    required this.ownerArchiveId,
    required this.entryId,
    required this.revision,
    required this.updatedAt,
    required this.sourceDeviceId,
    required this.mutation,
    required Map<String, dynamic> payload,
  }) : payload = Map.unmodifiable(payload);

  final String ownerArchiveId;
  final String entryId;
  final int revision;
  final DateTime updatedAt;
  final String sourceDeviceId;
  final SavedMomentSyncMutation mutation;
  final Map<String, dynamic> payload;

  factory SavedMomentSyncRecord.fromMoment(
    SavedMoment moment, {
    required int revision,
    required String sourceDeviceId,
  }) => SavedMomentSyncRecord(
    ownerArchiveId: moment.ownerArchiveId,
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
    required this.ciphertext,
    required this.nonce,
    required this.mac,
  });

  final String ownerArchiveId;
  final String entryId;
  final int revision;
  final String ciphertext;
  final String nonce;
  final String mac;
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
      aad: utf8.encode(
        _aad(record.ownerArchiveId, record.entryId, record.revision),
      ),
    );
    return EncryptedSavedMomentEnvelope(
      ownerArchiveId: record.ownerArchiveId,
      entryId: record.entryId,
      revision: record.revision,
      ciphertext: base64Encode(box.cipherText),
      nonce: base64Encode(box.nonce),
      mac: base64Encode(box.mac.bytes),
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
    final cleartext = Uint8List.fromList(
      await AesGcm.with256bits().decrypt(
        SecretBox(
          base64Decode(envelope.ciphertext),
          nonce: base64Decode(envelope.nonce),
          mac: Mac(base64Decode(envelope.mac)),
        ),
        secretKey: SecretKey(keyBytes),
        aad: utf8.encode(
          _aad(envelope.ownerArchiveId, envelope.entryId, envelope.revision),
        ),
      ),
    );
    try {
      final record = SavedMomentSyncRecord.fromJson(
        Map<String, dynamic>.from(jsonDecode(utf8.decode(cleartext)) as Map),
      );
      if (record.ownerArchiveId != expectedOwnerArchiveId ||
          record.entryId != envelope.entryId ||
          record.revision != envelope.revision) {
        throw StateError(
          'Encrypted sync metadata does not match its envelope.',
        );
      }
      return record;
    } finally {
      cleartext.fillRange(0, cleartext.length, 0);
    }
  }

  static String _aad(String ownerArchiveId, String entryId, int revision) =>
      'ArchiveMe.SavedMoment.v1|$ownerArchiveId|$entryId|$revision';
}

/// Account-scoped ordered queue for the canonical saved-moment sync path.
class SavedMomentSyncQueue {
  SavedMomentSyncQueue({required this.ownerArchiveId});

  final String ownerArchiveId;
  final List<SavedMomentSyncRecord> _pending = [];

  List<SavedMomentSyncRecord> get pending => List.unmodifiable(_pending);

  void enqueue(SavedMomentSyncRecord record) {
    if (record.ownerArchiveId != ownerArchiveId) {
      throw StateError('Cross-account queue write rejected.');
    }
    _pending.removeWhere(
      (item) =>
          item.entryId == record.entryId && item.revision <= record.revision,
    );
    _pending.add(record);
    _pending.sort((a, b) {
      final time = a.updatedAt.compareTo(b.updatedAt);
      return time != 0 ? time : a.entryId.compareTo(b.entryId);
    });
  }

  void acknowledge(String entryId, int revision) {
    _pending.removeWhere(
      (item) => item.entryId == entryId && item.revision <= revision,
    );
  }
}

class SavedMomentConflictResolver {
  const SavedMomentConflictResolver._();

  static SavedMomentSyncRecord winner(
    SavedMomentSyncRecord left,
    SavedMomentSyncRecord right,
  ) {
    if (left.ownerArchiveId != right.ownerArchiveId ||
        left.entryId != right.entryId) {
      throw StateError('Unrelated saved moments cannot be reconciled.');
    }
    final revision = left.revision.compareTo(right.revision);
    if (revision != 0) return revision > 0 ? left : right;
    final time = left.updatedAt.compareTo(right.updatedAt);
    if (time != 0) return time > 0 ? left : right;
    final device = left.sourceDeviceId.compareTo(right.sourceDeviceId);
    return device >= 0 ? left : right;
  }
}
