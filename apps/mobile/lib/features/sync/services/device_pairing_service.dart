import 'dart:convert';
import 'dart:math';

import 'package:archiveme_mobile/services/app_services.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the master key may be read after the phone unlocks.
enum MasterKeyKeychainScope {
  /// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Stays on this phone.
  thisDeviceOnly,

  /// Synced iCloud Keychain, available after the first unlock.
  iCloud,
}

/// Maps a scope onto the iOS Keychain flags Flutter secure storage writes.
IOSOptions iosOptionsForMasterKey(MasterKeyKeychainScope scope) {
  switch (scope) {
    case MasterKeyKeychainScope.thisDeviceOnly:
      return const IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
        synchronizable: false,
      );
    case MasterKeyKeychainScope.iCloud:
      return const IOSOptions(
        accessibility: KeychainAccessibility.first_unlock,
        synchronizable: true,
      );
  }
}

class PairingExpired implements Exception {
  const PairingExpired();
}

class PairingNotAuthentic implements Exception {
  const PairingNotAuthentic();
}

/// QR contents for a new phone: an ephemeral public key and a relay id.
class EphemeralPairingOffer {
  const EphemeralPairingOffer({
    required this.id,
    required this.payload,
    required this.expiresAt,
    required this.publicKey,
    required this.keyPair,
  });

  final String id;
  final String payload;
  final DateTime expiresAt;
  final List<int> publicKey;
  final SimpleKeyPair keyPair;
}

/// Stores the master key in Keychain and moves it through an ECDH relay.
class DevicePairingService {
  DevicePairingService({
    this.scope = MasterKeyKeychainScope.thisDeviceOnly,
    Future<void> Function(String key, String value)? write,
    Future<String?> Function(String key)? read,
    Random? random,
    this.postTransfer,
    this.fetchTransfer,
  }) : _write = write,
       _read = read,
       _random = random ?? Random.secure();

  static const storageKey = 'thoughtprint_master_key';
  static const pairingLifetime = Duration(minutes: 5);
  static const transferPath = '/api/sync/pair/transfer';
  static const _prefix = 'tp-pair:';

  final MasterKeyKeychainScope scope;
  final Future<void> Function(String key, String value)? _write;
  final Future<String?> Function(String key)? _read;
  final Random _random;
  final Future<void> Function(Map<String, Object> body)? postTransfer;
  final Future<Map<String, Object?>?> Function(String id)? fetchTransfer;

  IOSOptions get iosOptions => iosOptionsForMasterKey(scope);

  Future<void> saveMasterKey({
    required List<int> masterKey,
    required List<int> salt,
  }) async {
    final encoded = jsonEncode({
      'masterKey': base64Encode(masterKey),
      'salt': base64Encode(salt),
    });
    final write = _write;
    if (write != null) {
      await write(storageKey, encoded);
      return;
    }
    final box = FlutterSecureStorage(iOptions: iosOptions);
    await box.write(key: storageKey, value: encoded);
  }

  Future<({List<int> masterKey, List<int> salt})?> readMasterKey() async {
    final read = _read;
    final raw = read != null
        ? await read(storageKey)
        : await FlutterSecureStorage(
            iOptions: iosOptions,
          ).read(key: storageKey);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return (
      masterKey: base64Decode(decoded['masterKey'] as String),
      salt: base64Decode(decoded['salt'] as String),
    );
  }

  /// New phone: the QR holds an X25519 public key, not the account key.
  Future<EphemeralPairingOffer> createPairingOffer({DateTime? now}) async {
    final issued = (now ?? DateTime.now()).toUtc();
    final expires = issued.add(pairingLifetime);
    final algorithm = X25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final id = base64Url.encode(
      List<int>.generate(16, (_) => _random.nextInt(256)),
    );
    final body = jsonEncode({
      'v': 2,
      'id': id,
      'exp': expires.millisecondsSinceEpoch,
      'publicKey': base64Encode(publicKey.bytes),
    });
    return EphemeralPairingOffer(
      id: id,
      payload: '$_prefix${base64Url.encode(utf8.encode(body))}',
      expiresAt: expires,
      publicKey: publicKey.bytes,
      keyPair: keyPair,
    );
  }

  /// Existing phone: seal the account key to the scanned public key and post it.
  Future<void> sendAccountKey({
    required String scannedPayload,
    required List<int> accountKey,
    required List<int> salt,
    DateTime? now,
  }) async {
    final offer = _readOffer(scannedPayload, now: now ?? DateTime.now());
    final algorithm = X25519();
    final keyPair = await algorithm.newKeyPair();
    final senderPublic = await keyPair.extractPublicKey();
    final secret = await _sharedSecret(
      keyPair: keyPair,
      remotePublicKey: offer.publicKey,
    );
    final clear = utf8.encode(
      jsonEncode({
        'accountKey': base64Encode(accountKey),
        'salt': base64Encode(salt),
        'publicKey': base64Encode(offer.publicKey),
      }),
    );
    final box = await Xchacha20.poly1305Aead().encrypt(
      clear,
      secretKey: SecretKey(secret),
    );
    final body = <String, Object>{
      'id': offer.id,
      'ciphertext': base64Encode(<int>[...box.cipherText, ...box.mac.bytes]),
      'nonce': base64Encode(box.nonce),
      'senderPublicKey': base64Encode(senderPublic.bytes),
    };
    final post = postTransfer ?? _postTransfer;
    await post(body);
  }

