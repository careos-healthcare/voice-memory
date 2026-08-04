import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import '../../services/security/mesh_identity_service.dart';
import 'mesh_discovery.dart';
import 'mesh_frame_protocol.dart';
import 'mesh_models.dart';
import 'sync/peer_sync_channel.dart';

class MeshPairingInvitation {
  MeshPairingInvitation({
    required this.serviceId,
    required this.identityFingerprint,
    required List<int> oneTimeNonce,
    required DateTime expiresAt,
  }) : oneTimeNonce = Uint8List.fromList(oneTimeNonce),
       expiresAt = expiresAt.toUtc() {
    if (serviceId.isEmpty ||
        identityFingerprint.isEmpty ||
        this.oneTimeNonce.length != 32) {
      throw ArgumentError('Invalid mesh pairing invitation.');
    }
  }

  final String serviceId;
  final String identityFingerprint;
  final Uint8List oneTimeNonce;
  final DateTime expiresAt;

  String encode() => jsonEncode({
    'version': 1,
    'serviceId': serviceId,
    'identityFingerprint': identityFingerprint,
    'oneTimeNonce': base64UrlEncode(oneTimeNonce),
    'expiresAt': expiresAt.toIso8601String(),
  });

  factory MeshPairingInvitation.decode(String value, {DateTime? now}) {
    final raw = jsonDecode(value);
    if (raw is! Map || raw['version'] != 1) {
      throw const FormatException('Invalid mesh pairing invitation.');
    }
    if (raw['serviceId'] is! String ||
        raw['identityFingerprint'] is! String ||
        raw['oneTimeNonce'] is! String ||
        raw['expiresAt'] is! String) {
      throw const FormatException('Invalid mesh pairing invitation.');
    }
    final nonce = base64Url.decode('${raw['oneTimeNonce']}');
    final expiresAt = DateTime.tryParse('${raw['expiresAt']}');
    final invitation = MeshPairingInvitation(
      serviceId: raw['serviceId'] as String,
      identityFingerprint: raw['identityFingerprint'] as String,
      oneTimeNonce: nonce,
      expiresAt:
          expiresAt ??
          (throw const FormatException('Invalid pairing expiration.')),
    );
    if (!invitation.expiresAt.isAfter((now ?? DateTime.now()).toUtc())) {
      throw const FormatException('Mesh pairing invitation has expired.');
    }
    return invitation;
  }
}

class MeshPendingSession {
  MeshPendingSession._({
    required this.session,
    required this.transcript,
    required this.remoteFingerprint,
  });

  final MeshSecureSession session;
  final MeshHandshakeTranscript transcript;
  final String remoteFingerprint;

  String get sas => session.sas;
  String get remoteDeviceId => session.peerId;

  Future<void> confirm({Duration timeout = const Duration(seconds: 30)}) =>
      session.confirmPairing(timeout: timeout);
}

class MeshSecureSession implements AuthenticatedPeerSyncChannel {
  MeshSecureSession._({
    required this.peerId,
    required this.sas,
    required this._wire,
    required this._cipher,
  }) {
    _wireSubscription = _wire.packetStream.listen(
      (packet) {
        _decryptTail = _decryptTail.then((_) => _decrypt(packet));
      },
      onError: _packets.addError,
      onDone: _packets.close,
    );
  }

  @override
  final String peerId;
  final String sas;
  final _PacketWire _wire;
  final MeshFrameCipher _cipher;
  final _packets = StreamController<Map<String, dynamic>>.broadcast();
  late final StreamSubscription<Uint8List> _wireSubscription;
  Future<void> _decryptTail = Future.value();
  bool _confirmed = false;
  bool _closed = false;
  bool get isPairingConfirmed => _confirmed;

  @override
  Stream<Map<String, dynamic>> get packets => _packets.stream;

  @override
  Future<void> send(Map<String, dynamic> packet) async {
    if (_closed) throw StateError('Mesh session is closed.');
    final cleartext = Uint8List.fromList(utf8.encode(jsonEncode(packet)));
    try {
      final encrypted = await _cipher.encrypt(type: 1, payload: cleartext);
      _wire.sendPacket(encrypted);
    } finally {
      cleartext.fillRange(0, cleartext.length, 0);
    }
  }

