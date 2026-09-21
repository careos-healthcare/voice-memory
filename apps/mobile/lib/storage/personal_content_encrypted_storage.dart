import 'package:archiveme_mobile/storage/encrypted_json_storage.dart';
import 'package:archiveme_mobile/storage/private_data_encryption_key_store.dart';
import 'package:archiveme_mobile/storage/secure_storage.dart';

/// AES-GCM storage using the same per-namespace key as [JournalStore].
abstract final class PersonalContentEncryptedStorage {
  PersonalContentEncryptedStorage._();

  static Future<EncryptedJsonStorage> forNamespace({
    required SecureStorageService secureStorage,
    required String keyAlias,
  }) async {
    final keyStore = SecurePrivateDataEncryptionKeyStore(
      store: secureStorage,
      keyAlias: keyAlias,
    );
    final keyBytes = await keyStore.ensureKey();
    return EncryptedJsonStorage(masterKeyBytes: keyBytes);
  }

  static EncryptedJsonStorage forTest({List<int>? masterKeyBytes}) {
    return EncryptedJsonStorage(
      masterKeyBytes:
          masterKeyBytes ?? List<int>.generate(32, (index) => index + 1),
    );
  }
}
