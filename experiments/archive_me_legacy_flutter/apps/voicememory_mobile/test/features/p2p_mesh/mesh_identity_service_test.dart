import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/p2p_mesh/mesh_models.dart';
import 'package:voicememory_mobile/services/security/mesh_identity_service.dart';
import 'package:voicememory_mobile/services/security/sync_identity_service.dart';

void main() {
  group('MeshIdentityService', () {
    test('persists an Ed25519 identity in the supplied secure store', () async {
      final store = MemorySyncIdentityStore();
      final first = MeshIdentityService(store: store, random: Random(7));
      final original = await first.identity();

      final reloaded = await MeshIdentityService(
        store: store,
        random: Random(99),
      ).identity();

      expect(reloaded.deviceId, original.deviceId);
      expect(reloaded.publicKey, original.publicKey);
      expect(reloaded.fingerprint, original.fingerprint);
      expect(store.values.keys, contains('mesh_ed25519_seed_v1'));
    });

    test(
      'authenticates transcript and derives matching directional keys',
      () async {
        final initiator = MeshIdentityService(
          store: MemorySyncIdentityStore(),
          random: Random(1),
        );
        final responder = MeshIdentityService(
          store: MemorySyncIdentityStore(),
          random: Random(2),
        );
        final initiatorEphemeral = await initiator.createHandshakeParty();
        final responderEphemeral = await responder.createHandshakeParty();
        var transcript = MeshHandshakeTranscript(
          initiator: initiatorEphemeral.party,
          responder: responderEphemeral.party,
        );
        transcript = await initiator.signTranscript(
          transcript,
          role: MeshHandshakeRole.initiator,
        );
        transcript = await responder.signTranscript(
          transcript,
          role: MeshHandshakeRole.responder,
        );

        expect(await initiator.verifyTranscript(transcript), isTrue);
        final initiatorKeys = await initiator.establishSession(
          transcript: transcript,
          role: MeshHandshakeRole.initiator,
          localEphemeral: initiatorEphemeral,
        );
        final responderKeys = await responder.establishSession(
          transcript: transcript,
          role: MeshHandshakeRole.responder,
          localEphemeral: responderEphemeral,
        );

        expect(initiatorKeys.sendKey, responderKeys.receiveKey);
        expect(initiatorKeys.receiveKey, responderKeys.sendKey);
        expect(initiatorKeys.sendNoncePrefix, responderKeys.receiveNoncePrefix);
        expect(initiatorKeys.receiveNoncePrefix, responderKeys.sendNoncePrefix);
        expect(initiatorKeys.sas, matches(RegExp(r'^\d{6}$')));
        expect(responderKeys.sas, initiatorKeys.sas);

        initiatorEphemeral.destroy();
        responderEphemeral.destroy();
        initiatorKeys.destroy();
        responderKeys.destroy();
      },
    );

    test('rejects a transcript changed after signing', () async {
      final initiator = MeshIdentityService(
        store: MemorySyncIdentityStore(),
        random: Random(3),
      );
      final responder = MeshIdentityService(
        store: MemorySyncIdentityStore(),
        random: Random(4),
      );
      final initiatorEphemeral = await initiator.createHandshakeParty();
      final responderEphemeral = await responder.createHandshakeParty();
      var transcript = MeshHandshakeTranscript(
        initiator: initiatorEphemeral.party,
        responder: responderEphemeral.party,
      );
      transcript = await initiator.signTranscript(
        transcript,
        role: MeshHandshakeRole.initiator,
      );
      transcript = await responder.signTranscript(
        transcript,
        role: MeshHandshakeRole.responder,
      );
      final changed = MeshHandshakeTranscript(
        initiator: transcript.initiator,
        responder: MeshHandshakeParty(
          deviceId: '${transcript.responder.deviceId}-changed',
          identityPublicKey: transcript.responder.identityPublicKey,
          ephemeralPublicKey: transcript.responder.ephemeralPublicKey,
          nonce: transcript.responder.nonce,
        ),
        initiatorSignature: transcript.initiatorSignature,
        responderSignature: transcript.responderSignature,
      );

      expect(await initiator.verifyTranscript(changed), isFalse);
      await expectLater(
        initiator.establishSession(
          transcript: changed,
          role: MeshHandshakeRole.initiator,
          localEphemeral: initiatorEphemeral,
        ),
        throwsStateError,
      );

      initiatorEphemeral.destroy();
      responderEphemeral.destroy();
    });

    test('mesh session pairing preserves sync phrase and key epoch', () async {
      const phrase =
          'abandon abandon abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon about';
      final source = SyncIdentityService(store: MemorySyncIdentityStore());
      await source.installRecoveryPhrase(phrase);
      await source.rotate();
      final expectedPhrase = await source.recoveryPhrase();
      final bundle = await source.createMeshSessionPairingBundle();
      final destination = SyncIdentityService(store: MemorySyncIdentityStore());
      try {
        await destination.acceptMeshSessionPairingBundle(bundle);
      } finally {
        bundle.fillRange(0, bundle.length, 0);
      }

      expect(await destination.recoveryPhrase(), expectedPhrase);
      expect(await destination.keyEpoch, 2);
    });
  });
}
