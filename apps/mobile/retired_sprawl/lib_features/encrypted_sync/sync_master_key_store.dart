import 'package:archiveme_mobile/sync/sync_crypto.dart';

export 'package:archiveme_mobile/sync/sync_crypto.dart'
    show
        InMemorySyncCryptoKeyStore,
        SecureSyncCryptoKeyStore,
        SyncCryptoKeyStore;

/// Account-scoped sync encryption key — never sent to the server in plaintext.
abstract class SyncMasterKeyStore implements SyncCryptoKeyStore {}

class SecureSyncMasterKeyStore extends SecureSyncCryptoKeyStore
    implements SyncMasterKeyStore {
  SecureSyncMasterKeyStore({
    required super.accountNamespace,
    super.secureStorage,
  });

  static const keyByteLength = SecureSyncCryptoKeyStore.keyByteLength;
}

/// In-memory key store for unit tests.
class InMemorySyncMasterKeyStore extends InMemorySyncCryptoKeyStore
    implements SyncMasterKeyStore {}
