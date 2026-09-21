/// Hand-constructed [SqliteDatabaseEncryptionKey.fromStored] inputs.
///
/// These are **not** produced by `generate()` or by calling `fromStored` and
/// reading the result back. They follow the same rules as the Phase 0
/// capture, as fresh literals:
///
/// **v2** — stored form is standard Base64 of exactly 32 raw key bytes.
/// The SQLCipher password **is** that stored string (`fromStored` must not
/// utf8-decode a 32-byte payload).
///
/// **v1** — stored form is standard Base64 of `utf8(passphrase)` where the
/// UTF-8 length is not 32 (and is ≥ 32). The SQLCipher password is the
/// passphrase, not the stored string.
library;

/// 32 bytes `0x9C`. Encoded independently: Base64 of `\x9c` × 32.
const v2RawFillByte = 0x9c;
const v2Stored = 'nJycnJycnJycnJycnJycnJycnJycnJycnJycnJycnJw=';

/// 52 UTF-8 bytes — long enough for v1, not 32 so it cannot be v2.
const v1Passphrase = 'synthetic-v1-passphrase-clearly-longer-than-32-bytes';
const v1Stored =
    'c3ludGhldGljLXYxLXBhc3NwaHJhc2UtY2xlYXJseS1sb25nZXItdGhhbi0zMi1ieXRlcw==';

/// 32 ASCII bytes. Same discriminator as v2: decoded length 32 ⇒ raw key,
/// password is the stored Base64, not the ASCII text.
const v2LooksLikePassphrase = 'abcdefghijklmnopqrstuvwxyz012345';
const v2LooksLikePassphraseStored =
    'YWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXowMTIzNDU=';

/// 12 UTF-8 bytes — too short for either branch.
const shortSecretStored = 'c2hvcnQtc2VjcmV0';
