import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import '../../storage/secure_storage.dart';

enum BiometricVaultState { disabled, locked, unlocking, unlocked }

enum VaultAutoLock {
  immediate(Duration.zero, 'Immediate'),
  oneMinute(Duration(minutes: 1), 'After 1 minute'),
  fiveMinutes(Duration(minutes: 5), 'After 5 minutes');

  const VaultAutoLock(this.duration, this.label);

  final Duration duration;
  final String label;

  static VaultAutoLock fromSeconds(int? seconds) => values.firstWhere(
    (value) => value.duration.inSeconds == seconds,
    orElse: () => immediate,
  );
}

abstract class VaultDeviceAuthenticator {
  Future<bool> authenticate(String reason);
}

class LocalAuthVaultDeviceAuthenticator implements VaultDeviceAuthenticator {
  LocalAuthVaultDeviceAuthenticator({LocalAuthentication? authentication})
    : _authentication = authentication ?? LocalAuthentication();

  final LocalAuthentication _authentication;

  @override
  Future<bool> authenticate(String reason) async {
    try {
      if (!await _authentication.isDeviceSupported()) return false;
      return _authentication.authenticate(
        localizedReason: reason,
        biometricOnly: false,
      );
    } on Object {
      return false;
    }
  }
}

abstract class BiometricVaultSecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class PlatformBiometricVaultSecureStore implements BiometricVaultSecureStore {
  PlatformBiometricVaultSecureStore({SecureStorageService? storage})
    : _storage = storage ?? SecureStorageService();

  final SecureStorageService _storage;

  @override
  Future<String?> read(String key) => _storage.read(key);

  @override
  Future<void> write(String key, String value) => _storage.write(key, value);

  @override
  Future<void> delete(String key) => _storage.delete(key);
}

class MemoryBiometricVaultSecureStore implements BiometricVaultSecureStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

/// Session gate for the local AES-256 master key.
///
/// Platform secure storage is backed by Keychain/Keystore. Authentication is
/// requested with device-owner fallback (biometric or device credential).
/// Flutter cannot guarantee a non-exportable Secure Enclave AES key on every
/// supported OS version, so this service makes no stronger claim: plaintext
/// key bytes exist only in this explicitly zeroized in-memory session.
class BiometricVaultService extends ChangeNotifier {
  BiometricVaultService({
    BiometricVaultSecureStore? store,
    VaultDeviceAuthenticator? authenticator,
    DateTime Function()? clock,
  }) : _store = store ?? PlatformBiometricVaultSecureStore(),
       _authenticator = authenticator ?? LocalAuthVaultDeviceAuthenticator(),
       _clock = clock ?? DateTime.now;

  static const _enabledKey = 'biometric_vault_enabled_v1';
  static const _masterKey = 'private_journal_encryption_key_v1';
  static const _autoLockKey = 'biometric_vault_auto_lock_seconds_v1';
  static const keyLength = 32;

  static BiometricVaultService? _instance;
  static BiometricVaultService get instance =>
      _instance ??= BiometricVaultService();

  static void install(BiometricVaultService service) {
    if (!identical(_instance, service)) _instance?.dispose();
    _instance = service;
  }

  @visibleForTesting
  static set instanceForTest(BiometricVaultService? value) {
    if (value != null) {
      install(value);
      return;
    }
    _instance?.dispose();
    _instance = value;
  }

  final BiometricVaultSecureStore _store;
  final VaultDeviceAuthenticator _authenticator;
  final DateTime Function() _clock;
  final StreamController<BiometricVaultState> _states =
      StreamController<BiometricVaultState>.broadcast(sync: true);

  Uint8List? _keyBytes;
  BiometricVaultState _state = BiometricVaultState.disabled;
  VaultAutoLock _autoLock = VaultAutoLock.immediate;
  DateTime? _backgroundedAt;
  bool _initialized = false;

