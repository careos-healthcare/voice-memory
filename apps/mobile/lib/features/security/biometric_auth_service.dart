import 'package:archiveme_mobile/features/security/private_vault_gate.dart';
import 'package:archiveme_mobile/security/app_lock_service.dart';
import 'package:local_auth/local_auth.dart';

/// Face ID, Touch ID, or device PIN before private moments are shown.
class BiometricAuthService {
  BiometricAuthService({
    BiometricAuthenticator? authenticator,
    LocalAuthentication? localAuth,
  }) : _authenticator =
           authenticator ??
           _LocalOrPinAuthenticator(localAuth ?? LocalAuthentication());

  final BiometricAuthenticator _authenticator;

  bool unlocked = false;

  static const unlockReason = 'Unlock your archive';

  /// Prompts on launch and after the app returns from the background.
  Future<bool> unlock({String reason = unlockReason}) async {
    try {
      final ok = await _authenticator.authenticate(reason);
      unlocked = ok;
      if (ok) {
        PrivateVaultGate.unlock();
      }
      return ok;
    } on Object catch (error) {
      error.runtimeType;
      unlocked = false;
      return false;
    }
  }

  void lock() {
    unlocked = false;
    PrivateVaultGate.lock();
  }
}

class _LocalOrPinAuthenticator implements BiometricAuthenticator {
  _LocalOrPinAuthenticator(this._auth);

  final LocalAuthentication _auth;

  @override
  Future<bool> available() async {
    try {
      return await _auth.isDeviceSupported();
    } on Object catch (error) {
      error.runtimeType;
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      if (!await available()) return false;
      return await _auth.authenticate(localizedReason: reason);
    } on Object catch (error) {
      error.runtimeType;
      return false;
    }
  }
}
