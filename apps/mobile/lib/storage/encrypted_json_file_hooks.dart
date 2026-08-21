/// Optional fault-injection hooks for encrypted JSON storage tests.
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