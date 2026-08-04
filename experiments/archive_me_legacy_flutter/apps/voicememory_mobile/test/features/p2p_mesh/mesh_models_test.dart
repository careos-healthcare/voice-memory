import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/p2p_mesh/mesh_models.dart';

void main() {
  test('handshake transcript has stable JSON round trip and signing bytes', () {
    final transcript = MeshHandshakeTranscript(
      initiator: MeshHandshakeParty(
        deviceId: 'device-a',
        identityPublicKey: List.generate(32, (index) => index),
        ephemeralPublicKey: List.generate(32, (index) => index + 1),
        nonce: List.filled(32, 3),
      ),
      responder: MeshHandshakeParty(
        deviceId: 'device-b',
        identityPublicKey: List.generate(32, (index) => 31 - index),
        ephemeralPublicKey: List.filled(32, 5),
        nonce: List.filled(32, 6),
      ),
      initiatorSignature: List.filled(64, 7),
      responderSignature: List.filled(64, 8),
    );

    final decoded = MeshHandshakeTranscript.fromJson(transcript.toJson());

    expect(decoded.signingBytes, transcript.signingBytes);
    expect(decoded.initiatorSignature, transcript.initiatorSignature);
    expect(decoded.responderSignature, transcript.responderSignature);
  });

  test('rejects malformed handshake key material', () {
    expect(
      () => MeshHandshakeParty(
        deviceId: 'device',
        identityPublicKey: List.filled(31, 0),
        ephemeralPublicKey: List.filled(32, 0),
        nonce: List.filled(32, 0),
      ),
      throwsArgumentError,
    );
  });

  test('validates discovered peers before network use', () {
    expect(
      () => MeshPeer(
        id: 'peer',
        name: 'Nearby phone',
        host: '192.0.2.1',
        port: 0,
        identityFingerprint: 'fingerprint',
      ),
      throwsArgumentError,
    );
  });
}
