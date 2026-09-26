import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

/// How often a record sync runs, and how long a tombstone is kept.
abstract final class RecordSyncSchedule {
  RecordSyncSchedule._();

  static const pushDebounce = Duration(seconds: 5);
  static const foregroundPull = Duration(minutes: 15);
  static const tombstoneRetention = Duration(days: 180);
  static const mediaChunkBytes = 4 * 1024 * 1024;
  static const freeQuotaBytes = 5 * 1024 * 1024 * 1024;
  static const pairExpiry = Duration(minutes: 5);
  static const quotaMessage = 'Thoughtprint sync storage is full (5 GB).';

  static bool pullDue(DateTime? lastPull, DateTime now) {
    if (lastPull == null) return true;
    return !now.toUtc().isBefore(lastPull.toUtc().add(foregroundPull));
  }

  static Duration backoff(int attempt) {
    if (attempt <= 1) return const Duration(seconds: 1);
    final seconds = 1 << (attempt - 1);
    return Duration(seconds: seconds > 60 ? 60 : seconds);
  }
}

enum SyncRecordKind { entry, photo, audio, tombstone }

class SealedSyncRecord {
  const SealedSyncRecord({
    required this.recordId,
    required this.kind,
    required this.version,
    required this.updatedAt,
    required this.deviceId,
    required this.ciphertext,
    required this.nonce,
    required this.keyVersion,
  });

  final String recordId;
  final SyncRecordKind kind;
  final int version;
  final DateTime updatedAt;
  final String deviceId;
  final String ciphertext;
  final String nonce;
  final int keyVersion;

  Map<String, Object> toJson() => {
    'recordId': recordId,
    'kind': kind.name,
    'version': version,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'deviceId': deviceId,
    'ciphertext': ciphertext,
    'nonce': nonce,
    'keyVersion': keyVersion,
  };

  bool tombstoneActive(DateTime now) {
    if (kind != SyncRecordKind.tombstone) return false;
    return now.toUtc().isBefore(updatedAt.toUtc().add(RecordSyncSchedule.tombstoneRetention));
  }
}

class EntryFieldState {
  const EntryFieldState({
    required this.transcript,
    required this.baseTranscript,
    required this.transcriptUpdatedAt,
    required this.transcriptDeviceId,
    required this.title,
    required this.titleUpdatedAt,
    required this.titleDeviceId,
    required this.mood,
    required this.moodUpdatedAt,
    required this.moodDeviceId,
    required this.place,
    required this.placeUpdatedAt,
    required this.placeDeviceId,
    required this.tags,
    required this.tagsUpdatedAt,
    required this.tagsDeviceId,
    this.blobIds = const [],
  });

  final String transcript;
  final String baseTranscript;
  final DateTime transcriptUpdatedAt;
  final String transcriptDeviceId;
  final String title;
  final DateTime titleUpdatedAt;
  final String titleDeviceId;
  final String mood;
  final DateTime moodUpdatedAt;
  final String moodDeviceId;
  final String place;
  final DateTime placeUpdatedAt;
  final String placeDeviceId;
  final List<String> tags;
  final DateTime tagsUpdatedAt;
  final String tagsDeviceId;
  final List<String> blobIds;

