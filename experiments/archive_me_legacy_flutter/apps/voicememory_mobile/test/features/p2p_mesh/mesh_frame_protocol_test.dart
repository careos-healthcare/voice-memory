import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/p2p_mesh/mesh_frame_protocol.dart';
import 'package:voicememory_mobile/features/p2p_mesh/mesh_models.dart';

void main() {
  late MeshFrameCipher sender;
  late MeshFrameCipher receiver;

  setUp(() {
    final first = MeshSessionKeys(
      sendKey: List.filled(32, 1),
      receiveKey: List.filled(32, 2),
      sendNoncePrefix: [1, 2, 3, 4],
      receiveNoncePrefix: [5, 6, 7, 8],
      sas: '123456',
    );
    final second = MeshSessionKeys(
      sendKey: first.receiveKey,
      receiveKey: first.sendKey,
      sendNoncePrefix: first.receiveNoncePrefix,
      receiveNoncePrefix: first.sendNoncePrefix,
      sas: first.sas,
    );
    sender = MeshFrameCipher(keys: first, maxPlaintextBytes: 64);
    receiver = MeshFrameCipher(keys: second, maxPlaintextBytes: 64);
  });

  tearDown(() {
    sender.destroy();
    receiver.destroy();
  });

  test('encrypts authenticated, sequenced AES-256-GCM frames', () async {
    final packet = await sender.encrypt(type: 7, payload: [10, 20, 30]);
    final frame = await receiver.decrypt(packet);

    expect(frame.type, 7);
    expect(frame.sequence, 0);
    expect(frame.payload, [10, 20, 30]);
    expect(sender.nextSendSequence, 1);
    expect(receiver.nextReceiveSequence, 1);
  });

  test('rejects replayed and out-of-order frames', () async {
    final first = await sender.encrypt(type: 1, payload: [1]);
    final second = await sender.encrypt(type: 1, payload: [2]);

    await expectLater(
      receiver.decrypt(second),
      throwsA(isA<MeshProtocolException>()),
    );
    expect((await receiver.decrypt(first)).payload, [1]);
    expect((await receiver.decrypt(second)).payload, [2]);
    await expectLater(
      receiver.decrypt(first),
      throwsA(isA<MeshProtocolException>()),
    );
  });

  test(
    'does not advance receive sequence after authentication failure',
    () async {
      final packet = await sender.encrypt(type: 2, payload: [4, 5, 6]);
      final tampered = [...packet]..[packet.length - 1] ^= 1;

      await expectLater(
        receiver.decrypt(tampered),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      expect(receiver.nextReceiveSequence, 0);
      expect((await receiver.decrypt(packet)).payload, [4, 5, 6]);
    },
  );

  test('enforces payload and receive buffer limits', () async {
    await expectLater(
      sender.encrypt(type: 1, payload: List.filled(65, 0)),
      throwsA(isA<MeshProtocolException>()),
    );
    final buffer = MeshFrameBuffer(maxPacketBytes: 108);
    expect(
      () => buffer.add(List.filled(217, 0)),
      throwsA(isA<MeshProtocolException>()),
    );
  });

  test('reassembles complete packets from TCP chunks', () async {
    final packet = await sender.encrypt(type: 3, payload: [1, 2, 3, 4]);
    final buffer = MeshFrameBuffer(maxPacketBytes: 108);

    expect(buffer.add(packet.sublist(0, 8)), isEmpty);
    expect(buffer.add(packet.sublist(8, 20)), isEmpty);
    final packets = buffer.add(packet.sublist(20));

    expect(packets, hasLength(1));
    expect(packets.single, packet);
  });
}
