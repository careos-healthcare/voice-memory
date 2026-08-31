/// At-rest encryption and key-material handling for ArchiveMe.
///
/// Must not depend on `archiveme_mobile`. The app implements [KeyMaterialStore]
/// with `SecureStorageService` (prefixed) and a separate unprefixed vault
/// adapter.
library archiveme_crypto;

export 'src/key_material_store.dart';
export 'src/memory_key_material_store.dart';
export 'src/vault/sqlite_vault_crypto.dart';