  EntryFieldState copyWith({
    String? transcript,
    String? baseTranscript,
    DateTime? transcriptUpdatedAt,
    String? transcriptDeviceId,
    String? title,
    DateTime? titleUpdatedAt,
    String? titleDeviceId,
    String? mood,
    DateTime? moodUpdatedAt,
    String? moodDeviceId,
    String? place,
    DateTime? placeUpdatedAt,
    String? placeDeviceId,
    List<String>? tags,
    DateTime? tagsUpdatedAt,
    String? tagsDeviceId,
    List<String>? blobIds,
  }) {
    return EntryFieldState(
      transcript: transcript ?? this.transcript,
      baseTranscript: baseTranscript ?? this.baseTranscript,
      transcriptUpdatedAt: transcriptUpdatedAt ?? this.transcriptUpdatedAt,
      transcriptDeviceId: transcriptDeviceId ?? this.transcriptDeviceId,
      title: title ?? this.title,
      titleUpdatedAt: titleUpdatedAt ?? this.titleUpdatedAt,
      titleDeviceId: titleDeviceId ?? this.titleDeviceId,
      mood: mood ?? this.mood,
      moodUpdatedAt: moodUpdatedAt ?? this.moodUpdatedAt,
      moodDeviceId: moodDeviceId ?? this.moodDeviceId,
      place: place ?? this.place,
      placeUpdatedAt: placeUpdatedAt ?? this.placeUpdatedAt,
      placeDeviceId: placeDeviceId ?? this.placeDeviceId,
      tags: tags ?? this.tags,
      tagsUpdatedAt: tagsUpdatedAt ?? this.tagsUpdatedAt,
      tagsDeviceId: tagsDeviceId ?? this.tagsDeviceId,
      blobIds: blobIds ?? this.blobIds,
    );
  }

  Map<String, Object> toJson() => {
    'transcript': transcript,
    'baseTranscript': baseTranscript,
    'transcriptUpdatedAt': transcriptUpdatedAt.toUtc().toIso8601String(),
    'transcriptDeviceId': transcriptDeviceId,
    'title': title,
    'titleUpdatedAt': titleUpdatedAt.toUtc().toIso8601String(),
    'titleDeviceId': titleDeviceId,
    'mood': mood,
    'moodUpdatedAt': moodUpdatedAt.toUtc().toIso8601String(),
    'moodDeviceId': moodDeviceId,
    'place': place,
    'placeUpdatedAt': placeUpdatedAt.toUtc().toIso8601String(),
    'placeDeviceId': placeDeviceId,
    'tags': tags,
    'tagsUpdatedAt': tagsUpdatedAt.toUtc().toIso8601String(),
    'tagsDeviceId': tagsDeviceId,
    'blobIds': blobIds,
  };

  factory EntryFieldState.fromJson(Map<String, dynamic> json) {
    DateTime time(Object? raw) =>
        DateTime.tryParse('$raw')?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return EntryFieldState(
      transcript: '${json['transcript'] ?? ''}',
      baseTranscript: '${json['baseTranscript'] ?? ''}',
      transcriptUpdatedAt: time(json['transcriptUpdatedAt']),
      transcriptDeviceId: '${json['transcriptDeviceId'] ?? ''}',
      title: '${json['title'] ?? ''}',
      titleUpdatedAt: time(json['titleUpdatedAt']),
      titleDeviceId: '${json['titleDeviceId'] ?? ''}',
      mood: '${json['mood'] ?? ''}',
      moodUpdatedAt: time(json['moodUpdatedAt']),
      moodDeviceId: '${json['moodDeviceId'] ?? ''}',
      place: '${json['place'] ?? ''}',
      placeUpdatedAt: time(json['placeUpdatedAt']),
      placeDeviceId: '${json['placeDeviceId'] ?? ''}',
      tags: [
        for (final tag in (json['tags'] as List?) ?? const []) '$tag',
      ],
      tagsUpdatedAt: time(json['tagsUpdatedAt']),
      tagsDeviceId: '${json['tagsDeviceId'] ?? ''}',
      blobIds: [
        for (final id in (json['blobIds'] as List?) ?? const []) '$id',
      ],
    );
  }
}

class TranscriptConflict {
  const TranscriptConflict({required this.local, required this.remote});

  final String local;
  final String remote;
}

class MergeOutcome {
  const MergeOutcome({required this.state, this.conflict});

  final EntryFieldState state;
  final TranscriptConflict? conflict;

  bool get hasConflict => conflict != null;
}