  Future<void> confirmPairing({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (_confirmed) return;
    final remoteConfirmation = packets.firstWhere(
      (packet) => packet['type'] == 'pair_confirm',
    );
    await send(const {'version': 1, 'type': 'pair_confirm'});
    await remoteConfirmation.timeout(timeout);
    _confirmed = true;
  }

  Future<void> _decrypt(Uint8List packet) async {
    if (_closed) return;
    MeshFrame? frame;
    try {
      frame = await _cipher.decrypt(packet);
      if (frame.type != 1) {
        throw const MeshProtocolException('Unsupported secure frame type.');
      }
      final decoded = jsonDecode(utf8.decode(frame.payload));
      if (decoded is! Map) {
        throw const MeshProtocolException('Invalid secure mesh payload.');
      }
      _packets.add(Map<String, dynamic>.from(decoded));
    } on Object catch (error, stackTrace) {
      _packets.addError(error, stackTrace);
      unawaited(close());
    } finally {
      frame?.payload.fillRange(0, frame.payload.length, 0);
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _wire.close();
    await _wireSubscription.cancel();
    _cipher.destroy();
    await _packets.close();
  }
}

class MeshHandshake {
  const MeshHandshake._();

  static Future<MeshPendingSession> initiate({
    required MeshConnection connection,
    required MeshIdentityService identity,
    MeshPairingInvitation? invitation,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final wire = _PacketWire(connection);
    final local = await identity.createHandshakeParty();
    try {
      wire.sendJson({'type': 'hello', 'party': local.party.toJson()});
      final hello = await wire.nextJson().timeout(timeout);
      _requireType(hello, 'hello');
      final remote = MeshHandshakeParty.fromJson(_requiredMap(hello, 'party'));
      if (invitation != null) {
        if (!_constantTimeEquals(remote.nonce, invitation.oneTimeNonce)) {
          throw const MeshProtocolException(
            'Pairing invitation nonce does not match.',
          );
        }
        final fingerprint = await identity.fingerprintForPublicKey(
          remote.identityPublicKey,
        );
        if (fingerprint != invitation.identityFingerprint) {
          throw const MeshProtocolException(
            'Pairing invitation identity does not match.',
          );
        }
      }
      var transcript = MeshHandshakeTranscript(
        initiator: local.party,
        responder: remote,
      );
      transcript = await identity.signTranscript(
        transcript,
        role: MeshHandshakeRole.initiator,
      );
      wire.sendJson({'type': 'transcript', 'value': transcript.toJson()});
      final response = await wire.nextJson().timeout(timeout);
      _requireType(response, 'transcript');
      final completed = MeshHandshakeTranscript.fromJson(
        _requiredMap(response, 'value'),
      );
      if (!_sameParties(transcript, completed) ||
          !await identity.verifyTranscript(completed)) {
        throw const MeshProtocolException(
          'Mesh handshake transcript verification failed.',
        );
      }
      final keys = await identity.establishSession(
        transcript: completed,
        role: MeshHandshakeRole.initiator,
        localEphemeral: local,
      );
      return _pending(
        identity: identity,
        transcript: completed,
        role: MeshHandshakeRole.initiator,
        wire: wire,
        keys: keys,
      );
    } on Object {
      await wire.close();
      rethrow;
    } finally {
      local.destroy();
    }
  }

  static Future<MeshPendingSession> respond({
    required MeshConnection connection,
    required MeshIdentityService identity,
    List<int>? invitationNonce,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final wire = _PacketWire(connection);
    final local = await identity.createHandshakeParty(nonce: invitationNonce);
    try {
      final hello = await wire.nextJson().timeout(timeout);
      _requireType(hello, 'hello');
      final remote = MeshHandshakeParty.fromJson(_requiredMap(hello, 'party'));
      wire.sendJson({'type': 'hello', 'party': local.party.toJson()});
      final request = await wire.nextJson().timeout(timeout);
      _requireType(request, 'transcript');
      final requested = MeshHandshakeTranscript.fromJson(
        _requiredMap(request, 'value'),
      );
      if (!_sameParty(requested.initiator, remote) ||
          !_sameParty(requested.responder, local.party)) {
        throw const MeshProtocolException('Mesh handshake party mismatch.');
      }
      final completed = await identity.signTranscript(
        requested,
        role: MeshHandshakeRole.responder,
      );
      if (!await identity.verifyTranscript(completed)) {
        throw const MeshProtocolException(
          'Mesh handshake transcript verification failed.',
        );
      }
      wire.sendJson({'type': 'transcript', 'value': completed.toJson()});
      final keys = await identity.establishSession(
        transcript: completed,
        role: MeshHandshakeRole.responder,
        localEphemeral: local,
      );
      return _pending(
        identity: identity,
        transcript: completed,
        role: MeshHandshakeRole.responder,
        wire: wire,
        keys: keys,
      );
    } on Object {
      await wire.close();
      rethrow;
    } finally {
      local.destroy();
    }
  }

  static Future<MeshPendingSession> _pending({
    required MeshIdentityService identity,
    required MeshHandshakeTranscript transcript,
    required MeshHandshakeRole role,
    required _PacketWire wire,
    required MeshSessionKeys keys,
  }) async {
    final remote = role == MeshHandshakeRole.initiator
        ? transcript.responder
        : transcript.initiator;
    final session = MeshSecureSession._(
      peerId: remote.deviceId,
      sas: keys.sas,
      wire: wire,
      cipher: MeshFrameCipher(keys: keys),
    );
    keys.destroy();
    return MeshPendingSession._(
      session: session,
      transcript: transcript,
      remoteFingerprint: await identity.fingerprintForPublicKey(
        remote.identityPublicKey,
      ),
    );
  }

  static void _requireType(Map<String, dynamic> json, String type) {
    if (json['type'] != type) {
      throw MeshProtocolException('Expected mesh handshake message $type.');
    }
  }

  static Map<String, dynamic> _requiredMap(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    if (value is! Map) throw MeshProtocolException('Missing $key.');
    return Map<String, dynamic>.from(value);
  }

  static bool _sameParties(
    MeshHandshakeTranscript left,
    MeshHandshakeTranscript right,
  ) =>
      _sameParty(left.initiator, right.initiator) &&
      _sameParty(left.responder, right.responder);

  static bool _sameParty(MeshHandshakeParty left, MeshHandshakeParty right) =>
      left.deviceId == right.deviceId &&
      _constantTimeEquals(left.identityPublicKey, right.identityPublicKey) &&
      _constantTimeEquals(left.ephemeralPublicKey, right.ephemeralPublicKey) &&
      _constantTimeEquals(left.nonce, right.nonce);

  static bool _constantTimeEquals(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left[index] ^ right[index];
    }
    return difference == 0;
  }
}

class _PacketWire {
  _PacketWire(this._connection) {
    _subscription = _connection.bytes.listen(
      _addBytes,
      onError: _fail,
      onDone: () => _fail(const MeshProtocolException('Connection closed.')),
    );
  }

  static const _maxPacketBytes = 1024 * 1024 + 64;
  final MeshConnection _connection;
  final List<int> _buffer = [];
  final Queue<Uint8List> _packets = Queue();
  final Queue<Completer<Uint8List>> _waiters = Queue();
  late final StreamSubscription<List<int>> _subscription;
  bool _closed = false;

  Stream<Uint8List> get packetStream async* {
    while (!_closed) {
      yield await nextPacket();
    }
  }

  void sendJson(Map<String, dynamic> value) =>
      sendPacket(utf8.encode(jsonEncode(value)));

  Future<Map<String, dynamic>> nextJson() async {
    final packet = await nextPacket();
    final decoded = jsonDecode(utf8.decode(packet));
    if (decoded is! Map) {
      throw const MeshProtocolException('Invalid handshake payload.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<Uint8List> nextPacket() {
    if (_packets.isNotEmpty) return Future.value(_packets.removeFirst());
    if (_closed) {
      return Future.error(const MeshProtocolException('Connection closed.'));
    }
    final waiter = Completer<Uint8List>();
    _waiters.add(waiter);
    return waiter.future;
  }

  void sendPacket(List<int> packet) {
    if (_closed || packet.length > _maxPacketBytes) {
      throw const MeshProtocolException('Invalid mesh packet.');
    }
    final framed = Uint8List(4 + packet.length);
    ByteData.sublistView(framed).setUint32(0, packet.length);
    framed.setRange(4, framed.length, packet);
    _connection.send(framed);
  }

  void _addBytes(List<int> bytes) {
    if (_closed) return;
    _buffer.addAll(bytes);
    if (_buffer.length > _maxPacketBytes * 2) {
      _fail(const MeshProtocolException('Mesh wire buffer exceeded.'));
      return;
    }
    while (_buffer.length >= 4) {
      final length = ByteData.sublistView(
        Uint8List.fromList(_buffer.sublist(0, 4)),
      ).getUint32(0);
      if (length < 1 || length > _maxPacketBytes) {
        _fail(const MeshProtocolException('Invalid mesh packet length.'));
        return;
      }
      if (_buffer.length < length + 4) return;
      final packet = Uint8List.fromList(_buffer.sublist(4, length + 4));
      _buffer.removeRange(0, length + 4);
      if (_waiters.isNotEmpty) {
        _waiters.removeFirst().complete(packet);
      } else {
        _packets.add(packet);
      }
    }
  }

  void _fail(Object error, [StackTrace? stackTrace]) {
    if (_closed) return;
    _closed = true;
    while (_waiters.isNotEmpty) {
      _waiters.removeFirst().completeError(error, stackTrace);
    }
  }

  Future<void> close() async {
    if (!_closed) {
      _closed = true;
      while (_waiters.isNotEmpty) {
        _waiters.removeFirst().completeError(
          const MeshProtocolException('Connection closed.'),
        );
      }
    }
    await _subscription.cancel();
    await _connection.close();
  }
}
