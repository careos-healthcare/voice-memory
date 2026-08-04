import 'dart:convert';
import 'dart:typed_data';

enum MeshHandshakeRole { initiator, responder }

class MeshPeer {
  MeshPeer({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.identityFingerprint,
    this.protocolVersion = 1,
  }) {
    if (id.isEmpty ||
        name.isEmpty ||
        host.isEmpty ||
        port < 1 ||
        port > 65535) {
      throw ArgumentError('Invalid mesh peer.');
    }
  }

  final String id;
  final String name;
  final String host;
  final int port;
  final String identityFingerprint;
  final int protocolVersion;
}

enum MeshPeerEventKind { found, lost }

class MeshPeerEvent {
  const MeshPeerEvent({required this.kind, required this.peer});

  final MeshPeerEventKind kind;
  final MeshPeer peer;
}

class MeshHandshakeParty {
  MeshHandshakeParty({
    required this.deviceId,
    required List<int> identityPublicKey,
    required List<int> ephemeralPublicKey,
    required List<int> nonce,
  }) : identityPublicKey = Uint8List.fromList(identityPublicKey),
       ephemeralPublicKey = Uint8List.fromList(ephemeralPublicKey),
       nonce = Uint8List.fromList(nonce) {
    if (deviceId.isEmpty) throw ArgumentError.value(deviceId, 'deviceId');
    if (this.identityPublicKey.length != 32 ||
        this.ephemeralPublicKey.length != 32 ||
        this.nonce.length != 32) {
      throw ArgumentError('Mesh handshake keys and nonce must be 32 bytes.');
    }
  }

  final String deviceId;
  final Uint8List identityPublicKey;
  final Uint8List ephemeralPublicKey;
  final Uint8List nonce;

  Map<String, Object> toJson() => {
    'deviceId': deviceId,
    'identityKey': base64UrlEncode(identityPublicKey),
    'ephemeralKey': base64UrlEncode(ephemeralPublicKey),
    'nonce': base64UrlEncode(nonce),
  };

  factory MeshHandshakeParty.fromJson(Map<String, dynamic> json) {
    return MeshHandshakeParty(
      deviceId: _requiredString(json, 'deviceId'),
      identityPublicKey: _decode32(json, 'identityKey'),
      ephemeralPublicKey: _decode32(json, 'ephemeralKey'),
      nonce: _decode32(json, 'nonce'),
    );
  }
}

class MeshHandshakeTranscript {
  MeshHandshakeTranscript({
    required this.initiator,
    required this.responder,
    List<int>? initiatorSignature,
    List<int>? responderSignature,
    this.protocolVersion = 1,
  }) : initiatorSignature = initiatorSignature == null
           ? null
           : Uint8List.fromList(initiatorSignature),
       responderSignature = responderSignature == null
           ? null
           : Uint8List.fromList(responderSignature) {
    if (protocolVersion != 1) {
      throw ArgumentError.value(protocolVersion, 'protocolVersion');
    }
    if (this.initiatorSignature case final signature?) {
      if (signature.length != 64) {
        throw ArgumentError('Ed25519 signatures must be 64 bytes.');
      }
    }
    if (this.responderSignature case final signature?) {
      if (signature.length != 64) {
        throw ArgumentError('Ed25519 signatures must be 64 bytes.');
      }
    }
  }

  final int protocolVersion;
  final MeshHandshakeParty initiator;
  final MeshHandshakeParty responder;
  final Uint8List? initiatorSignature;
  final Uint8List? responderSignature;

  Uint8List get signingBytes => Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'domain': 'ArchiveMe.Mesh.Handshake.v1',
        'version': protocolVersion,
        'initiator': initiator.toJson(),
        'responder': responder.toJson(),
      }),
    ),
  );

  MeshHandshakeTranscript copyWith({
    List<int>? initiatorSignature,
    List<int>? responderSignature,
  }) {
    return MeshHandshakeTranscript(
      initiator: initiator,
      responder: responder,
      protocolVersion: protocolVersion,
      initiatorSignature: initiatorSignature ?? this.initiatorSignature,
      responderSignature: responderSignature ?? this.responderSignature,
    );
  }

  Map<String, Object?> toJson() => {
    'version': protocolVersion,
    'initiator': initiator.toJson(),
    'responder': responder.toJson(),
    if (initiatorSignature != null)
      'initiatorSignature': base64UrlEncode(initiatorSignature!),
    if (responderSignature != null)
      'responderSignature': base64UrlEncode(responderSignature!),
  };

  factory MeshHandshakeTranscript.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    if (version is! num || version.toInt() != 1) {
      throw const FormatException('Unsupported mesh handshake version.');
    }
    return MeshHandshakeTranscript(
      protocolVersion: version.toInt(),
      initiator: MeshHandshakeParty.fromJson(_requiredMap(json, 'initiator')),
      responder: MeshHandshakeParty.fromJson(_requiredMap(json, 'responder')),
      initiatorSignature: _optionalBytes(json, 'initiatorSignature'),
      responderSignature: _optionalBytes(json, 'responderSignature'),
    );
  }
}

class MeshSessionKeys {
  MeshSessionKeys({
    required List<int> sendKey,
    required List<int> receiveKey,
    required List<int> sendNoncePrefix,
    required List<int> receiveNoncePrefix,
    required this.sas,
  }) : sendKey = Uint8List.fromList(sendKey),
       receiveKey = Uint8List.fromList(receiveKey),
       sendNoncePrefix = Uint8List.fromList(sendNoncePrefix),
       receiveNoncePrefix = Uint8List.fromList(receiveNoncePrefix) {
    if (this.sendKey.length != 32 || this.receiveKey.length != 32) {
      throw ArgumentError('Mesh session keys must be 32 bytes.');
    }
    if (this.sendNoncePrefix.length != 4 ||
        this.receiveNoncePrefix.length != 4) {
      throw ArgumentError('Mesh nonce prefixes must be 4 bytes.');
    }
    if (!RegExp(r'^\d{6}$').hasMatch(sas)) {
      throw ArgumentError.value(sas, 'sas', 'Expected six digits.');
    }
  }

  final Uint8List sendKey;
  final Uint8List receiveKey;
  final Uint8List sendNoncePrefix;
  final Uint8List receiveNoncePrefix;
  final String sas;

  void destroy() {
    sendKey.fillRange(0, sendKey.length, 0);
    receiveKey.fillRange(0, receiveKey.length, 0);
    sendNoncePrefix.fillRange(0, sendNoncePrefix.length, 0);
    receiveNoncePrefix.fillRange(0, receiveNoncePrefix.length, 0);
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing $key.');
  }
  return value;
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map) throw FormatException('Missing $key.');
  return Map<String, dynamic>.from(value);
}

Uint8List _decode32(Map<String, dynamic> json, String key) {
  final bytes = _optionalBytes(json, key);
  if (bytes == null || bytes.length != 32) {
    throw FormatException('$key must contain 32 bytes.');
  }
  return bytes;
}

Uint8List? _optionalBytes(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('Invalid $key.');
  try {
    return Uint8List.fromList(base64Url.decode(value));
  } on FormatException {
    throw FormatException('Invalid $key.');
  }
}