class SealedMediaChunk {
  const SealedMediaChunk({
    required this.blobId,
    required this.index,
    required this.ciphertext,
    required this.nonce,
  });

  final String blobId;
  final int index;
  final String ciphertext;
  final String nonce;
}

class PairTicket {
  const PairTicket({
    required this.id,
    required this.ciphertext,
    required this.nonce,
    required this.expiresAt,
  });

  final String id;
  final String ciphertext;
  final String nonce;
  final DateTime expiresAt;

  Map<String, Object> toJson() => {
    'id': id,
    'ciphertext': ciphertext,
    'nonce': nonce,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
  };
}

/// Per-entry XChaCha20-Poly1305 sync. The server stores [SealedSyncRecord] only.
abstract final class RecordSync {
  RecordSync._();

  static const keyVersion = 1;

  static Future<SealedSyncRecord> seal({
    required List<int> accountKey,
    required String recordId,
    required SyncRecordKind kind,
    required int version,
    required DateTime updatedAt,
    required String deviceId,
    required Map<String, Object> plaintext,
  }) async {
    final box = await Xchacha20.poly1305Aead().encrypt(
      utf8.encode(jsonEncode(plaintext)),
      secretKey: SecretKey(accountKey),
    );
    return SealedSyncRecord(
      recordId: recordId,
      kind: kind,
      version: version,
      updatedAt: updatedAt,
      deviceId: deviceId,
      ciphertext: _pack(box),
      nonce: base64Encode(box.nonce),
      keyVersion: keyVersion,
    );
  }

  static Future<Map<String, Object>> open({
    required List<int> accountKey,
    required SealedSyncRecord record,
  }) async {
    final packed = base64Decode(record.ciphertext);
    final clear = await Xchacha20.poly1305Aead().decrypt(
      SecretBox(
        packed.sublist(0, packed.length - 16),
        nonce: base64Decode(record.nonce),
        mac: Mac(packed.sublist(packed.length - 16)),
      ),
      secretKey: SecretKey(accountKey),
    );
    final decoded = jsonDecode(utf8.decode(clear));
    if (decoded is! Map) {
      throw const FormatException('Sync record was not an object.');
    }
    return Map<String, Object>.from(decoded);
  }

  static Future<SealedSyncRecord> sealEntry({
    required List<int> accountKey,
    required String recordId,
    required EntryFieldState state,
    required int version,
    required String deviceId,
  }) {
    final updated = [
      state.transcriptUpdatedAt,
      state.titleUpdatedAt,
      state.moodUpdatedAt,
      state.placeUpdatedAt,
      state.tagsUpdatedAt,
    ].reduce((a, b) => a.isAfter(b) ? a : b);
    return seal(
      accountKey: accountKey,
      recordId: recordId,
      kind: SyncRecordKind.entry,
      version: version,
      updatedAt: updated,
      deviceId: deviceId,
      plaintext: state.toJson(),
    );
  }

  static Future<EntryFieldState> openEntry({
    required List<int> accountKey,
    required SealedSyncRecord record,
  }) async {
    return EntryFieldState.fromJson(
      Map<String, dynamic>.from(await open(accountKey: accountKey, record: record)),
    );
  }

  static Future<SealedSyncRecord> tombstone({
    required List<int> accountKey,
    required String recordId,
    required DateTime deletedAt,
    required String deviceId,
    required int version,
  }) {
    return seal(
      accountKey: accountKey,
      recordId: recordId,
      kind: SyncRecordKind.tombstone,
      version: version,
      updatedAt: deletedAt,
      deviceId: deviceId,
      plaintext: {'deleted': true},
    );
  }