  /// New phone: pull the relay payload and open it with the ephemeral key.
  Future<({List<int> masterKey, List<int> salt})> finishPairing({
    required EphemeralPairingOffer offer,
    DateTime? now,
  }) async {
    final current = now ?? DateTime.now();
    if (!current.toUtc().isBefore(offer.expiresAt)) {
      throw const PairingExpired();
    }
    final fetch = fetchTransfer ?? _fetchTransfer;
    final remote = await fetch(offer.id);
    if (remote == null) throw const PairingNotAuthentic();
    final senderPublic = remote['senderPublicKey'];
    final ciphertext = remote['ciphertext'];
    final nonce = remote['nonce'];
    if (senderPublic is! String || ciphertext is! String || nonce is! String) {
      throw const PairingNotAuthentic();
    }
    final secret = await _sharedSecret(
      keyPair: offer.keyPair,
      remotePublicKey: base64Decode(senderPublic),
    );
    final List<int> clear;
    try {
      final packed = base64Decode(ciphertext);
      if (packed.length < 16) throw const PairingNotAuthentic();
      clear = await Xchacha20.poly1305Aead().decrypt(
        SecretBox(
          packed.sublist(0, packed.length - 16),
          nonce: base64Decode(nonce),
          mac: Mac(packed.sublist(packed.length - 16)),
        ),
        secretKey: SecretKey(secret),
      );
    } on SecretBoxAuthenticationError {
      throw const PairingNotAuthentic();
    }
    final decoded = jsonDecode(utf8.decode(clear));
    if (decoded is! Map) throw const PairingNotAuthentic();
    if (decoded['publicKey'] != base64Encode(offer.publicKey)) {
      throw const PairingNotAuthentic();
    }
    final masterKey = base64Decode(decoded['accountKey'] as String);
    final salt = base64Decode(decoded['salt'] as String);
    await saveMasterKey(masterKey: masterKey, salt: salt);
    return (masterKey: masterKey, salt: salt);
  }

  Future<List<int>> _sharedSecret({
    required SimpleKeyPair keyPair,
    required List<int> remotePublicKey,
  }) async {
    final shared = await X25519().sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey: SimplePublicKey(
        remotePublicKey,
        type: KeyPairType.x25519,
      ),
    );
    return shared.extractBytes();
  }

  _ScannedOffer _readOffer(String payload, {required DateTime now}) {
    final trimmed = payload.trim();
    if (!trimmed.startsWith(_prefix)) {
      throw const FormatException('Pairing code was not recognized.');
    }
    final decoded = jsonDecode(
      utf8.decode(base64Url.decode(trimmed.substring(_prefix.length))),
    );
    if (decoded is! Map || decoded['v'] != 2) {
      throw const FormatException('Pairing code was not recognized.');
    }
    if (decoded['wrap'] != null || decoded['masterKey'] != null) {
      throw const FormatException('Pairing code was not recognized.');
    }
    final expires = DateTime.fromMillisecondsSinceEpoch(
      decoded['exp'] as int,
      isUtc: true,
    );
    if (!now.toUtc().isBefore(expires)) throw const PairingExpired();
    final publicKey = decoded['publicKey'];
    final id = decoded['id'];
    if (publicKey is! String || id is! String || id.isEmpty) {
      throw const FormatException('Pairing code was not recognized.');
    }
    return _ScannedOffer(
      id: id,
      publicKey: base64Decode(publicKey),
      expiresAt: expires,
    );
  }

  Future<void> _postTransfer(Map<String, Object> body) async {
    if (!AppServices.isInitialized) {
      throw StateError('Pairing transfer needs a signed-in session.');
    }
    final result = await AppServices.instance.httpTransport.post(
      transferPath,
      body: body,
    );
    final response = result.valueOrNull;
    if (response == null || response.statusCode != 200) {
      throw StateError('Pairing transfer was not accepted.');
    }
  }

  Future<Map<String, Object?>?> _fetchTransfer(String id) async {
    if (!AppServices.isInitialized) return null;
    final result = await AppServices.instance.httpTransport.get(
      transferPath,
      queryParameters: {'id': id},
    );
    final response = result.valueOrNull;
    if (response == null || response.statusCode != 200) return null;
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return null;
    return Map<String, Object?>.from(decoded);
  }
}

class _ScannedOffer {
  const _ScannedOffer({
    required this.id,
    required this.publicKey,
    required this.expiresAt,
  });

  final String id;
  final List<int> publicKey;
  final DateTime expiresAt;
}