  BiometricVaultState get state => _state;
  Stream<BiometricVaultState> get states => _states.stream;
  bool get isEnabled => _state != BiometricVaultState.disabled;
  bool get isUnlocked => _state == BiometricVaultState.unlocked;
  bool get keyMaterialLoaded => _keyBytes != null;
  bool get initialized => _initialized;
  VaultAutoLock get autoLock => _autoLock;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      _autoLock = VaultAutoLock.fromSeconds(
        int.tryParse(await _store.read(_autoLockKey) ?? ''),
      );
      final enabled = await _store.read(_enabledKey) == 'true';
      _setState(
        enabled ? BiometricVaultState.locked : BiometricVaultState.disabled,
      );
    } on Object {
      _setState(BiometricVaultState.disabled);
    } finally {
      _initialized = true;
    }
  }

  Future<bool> enable() async {
    if (!await _authenticate()) return false;
    var key = await _readPersistedKey();
    key ??= _generateKey();
    await _store.write(_masterKey, base64Encode(key));
    await _store.write(_enabledKey, 'true');
    _loadKey(key);
    _setState(BiometricVaultState.unlocked);
    return true;
  }

  Future<void> disable() async {
    lock();
    await _store.delete(_enabledKey);
    _setState(BiometricVaultState.disabled);
  }

  Future<void> destroyMasterKeyForPrivacyWipe() async {
    lock();
    await _store.delete(_masterKey);
    await _store.delete(_enabledKey);
    _setState(BiometricVaultState.disabled);
  }

  Future<bool> unlock() async {
    if (!isEnabled) return false;
    return reauthenticateAndUnlock(
      reason: 'Unlock your private ArchiveMe vault',
    );
  }

  /// Performs exactly one fresh device-owner authentication. When protection
  /// is enabled it also reloads the persisted key into the active session;
  /// when disabled, successful owner authentication is sufficient.
  Future<bool> reauthenticateAndUnlock({
    String reason = 'Confirm your identity to access your private archive',
  }) async {
    final enabled = isEnabled;
    if (enabled) _setState(BiometricVaultState.unlocking);
    if (!await _authenticator.authenticate(reason)) {
      if (enabled) _setState(BiometricVaultState.locked);
      return false;
    }
    if (!enabled) return true;
    final key = await _readPersistedKey();
    if (key == null || key.length != keyLength) {
      _setState(BiometricVaultState.locked);
      return false;
    }
    _loadKey(key);
    _backgroundedAt = null;
    _setState(BiometricVaultState.unlocked);
    return true;
  }

  /// Performs a device-owner check without changing the vault session.
  Future<bool> authenticateDeviceOwner({
    String reason = 'Confirm your identity to access your private archive',
  }) => _authenticator.authenticate(reason);

  /// Returns a newly-owned copy only after fresh device-owner authentication.
  Future<Uint8List?> exportMasterKeyForPortability() async {
    if (!await reauthenticateAndUnlock(
      reason: 'Confirm your identity to create an encrypted backup',
    )) {
      return null;
    }
    final key = await _readPersistedKey();
    if (key == null || key.length != keyLength) {
      key?.fillRange(0, key.length, 0);
      return null;
    }
    return key;
  }

  /// Replaces the persisted and active 32-byte key after a fresh owner check.
  /// The returned transaction can be used only with this service for rollback.
  Future<BiometricVaultKeyReplacement?> replaceMasterKeyForRestore(
    Uint8List restoredKey,
  ) async {
    if (restoredKey.length != keyLength) {
      throw ArgumentError.value(
        restoredKey.length,
        'restoredKey.length',
        'expected $keyLength bytes',
      );
    }
    if (!await reauthenticateAndUnlock(
      reason: 'Confirm your identity to restore your encrypted vault',
    )) {
      return null;
    }
    final previous = await _readPersistedKey();
    final installed = Uint8List.fromList(restoredKey);
    try {
      await _store.write(_masterKey, base64Encode(installed));
      _loadKey(installed);
      if (isEnabled) _setState(BiometricVaultState.unlocked);
      return BiometricVaultKeyReplacement._(this, previous);
    } finally {
      installed.fillRange(0, installed.length, 0);
    }
  }

  Future<void> rollbackMasterKeyReplacement(
    BiometricVaultKeyReplacement transaction,
  ) async {
    if (!identical(transaction._owner, this) || transaction._consumed) {
      throw StateError('Invalid or already-consumed key replacement.');
    }
    transaction._consumed = true;
    final previous = transaction._previous;
    try {
      if (previous == null) {
        await _store.delete(_masterKey);
        lock();
      } else {
        await _store.write(_masterKey, base64Encode(previous));
        _loadKey(previous);
        if (isEnabled) _setState(BiometricVaultState.unlocked);
      }
    } finally {
      previous?.fillRange(0, previous.length, 0);
    }
  }

  void commitMasterKeyReplacement(BiometricVaultKeyReplacement transaction) {
    if (!identical(transaction._owner, this) || transaction._consumed) {
      throw StateError('Invalid or already-consumed key replacement.');
    }
    transaction._consumed = true;
    final previous = transaction._previous;
    previous?.fillRange(0, previous.length, 0);
  }

  Uint8List requireKeyBytes() {
    final key = _keyBytes;
    if (key == null || !isUnlocked) {
      throw StateError('Biometric vault is locked.');
    }
    return Uint8List.fromList(key);
  }

  Future<T> withUnlockedKey<T>(
    Future<T> Function(Uint8List keyBytes) operation,
  ) async {
    final copy = requireKeyBytes();
    try {
      return await operation(copy);
    } finally {
      copy.fillRange(0, copy.length, 0);
    }
  }

  Future<void> setAutoLock(VaultAutoLock value) async {
    _autoLock = value;
    await _store.write(_autoLockKey, '${value.duration.inSeconds}');
    notifyListeners();
  }

  void onAppBackgrounded() {
    _backgroundedAt = _clock().toUtc();
    if (_autoLock == VaultAutoLock.immediate) lock();
  }

  Future<bool> onAppResumed() async {
    if (!isEnabled) return true;
    final backgroundedAt = _backgroundedAt;
    if (backgroundedAt != null &&
        _clock().toUtc().difference(backgroundedAt) >= _autoLock.duration) {
      lock();
    }
    _backgroundedAt = null;
    if (isUnlocked) return true;
    return unlock();
  }

  void lock() {
    final key = _keyBytes;
    if (key != null) {
      key.fillRange(0, key.length, 0);
      _keyBytes = null;
    }
    if (isEnabled) _setState(BiometricVaultState.locked);
  }

  Future<bool> _authenticate() =>
      _authenticator.authenticate('Unlock your private ArchiveMe vault');

  Future<Uint8List?> _readPersistedKey() async {
    final encoded = await _store.read(_masterKey);
    if (encoded == null || encoded.isEmpty) return null;
    try {
      return Uint8List.fromList(base64Decode(encoded));
    } on FormatException {
      return null;
    }
  }

  Uint8List _generateKey() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(keyLength, (_) => random.nextInt(256)),
    );
  }

  void _loadKey(List<int> key) {
    lock();
    _keyBytes = Uint8List.fromList(key);
  }

  void _setState(BiometricVaultState value) {
    if (_state == value) return;
    _state = value;
    if (!_states.isClosed) _states.add(value);
    notifyListeners();
  }

  @override
  void dispose() {
    lock();
    _states.close();
    super.dispose();
  }
}

final class BiometricVaultKeyReplacement {
  BiometricVaultKeyReplacement._(this._owner, Uint8List? previous)
    : _previous = previous == null ? null : Uint8List.fromList(previous) {
    previous?.fillRange(0, previous.length, 0);
  }

  final BiometricVaultService _owner;
  final Uint8List? _previous;
  bool _consumed = false;
}
