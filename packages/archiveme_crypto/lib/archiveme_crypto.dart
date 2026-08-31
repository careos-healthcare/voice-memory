/// At-rest encryption and key-material handling for ArchiveMe.
///
/// Must not depend on `archiveme_mobile`. The app implements [KeyMaterialStore]
/// with `SecureStorageService` (prefixed) and a separate unprefixed vault
/// adapter.
library archiveme_crypto;

export 'src/json/encrypted_json_file_hooks.dart';
export 'src/json/encrypted_json_file_outcome.dart';
export 'src/json/encrypted_json_storage.dart';
export 'src/json/private_data_encryption_key_store.dart';
export 'src/key_material_store.dart';
export 'src/memory_key_material_store.dart';
export 'src/sqlcipher/sqlite_database_encryption_key.dart';
export 'src/vault/sqlite_vault_crypto.dart';
