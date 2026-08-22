import 'package:archiveme_mobile/security/app_lock_service.dart';
import 'package:archiveme_mobile/security/sqlite/secure_sqlite_lock_service.dart';
import 'package:archiveme_mobile/security/sqlite/secure_sqlite_session.dart';
import 'package:archiveme_mobile/security/sqlite/sqlite_encryption_key_store.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBiometrics implements BiometricAuthenticator {
  bool isAvailable = true;
  bool result = true;

  @override
  Future<bool> authenticate(String reason) async => result;

  @override
  Future<bool> available() async => isAvailable;
}

void main() {
  group('SecureSqliteSession', () {
    test('lock wipes passphrase from memory', () {
      final session = SecureSqliteSession()..unlock('secret-passphrase');
      expect(session.isUnlocked, isTrue);
      session.lock();
      expect(session.isUnlocked, isFalse);
      expect(() => session.requirePassphrase(), throwsStateError);
    });
  });

  group('SecureSqliteLockService', () {
    late InMemorySqliteEncryptionKeyStore keyStore;
    late SecureSqliteSession session;
    late _FakeBiometrics biometrics;
    late SecureSqliteLockService lock;
    var closed = false;

    setUp(() {
      SecureSqliteLockService.encryptionEnabled = true;
      keyStore = InMemorySqliteEncryptionKeyStore();
      session = SecureSqliteSession();
      biometrics = _FakeBiometrics();
      closed = false;
      lock = SecureSqliteLockService(
        keyStore: keyStore,
        session: session,
        biometrics: biometrics,
        onLockDatabase: () async {
          closed = true;
        },
      );
    });

    tearDown(() {
      SecureSqliteLockService.encryptionEnabled = false;
      SecureSqliteLockService.instanceForTest = null;
    });

    test('bootstrap loads persisted passphrase into session', () async {
      await lock.bootstrapUnlockedSession();
      expect(session.isUnlocked, isTrue);
      expect(lock.isLocked, isFalse);
    });

    test('lifecycle lock wipes session and closes database', () async {
      await lock.bootstrapUnlockedSession();
      await lock.lockDatabaseFromLifecycle();
      expect(session.isUnlocked, isFalse);
      expect(closed, isTrue);
      expect(lock.isLocked, isTrue);
    });

    test('biometric unlock restores session passphrase', () async {
      await keyStore.ensurePassphrase();
      await lock.lockDatabaseFromLifecycle();
      final ok = await lock.unlockWithBiometric();
      expect(ok, isTrue);
      expect(session.isUnlocked, isTrue);
      expect(lock.isLocked, isFalse);
    });
  });
}
