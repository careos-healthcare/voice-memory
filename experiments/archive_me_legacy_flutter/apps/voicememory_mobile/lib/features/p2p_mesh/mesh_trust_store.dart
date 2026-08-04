import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../../storage/encrypted_json_file_store.dart';

class TrustedMeshPeer {
  TrustedMeshPeer({
    required this.deviceId,
    required this.displayName,
    required this.fingerprint,
    required List<int> identityPublicKey,
    required DateTime pairedAt,
  }) : identityPublicKey = Uint8List.fromList(identityPublicKey),
       pairedAt = pairedAt.toUtc();

  final String deviceId;
  final String displayName;
  final String fingerprint;
  final Uint8List identityPublicKey;
  final DateTime pairedAt;

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'displayName': displayName,
    'fingerprint': fingerprint,
    'identityPublicKey': base64UrlEncode(identityPublicKey),
    'pairedAt': pairedAt.toIso8601String(),
  };

  factory TrustedMeshPeer.fromJson(Map<String, dynamic> json) {
    final pairedAt = DateTime.tryParse('${json['pairedAt']}');
    final key = base64Url.decode('${json['identityPublicKey']}');
    if (json['deviceId'] is! String ||
        (json['deviceId'] as String).isEmpty ||
        json['displayName'] is! String ||
        json['fingerprint'] is! String ||
        (json['fingerprint'] as String).isEmpty ||
        key.length != 32 ||
        pairedAt == null) {
      throw const FormatException('Invalid trusted mesh peer.');
    }
    return TrustedMeshPeer(
      deviceId: json['deviceId'] as String,
      displayName: json['displayName'] as String,
      fingerprint: json['fingerprint'] as String,
      identityPublicKey: key,
      pairedAt: pairedAt,
    );
  }
}

class MeshTrustStore {
  MeshTrustStore(this._storage);

  final EncryptedJsonFileStore _storage;
  final _changes = StreamController<List<TrustedMeshPeer>>.broadcast();
  Future<void> _tail = Future.value();

  Stream<List<TrustedMeshPeer>> get changes => _changes.stream;

  Future<List<TrustedMeshPeer>> list() => _serialize(_read);

  Future<TrustedMeshPeer?> find(String deviceId) async {
    final peers = await list();
    return peers.where((peer) => peer.deviceId == deviceId).firstOrNull;
  }

  Future<void> trust(TrustedMeshPeer peer) => _serialize(() async {
    final peers = await _read();
    final existing = peers.where((item) => item.deviceId == peer.deviceId);
    if (existing.isNotEmpty && existing.first.fingerprint != peer.fingerprint) {
      throw StateError('A trusted device cannot silently change identity.');
    }
    final updated = [
      for (final item in peers)
        if (item.deviceId != peer.deviceId) item,
      peer,
    ]..sort((left, right) => left.deviceId.compareTo(right.deviceId));
    await _write(updated);
  });

  Future<void> revoke(String deviceId) => _serialize(() async {
    final peers = await _read();
    final updated = peers
        .where((peer) => peer.deviceId != deviceId)
        .toList(growable: false);
    await _write(updated);
  });

  Future<List<TrustedMeshPeer>> _read() async {
    final raw = await _storage.readJson();
    if (raw == null) return const [];
    if (raw is! Map || raw['version'] != 1 || raw['peers'] is! List) {
      throw const FormatException('Invalid trusted mesh peer store.');
    }
    return List.unmodifiable(
      (raw['peers'] as List).map((item) {
        if (item is! Map) throw const FormatException('Invalid mesh peer.');
        return TrustedMeshPeer.fromJson(Map<String, dynamic>.from(item));
      }),
    );
  }

  Future<void> _write(List<TrustedMeshPeer> peers) async {
    await _storage.writeJson({
      'version': 1,
      'peers': peers.map((peer) => peer.toJson()).toList(growable: false),
    });
    _changes.add(List.unmodifiable(peers));
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    _tail = _tail.catchError((Object _) {}).then((_) async {
      try {
        result.complete(await operation());
      } on Object catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  Future<void> dispose() => _changes.close();
}
