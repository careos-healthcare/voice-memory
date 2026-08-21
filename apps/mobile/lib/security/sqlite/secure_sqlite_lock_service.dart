import 'dart:io' show Platform;

import 'package:archiveme_mobile/features/privacy/database_biometric_gate_store.dart';
import 'package:archiveme_mobile/security/app_lock_service.dart';
import 'package:archiveme_mobile/security/secure_database_copy.dart';
import 'package:archiveme_mobile/security/sqlite/secure_sqlite_session.dart';
import 'package:archiveme_mobile/security/sqlite/sqlite_encryption_key_store.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_database_initializer.dart';
import 'package:flutter/foundation.dart';

typedef SecureSqliteDatabaseCloser = Future<void> Function();

/// Locks SQLCipher by wiping in-memory keys and closing the DB handle.
class SecureSqliteLockService extends ChangeNotifier {
  SecureSqliteLockService({
    SqliteEncryptionKeyStore? keyStore,
    SecureSqliteSession? session,
    BiometricAuthenticator? biometrics,
    SecureSqliteDatabaseCloser? onLockDatabase,
  }) : _keyStore = keyStore ?? SecureSqliteEncryptionKeyStore(),
       _session = session ?? SecureSqliteSession(),
       _biometrics = biometrics ?? LocalAuthBiometricAuthenticator(),
       _onLockDatabase = onLockDatabase;

  final SqliteEncryptionKeyStore _keyStore;
  final SecureSqliteSession _session;
  final BiometricAuthenticator _biometrics;
  SecureSqliteDatabaseCloser? _onLockDatabase;

  static SecureSqliteLockService? _instance;

  static SecureSqliteLockService get instance =>
      _instance ??= SecureSqliteLockService();

  @visibleForTesting
  static set instanceForTest(SecureSqliteLockService? service) {
    _instance = service;
  }

  static bool encryptionEnabled = !_runningUnderFlutterTest;

  static bool get _runningUnderFlutterTest =>
      Platform.environment.containsKey('FLUTTER_TEST');

  bool _lockRequired = false;

  SecureSqliteSession get session => _session;

  bool get lockRequired => _lockRequired;

  bool get isLocked => encryptionEnabled && (!_session.isUnlocked || _lockRequired);

  void bindDatabaseCloser(SecureSqliteDatabaseCloser closer) {
    _onLockDatabase = closer;
  }

  /// Loads or creates the persisted encryption key into the in-memory session.
  Future<String> bootstrapUnlockedSession() async {
    if (!encryptionEnabled) {
      _lockRequired = false;
      _session.unlock(SqliteDatabaseInitializer.testEncryptionPassword);
      return _session.requirePassphrase();
    }
    final key = await _keyStore.ensureEncryptionKey();
    _session.unlock(key.sqlcipherPassword);
    _lockRequired = false;
    notifyListeners();
    return key.sqlcipherPassword;
  }

  Future<bool> biometricsAvailable() => _biometrics.available();

  /// Face ID / Touch ID gate before restoring the in-memory passphrase.
  Future<bool> unlockWithBiometric() async {
    if (!encryptionEnabled) {
      await bootstrapUnlockedSession();
      return true;
    }
    if (!await _biometrics.available()) return false;

    final ok = await _biometrics.authenticate(
      SecureDatabaseCopy.biometricReason,
    );
    if (!ok) return false;

    final key = await _keyStore.readEncryptionKey();
    if (key == null) return false;

    _session.unlock(key.sqlcipherPassword);
    _lockRequired = false;
    notifyListeners();
    return true;
  }

  /// Background/minimize handler — wipe RAM keys and close SQLite.
  Future<void> lockDatabaseFromLifecycle() async {
    if (!encryptionEnabled) return;
    await DatabaseBiometricGateStore.ensureLoaded();
    if (!DatabaseBiometricGateStore.enabled) return;
    _session.lock();
    _lockRequired = true;
    final closer = _onLockDatabase;
    if (closer != null) {
      await closer();
    }
    notifyListeners();
  }

  Future<void> onAppResumed() async {
    if (!encryptionEnabled || !_lockRequired) return;
    notifyListeners();
  }

  @visibleForTesting
  void resetForTest() {
    _session.resetForTest();
    _lockRequired = false;
  }
}
