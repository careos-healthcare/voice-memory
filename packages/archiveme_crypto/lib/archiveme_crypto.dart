/// ArchiveMe at-rest encryption and key-material handling.
///
/// Hosts implement [KeyMaterialStore]. Encoding and any keychain prefix
/// are the host's job. This library must not depend on a host app.
///
/// Fault-injection hooks live in `package:archiveme_crypto/testing.dart`.
library archiveme_crypto;

export 'src/json/encrypted_json_file_outcome.dart';
export 'src/json/encrypted_json_file_store.dart';
export 'src/json/encrypted_json_storage.dart';
export 'src/json/private_data_encryption_key_store.dart';
export 'src/key_material_store.dart';
export 'src/memory_key_material_store.dart';
export 'src/sqlcipher/sqlite_database_encryption_key.dart';
export 'src/sqlcipher/sqlite_encryption_key_store.dart';
export 'src/vault/sqlite_vault_crypto.dart';
export 'src/vault/sqlite_vault_key_store.dart';
