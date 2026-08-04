import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import '../services/activation_funnel_analytics.dart';
import 'app_lock_settings.dart';
import 'app_lock_store.dart';
import 'pin_hash.dart';

/// Abstraction over the platform biometric prompt so the lock logic is
/// testable and degrades gracefully on devices without biometrics.
abstract class BiometricAuthenticator {
  /// True when the device can show a biometric prompt right now.
  Future<bool> available();

  /// Shows the platform prompt; true only on a successful authentication.
  /// Cancel and failure both return false — the caller falls back to PIN.
  Future<bool> authenticate(String reason);
}

/// Production authenticator over local_auth. Every call is wrapped — a
/// missing plugin, unsupported device, or platform error simply reads as
/// "not available" / "not authenticated", never an exception.
class LocalAuthBiometricAuthenticator implements BiometricAuthenticator {
  LocalAuthBiometricAuthenticator({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> available() async {
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } catch (_) {
      return false;
    }
  }
}

/// Always-unavailable authenticator for tests and platforms without
/// biometric hardware.
class NoBiometricAuthenticator implements BiometricAuthenticator {
  const NoBiometricAuthenticator();

  @override
  Future<bool> available() async => false;

  @override
  Future<bool> authenticate(String reason) async => false;
}

/// Orchestrates the optional app lock: PIN setup/verification (salted hash
/// only — no raw PIN is ever stored, logged, or passed to analytics),
/// optional biometric unlock with PIN fallback, the per-session unlock
/// state, and immediate re-lock whenever the app leaves the foreground.
class AppLockService extends ChangeNotifier {
  AppLockService({
    AppLockStore? store,
    BiometricAuthenticator? biometrics,
    DateTime Function()? clock,
  }) : _store = store ?? AppLockStore(store: SecureAppLockStore()),
       _biometrics = biometrics ?? LocalAuthBiometricAuthenticator();

  final AppLockStore _store;
  final BiometricAuthenticator _biometrics;
  static AppLockService? _instance;

  /// Process-wide instance used by the gate and the settings surface.
  static AppLockService get instance => _instance ??= AppLockService();

  @visibleForTesting
  static set instanceForTest(AppLockService? service) {
    _instance = service;
  }

  bool _unlockedThisSession = false;
  bool _wasBackgrounded = false;

  /// True after a successful unlock (or fresh setup) this session.
  bool get unlockedThisSession => _unlockedThisSession;

  Future<bool> isEnabled() => _store.enabled();

  /// True when the lock screen must be shown before any archive content.
  Future<bool> isLocked() async => await isEnabled() && !_unlockedThisSession;

  /// Device capability — independent of the user's opt-in.
  Future<bool> biometricsAvailable() => _biometrics.available();

  /// True when the user opted in, a PIN exists, and the device supports it.
  Future<bool> biometricUnlockReady() async {
    if (!await _store.enabled()) return false;
    if (!await _store.biometricsEnabled()) return false;
    if (await _store.readCredentials() == null) return false;
    return _biometrics.available();
  }

  /// Sets up the lock with a new PIN. Derives a fresh salt + hash, stores
  /// only those, and leaves this session unlocked.
  Future<bool> enableWithPin(String pin) async {
    if (!PinHash.isValidPin(pin)) return false;
    final salt = PinHash.generateSalt();
    await _store.saveCredentials(
      pinHash: PinHash.hash(pin: pin, salt: salt),
      pinSalt: salt,
    );
    _unlockedThisSession = true;
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.appLockEnabled,
      enabled: true,
    );
    notifyListeners();
    return true;
  }

  /// Verifies a PIN attempt against the stored hash. A success unlocks the
  /// session; both outcomes are tracked with the method id only.
  Future<bool> verifyPin(String pin) async {
    final credentials = await _store.readCredentials();
    final ok =
        credentials != null &&
        PinHash.verify(
          pin: pin,
          salt: credentials.salt,
          expectedHash: credentials.hash,
        );
    if (ok) {
      _unlockedThisSession = true;
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.appLockUnlocked,
        method: 'pin',
      );
      notifyListeners();
    } else {
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.appLockFailed,
        method: 'pin',
      );
    }
    return ok;
  }

  /// One biometric attempt. Success unlocks the session; failure or cancel
  /// leaves the lock in place so the PIN path takes over.
  Future<bool> attemptBiometricUnlock() async {
    if (!await biometricUnlockReady()) return false;
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.biometricUnlockAttempted,
      method: 'biometric',
    );
    final ok = await _biometrics.authenticate(AppLockCopy.biometricReason);
    if (ok) {
      _unlockedThisSession = true;
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.biometricUnlockSucceeded,
        method: 'biometric',
      );
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.appLockUnlocked,
        method: 'biometric',
      );
      notifyListeners();
    } else {
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.biometricUnlockFailed,
        method: 'biometric',
      );
    }
    return ok;
  }

  /// Changes the PIN — only allowed while this session is unlocked.
  Future<bool> changePin(String newPin) async {
    if (!_unlockedThisSession) return false;
    if (!PinHash.isValidPin(newPin)) return false;
    final salt = PinHash.generateSalt();
    await _store.saveCredentials(
      pinHash: PinHash.hash(pin: newPin, salt: salt),
      pinSalt: salt,
    );
    notifyListeners();
    return true;
  }

  /// Turns the lock off and clears every stored credential — only allowed
  /// while this session is unlocked.
  Future<bool> disable() async {
    if (!_unlockedThisSession) return false;
    return _clearLockCredentials();
  }

  /// Emergency wipe path — clears lock credentials without an unlocked session.
  Future<void> disableAfterEmergencyWipe() async {
    await _clearLockCredentials();
  }

  Future<bool> _clearLockCredentials() async {
    await _store.clear();
    _unlockedThisSession = false;
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.appLockDisabled,
      enabled: false,
    );
    notifyListeners();
    return true;
  }

  /// User opt-in for biometrics — meaningful only once a PIN exists.
  Future<void> setBiometricsEnabled(bool enabled) async {
    await _store.setBiometricsEnabled(enabled);
    notifyListeners();
  }

  // --- Lifecycle ---

  /// Called when the app moves to the background.
  void onAppBackgrounded() {
    _wasBackgrounded = true;
  }

  /// Called when the app returns to the foreground. Every completed
  /// background transition requires a fresh biometric or PIN unlock.
  Future<void> onAppResumed() async {
    if (!_wasBackgrounded) return;
    _wasBackgrounded = false;
    if (!_unlockedThisSession) return;
    if (!await isEnabled()) return;
    _unlockedThisSession = false;
    notifyListeners();
  }

  @visibleForTesting
  void resetSessionForTest() {
    _unlockedThisSession = false;
    _wasBackgrounded = false;
  }
}
