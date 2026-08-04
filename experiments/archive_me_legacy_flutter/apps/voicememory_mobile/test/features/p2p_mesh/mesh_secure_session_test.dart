import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/p2p_mesh/mesh_discovery.dart';
import 'package:voicememory_mobile/features/p2p_mesh/mesh_secure_session.dart';
import 'package:voicememory_mobile/services/security/mesh_identity_service.dart';
import 'package:voicememory_mobile/services/security/sync_identity_service.dart';

void main() {
  test('pairing invitation is one-time scoped and rejects expiry', () {
    final invitation = MeshPairingInvitation(
      serviceId: 'rotating-service',
      identityFingerprint: 'fingerprint',
      oneTimeNonce: Uint8List(32),
      expiresAt: DateTime.utc(2026, 7, 27, 12, 2),
    );
    expect(
      MeshPairingInvitation.decode(
        invitation.encode(),
        now: DateTime.utc(2026, 7, 27, 12),
      ).serviceId,
      'rotating-service',
    );
    expect(
      () => MeshPairingInvitation.decode(
        invitation.encode(),
        now: DateTime.utc(2026, 7, 27, 12, 3),
      ),
      throwsFormatException,
    );
  });

  test(
    'handshake confirms SAS and carries authenticated encrypted packets',
    () async {
      final pair = _MemoryConnection.pair();
      final initiatorIdentity = MeshIdentityService(
        store: MemorySyncIdentityStore(),
        random: Random(11),
        deviceIdProvider: () async => 'device-a',
      );
      final responderIdentity = MeshIdentityService(
        store: MemorySyncIdentityStore(),
        random: Random(22),
        deviceIdProvider: () async => 'device-b',
      );
      final responderFuture = MeshHandshake.respond(
        connection: pair.$2,
        identity: responderIdentity,
      );
      final initiator = await MeshHandshake.initiate(
        connection: pair.$1,
        identity: initiatorIdentity,
      );
      final responder = await responderFuture;

      expect(initiator.sas, responder.sas);
      expect(initiator.remoteDeviceId, 'device-b');
      await Future.wait([initiator.confirm(), responder.confirm()]);
      expect(initiator.session.isPairingConfirmed, isTrue);
      expect(responder.session.isPairingConfirmed, isTrue);

      final received = responder.session.packets.first;
      await initiator.session.send(const {'type': 'proof', 'value': 42});
      expect(await received, containsPair('value', 42));

      await initiator.session.close();
      await responder.session.close();
    },
  );

  test('QR invitation rejects a responder with the wrong nonce', () async {
    final pair = _MemoryConnection.pair();
    final initiatorIdentity = MeshIdentityService(
      store: MemorySyncIdentityStore(),
      random: Random(31),
    );
    final responderIdentity = MeshIdentityService(
      store: MemorySyncIdentityStore(),
      random: Random(32),
    );
    final responderPublic = await responderIdentity.identity();
    final responderFuture = MeshHandshake.respond(
      connection: pair.$2,
      identity: responderIdentity,
      invitationNonce: Uint8List(32)..fillRange(0, 32, 7),
    );
    final invitation = MeshPairingInvitation(
      serviceId: 'opaque-service',
      identityFingerprint: responderPublic.fingerprint,
      oneTimeNonce: Uint8List(32)..fillRange(0, 32, 9),
      expiresAt: DateTime.now().add(const Duration(minutes: 1)),
    );

    await expectLater(
      MeshHandshake.initiate(
        connection: pair.$1,
        identity: initiatorIdentity,
        invitation: invitation,
      ),
      throwsA(isA<Exception>()),
    );
    await expectLater(responderFuture, throwsA(isA<Exception>()));
  });
}

class _MemoryConnection implements MeshConnection {
  _MemoryConnection(this.remoteAddress);

  static (_MemoryConnection, _MemoryConnection) pair() {
    final first = _MemoryConnection('second');
    final second = _MemoryConnection('first');
    first._remote = second;
    second._remote = first;
    return (first, second);
  }

  @override
  final String remoteAddress;
  final _bytes = StreamController<List<int>>();
  late final _MemoryConnection _remote;
  bool _closed = false;

  @override
  Stream<List<int>> get bytes => _bytes.stream;

  @override
  void send(List<int> bytes) {
    if (_closed) throw StateError('closed');
    _remote._bytes.add(List<int>.from(bytes));
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    if (!_remote._closed) {
      await _remote._bytes.close();
    }
    await _bytes.close();
  }
}