  /// Later field clock wins. Equal times break the tie on device id.
  static MergeOutcome merge(EntryFieldState local, EntryFieldState remote) {
    final title = _pick(
      local.title,
      local.titleUpdatedAt,
      local.titleDeviceId,
      remote.title,
      remote.titleUpdatedAt,
      remote.titleDeviceId,
    );
    final mood = _pick(
      local.mood,
      local.moodUpdatedAt,
      local.moodDeviceId,
      remote.mood,
      remote.moodUpdatedAt,
      remote.moodDeviceId,
    );
    final place = _pick(
      local.place,
      local.placeUpdatedAt,
      local.placeDeviceId,
      remote.place,
      remote.placeUpdatedAt,
      remote.placeDeviceId,
    );
    final tags = _pick(
      local.tags.join('\n'),
      local.tagsUpdatedAt,
      local.tagsDeviceId,
      remote.tags.join('\n'),
      remote.tagsUpdatedAt,
      remote.tagsDeviceId,
    );
    final localChanged = local.transcript != local.baseTranscript;
    final remoteChanged = remote.transcript != remote.baseTranscript;
    final diverged =
        localChanged &&
        remoteChanged &&
        local.transcript != remote.transcript;
    final transcript = diverged
        ? _pick(
            local.baseTranscript,
            local.transcriptUpdatedAt,
            local.transcriptDeviceId,
            remote.baseTranscript,
            remote.transcriptUpdatedAt,
            remote.transcriptDeviceId,
          )
        : _pick(
            local.transcript,
            local.transcriptUpdatedAt,
            local.transcriptDeviceId,
            remote.transcript,
            remote.transcriptUpdatedAt,
            remote.transcriptDeviceId,
          );
    return MergeOutcome(
      state: EntryFieldState(
        transcript: diverged ? local.baseTranscript : transcript.value,
        baseTranscript: diverged ? local.baseTranscript : transcript.value,
        transcriptUpdatedAt: transcript.updatedAt,
        transcriptDeviceId: transcript.deviceId,
        title: title.value,
        titleUpdatedAt: title.updatedAt,
        titleDeviceId: title.deviceId,
        mood: mood.value,
        moodUpdatedAt: mood.updatedAt,
        moodDeviceId: mood.deviceId,
        place: place.value,
        placeUpdatedAt: place.updatedAt,
        placeDeviceId: place.deviceId,
        tags: tags.value.isEmpty ? const [] : tags.value.split('\n'),
        tagsUpdatedAt: tags.updatedAt,
        tagsDeviceId: tags.deviceId,
        blobIds: {...local.blobIds, ...remote.blobIds}.toList(),
      ),
      conflict: diverged
          ? TranscriptConflict(local: local.transcript, remote: remote.transcript)
          : null,
    );
  }

  static EntryFieldState keepTranscript(EntryFieldState state, String chosen, DateTime now) {
    return state.copyWith(
      transcript: chosen,
      baseTranscript: chosen,
      transcriptUpdatedAt: now.toUtc(),
    );
  }

  static Map<String, EntryFieldState> apply({
    required Map<String, EntryFieldState> local,
    required List<({String id, SealedSyncRecord? tombstone, EntryFieldState? entry})> remote,
    required DateTime now,
  }) {
    final next = Map<String, EntryFieldState>.from(local);
    for (final row in remote) {
      final tombstone = row.tombstone;
      if (tombstone != null && tombstone.tombstoneActive(now)) {
        next.remove(row.id);
        continue;
      }
      final incoming = row.entry;
      if (incoming == null) continue;
      final current = next[row.id];
      next[row.id] = current == null ? incoming : merge(current, incoming).state;
    }
    return next;
  }

  static Future<List<SealedMediaChunk>> sealMedia({
    required List<int> accountKey,
    required List<int> bytes,
    required String blobPrefix,
  }) async {
    final chunks = <SealedMediaChunk>[];
    var index = 0;
    for (var start = 0; start < bytes.length; start += RecordSyncSchedule.mediaChunkBytes) {
      final end = start + RecordSyncSchedule.mediaChunkBytes;
      final slice = bytes.sublist(start, end > bytes.length ? bytes.length : end);
      final box = await Xchacha20.poly1305Aead().encrypt(
        slice,
        secretKey: SecretKey(accountKey),
      );
      chunks.add(
        SealedMediaChunk(
          blobId: '$blobPrefix-$index',
          index: index,
          ciphertext: _pack(box),
          nonce: base64Encode(box.nonce),
        ),
      );
      index += 1;
    }
    return chunks;
  }

