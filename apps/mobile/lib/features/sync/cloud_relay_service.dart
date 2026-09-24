import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/features/monetization/revenuecat_service.dart';
import 'package:archiveme_mobile/features/sync/secure_key_manager.dart';
import 'package:archiveme_mobile/sync/sync_crypto.dart';
import 'package:sqflite/sqflite.dart';

/// Ciphertext object stored in a cloud bucket. The device key never leaves
/// the phone; only this envelope is uploaded.
class CloudRelayEnvelope {
  const CloudRelayEnvelope({
    required this.recordingId,
    required this.payload,
  });

  final String recordingId;
  final EncryptedPayload payload;

  Map<String, dynamic> toJson() => {
    'recordingId': recordingId,
    'payload': payload.toJson(),
  };

  factory CloudRelayEnvelope.fromJson(Map<String, dynamic> json) {
    final raw = json['payload'];
    return CloudRelayEnvelope(
      recordingId: json['recordingId'] as String? ?? '',
      payload: EncryptedPayload.fromJson(
        raw is Map<String, dynamic> ? raw : const {},
      ),
    );
  }
}

/// Bucket that stores ciphertext only.
abstract class CloudRelayBucket {
  Future<void> put(CloudRelayEnvelope envelope);

  Future<List<CloudRelayEnvelope>> list();

  Future<void> remove(String recordingId);
}

/// In-process bucket used when no remote endpoint is configured.
class MemoryCloudRelayBucket implements CloudRelayBucket {
  final Map<String, CloudRelayEnvelope> _items = {};

  @override
  Future<void> put(CloudRelayEnvelope envelope) async {
    _items[envelope.recordingId] = envelope;
  }

  @override
  Future<List<CloudRelayEnvelope>> list() async => _items.values.toList();

  @override
  Future<void> remove(String recordingId) async {
    _items.remove(recordingId);
  }
}

class DecryptedRelayBlob {
  const DecryptedRelayBlob({
    required this.recordingId,
    required this.audioBytes,
    required this.transcript,
  });

  final String recordingId;
  final Uint8List audioBytes;
  final String transcript;
}

/// Encrypts a capture for cloud pickup when the secondary device is offline.
///
/// The mesh gate is off in this build, so a reachable peer is never assumed.
/// Callers pass peerObserved only after a real peer check; the default path
/// treats the secondary device as offline and uses this relay.
class CloudRelayService {
  CloudRelayService({
    required SyncCrypto crypto,
    CloudRelayBucket? bucket,
  }) : _crypto = crypto,
       _bucket = bucket ?? MemoryCloudRelayBucket();

  final SyncCrypto _crypto;
  final CloudRelayBucket _bucket;

  CloudRelayBucket get bucket => _bucket;

  /// Builds a relay whose AES-256-GCM key comes from the local secure store.
  static Future<CloudRelayService> withSecureKey({
    required SyncCryptoKeyStore keyStore,
    CloudRelayBucket? bucket,
  }) async {
    final keyBytes = await keyStore.ensureKey();
    return CloudRelayService(crypto: SyncCrypto(keyBytes), bucket: bucket);
  }

  /// First-boot key from [SecureKeyManager], then the same encrypt path.
  static Future<CloudRelayService> fromBootKey({
    SecureKeyManager? keys,
    CloudRelayBucket? bucket,
  }) {
    return withSecureKey(keyStore: keys ?? SecureKeyManager(), bucket: bucket);
  }

  /// True only when the mesh capability is enabled and a peer was observed.
  static bool secondaryDeviceOnline({required bool peerObserved}) =>
      V1CapabilityRegistry.p2pAndWebRtc && peerObserved;

  /// Encrypts and uploads when the secondary device is offline and premium
  /// continuity is active. Returns null when the peer is online or the
  /// free tier is in use.
  Future<CloudRelayEnvelope?> relayIfSecondaryOffline({
    required bool peerObserved,
    required String recordingId,
    required List<int> audioBytes,
    required String transcript,
  }) async {
    final secondaryOffline = !secondaryDeviceOnline(peerObserved: peerObserved);
    if (!FreeTierGate.allowsMultiDeviceSync(
      PremiumAccess.current,
      offline: secondaryOffline,
    )) {
      return null;
    }
    if (!secondaryOffline) return null;
    final payload = await _crypto.encryptJson({
      'audio': base64Encode(audioBytes),
      'transcript': transcript,
    });
    final envelope = CloudRelayEnvelope(
      recordingId: recordingId,
      payload: payload,
    );
    await _bucket.put(envelope);
    return envelope;
  }

  /// Downloads pending envelopes and decrypts them on this device.
  Future<List<DecryptedRelayBlob>> pullAndDecrypt() async {
    final pending = await _bucket.list();
    final decoded = <DecryptedRelayBlob>[];
    for (final envelope in pending) {
      final map = await _crypto.decryptJson(envelope.payload);
      final audio = map['audio'];
      final transcript = map['transcript'];
      if (audio is! String || transcript is! String) continue;
      decoded.add(
        DecryptedRelayBlob(
          recordingId: envelope.recordingId,
          audioBytes: Uint8List.fromList(base64Decode(audio)),
          transcript: transcript,
        ),
      );
      await _bucket.remove(envelope.recordingId);
    }
    return decoded;
  }
}

/// Polls the ciphertext bucket and writes decrypted captures into SQLite.
class CloudRelaySyncWorker {
  CloudRelaySyncWorker(
    this._relay, {
    this.inbox,
    this.interval = const Duration(minutes: 2),
  });

  final CloudRelayService _relay;
  final CloudRelayInbox? inbox;
  final Duration interval;
  Timer? _timer;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) {
      unawaited(pollOnce());
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<List<DecryptedRelayBlob>> pollOnce() async {
    final decoded = await _relay.pullAndDecrypt();
    final store = inbox;
    if (store != null) {
      for (final blob in decoded) {
        await store.save(blob);
      }
    }
    return decoded;
  }
}

/// Decrypted relay audio and transcript, stored only after local decrypt.
class CloudRelayInbox {
  CloudRelayInbox(this._db);

  final Database _db;
  var _ready = false;

  static const table = 'cloud_relay_inbox';

  Future<void> _ensure() async {
    if (_ready) return;
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        recording_id TEXT PRIMARY KEY NOT NULL,
        audio BLOB NOT NULL,
        transcript TEXT NOT NULL,
        received_at INTEGER NOT NULL
      )
    ''');
    _ready = true;
  }

  Future<void> save(DecryptedRelayBlob blob) async {
    await _ensure();
    await _db.insert(table, {
      'recording_id': blob.recordingId,
      'audio': blob.audioBytes,
      'transcript': blob.transcript,
      'received_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<DecryptedRelayBlob?> read(String recordingId) async {
    await _ensure();
    final rows = await _db.query(
      table,
      where: 'recording_id = ?',
      whereArgs: [recordingId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return DecryptedRelayBlob(
      recordingId: row['recording_id']! as String,
      audioBytes: row['audio']! as Uint8List,
      transcript: row['transcript']! as String,
    );
  }
}
