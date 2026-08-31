/// Test-only fault injection for encrypted JSON file-store crash-safe writes.
///
/// Import from `package:archiveme_crypto/testing.dart`, not the production
/// barrel.
class EncryptedJsonFileHooks {
  const EncryptedJsonFileHooks({
    this.failAfterEncrypt = false,
    this.failAfterTempWrite = false,
    this.failAfterVerify = false,
    this.failBeforeRename = false,
    this.corruptTempFile = false,
    this.skipBackup = false,
  });

  final bool failAfterEncrypt;
  final bool failAfterTempWrite;
  final bool failAfterVerify;
  final bool failBeforeRename;
  final bool corruptTempFile;
  final bool skipBackup;

  static const none = EncryptedJsonFileHooks();
}