  static Future<List<int>> openMedia({
    required List<int> accountKey,
    required List<SealedMediaChunk> chunks,
  }) async {
    final ordered = [...chunks]..sort((a, b) => a.index.compareTo(b.index));
    final out = <int>[];
    for (final chunk in ordered) {
      final packed = base64Decode(chunk.ciphertext);
      final clear = await Xchacha20.poly1305Aead().decrypt(
        SecretBox(
          packed.sublist(0, packed.length - 16),
          nonce: base64Decode(chunk.nonce),
          mac: Mac(packed.sublist(packed.length - 16)),
        ),
        secretKey: SecretKey(accountKey),
      );
      out.addAll(clear);
    }
    return out;
  }

  static Map<String, Object> pushBody(List<SealedSyncRecord> records) => {
    'records': [for (final record in records) record.toJson()],
  };

  static bool bodyContainsPlaintext(Map<String, Object> body, String transcript) {
    return jsonEncode(body).contains(transcript);
  }

  /// One-time key handoff. The relay body is ciphertext and an expiry.
  static Future<({PairTicket ticket, List<int> oneTimeKey})> issuePairTicket({
    required List<int> accountKey,
    required String id,
    required DateTime now,
    Random? random,
  }) async {
    final source = random ?? Random.secure();
    final oneTime = List<int>.generate(32, (_) => source.nextInt(256));
    final box = await Xchacha20.poly1305Aead().encrypt(
      accountKey,
      secretKey: SecretKey(oneTime),
    );
    return (
      ticket: PairTicket(
        id: id,
        ciphertext: _pack(box),
        nonce: base64Encode(box.nonce),
        expiresAt: now.toUtc().add(RecordSyncSchedule.pairExpiry),
      ),
      oneTimeKey: oneTime,
    );
  }

  static Future<List<int>> claimPairTicket({
    required PairTicket ticket,
    required List<int> oneTimeKey,
    required DateTime now,
  }) async {
    if (!now.toUtc().isBefore(ticket.expiresAt)) {
      throw StateError('This device link has expired.');
    }
    final packed = base64Decode(ticket.ciphertext);
    return Xchacha20.poly1305Aead().decrypt(
      SecretBox(
        packed.sublist(0, packed.length - 16),
        nonce: base64Decode(ticket.nonce),
        mac: Mac(packed.sublist(packed.length - 16)),
      ),
      secretKey: SecretKey(oneTimeKey),
    );
  }

  static _Picked _pick(
    String left,
    DateTime leftAt,
    String leftDevice,
    String right,
    DateTime rightAt,
    String rightDevice,
  ) {
    final compare = leftAt.compareTo(rightAt);
    if (compare > 0) {
      return _Picked(left, leftAt, leftDevice);
    }
    if (compare < 0) {
      return _Picked(right, rightAt, rightDevice);
    }
    if (leftDevice.compareTo(rightDevice) >= 0) {
      return _Picked(left, leftAt, leftDevice);
    }
    return _Picked(right, rightAt, rightDevice);
  }

  static String _pack(SecretBox box) =>
      base64Encode(<int>[...box.cipherText, ...box.mac.bytes]);
}

class _Picked {
  const _Picked(this.value, this.updatedAt, this.deviceId);

  final String value;
  final DateTime updatedAt;
  final String deviceId;
}

/// Keeps the account key for other iPhones on the same Apple ID.
abstract final class AccountKeyKeychain {
  AccountKeyKeychain._();

  static const channelName = 'archive_me/account_keychain';
  static const synchronizable = true;
}
