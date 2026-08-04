import 'dart:typed_data';

import '../../../services/security/mesh_identity_service.dart';
import '../../../services/security/biometric_vault_service.dart';
import '../mesh_trust_store.dart';
import 'vault_share_models.dart';

class MeshIdentityVaultShareSigner implements VaultShareSigner {
  MeshIdentityVaultShareSigner._(
    this._identity, {
    required this.signerId,
    required this.publicKeyBytes,
  });

  static Future<MeshIdentityVaultShareSigner> create(
    MeshIdentityService identity,
  ) async {
    final value = await identity.identity();
    return MeshIdentityVaultShareSigner._(
      identity,
      signerId: value.deviceId,
      publicKeyBytes: Uint8List.fromList(value.publicKey),
    );
  }

  final MeshIdentityService _identity;

  @override
  final String signerId;

  @override
  final Uint8List publicKeyBytes;

  @override
  Future<Uint8List> sign(Uint8List message) => _identity.signDetached(message);
}

class BiometricVaultShareAuthorizer implements VaultShareBiometricAuthorizer {
  const BiometricVaultShareAuthorizer(this.vault);

  final BiometricVaultService vault;

  @override
  Future<bool> authorizeVaultShare(VaultShareSelection selection) =>
      vault.reauthenticateAndUnlock(
        reason: 'Confirm your identity to share selected private memories',
      );
}

class MeshVaultShareTrust implements VaultShareSignerTrust {
  MeshVaultShareTrust(Iterable<TrustedMeshPeer> peers)
    : _publicKeys = {
        for (final peer in peers)
          peer.deviceId: Uint8List.fromList(peer.identityPublicKey),
      };

  final Map<String, Uint8List> _publicKeys;

  @override
  bool isTrusted({
    required String signerId,
    required Uint8List publicKeyBytes,
  }) {
    final expected = _publicKeys[signerId];
    if (expected == null || expected.length != publicKeyBytes.length) {
      return false;
    }
    var difference = 0;
    for (var index = 0; index < expected.length; index++) {
      difference |= expected[index] ^ publicKeyBytes[index];
    }
    return difference == 0;
  }
}
