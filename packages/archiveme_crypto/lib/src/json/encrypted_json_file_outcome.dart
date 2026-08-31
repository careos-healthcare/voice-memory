/// Structured outcome of reading an encrypted JSON file.
sealed class EncryptedJsonReadOutcome {
  const EncryptedJsonReadOutcome();
}

/// Primary on-disk file decrypted successfully.
final class EncryptedJsonReadPrimaryValid extends EncryptedJsonReadOutcome {
  const EncryptedJsonReadPrimaryValid(this.value);
  final dynamic value;
}

/// Primary was unreadable; last-known-good backup was used.
final class EncryptedJsonReadRecoveredFromBackup
    extends EncryptedJsonReadOutcome {
  const EncryptedJsonReadRecoveredFromBackup(this.value);
  final dynamic value;
}

/// File exists but encryption key is unavailable.
final class EncryptedJsonReadKeyUnavailable extends EncryptedJsonReadOutcome {
  const EncryptedJsonReadKeyUnavailable();
}

/// Authentication tag verification failed on primary (and backup if tried).
///
/// [recoveredFromBackup] is reserved; the store never constructs `true`.
final class EncryptedJsonReadAuthenticationFailure
    extends EncryptedJsonReadOutcome {
  const EncryptedJsonReadAuthenticationFailure({
    this.recoveredFromBackup = false,
  });
  final bool recoveredFromBackup;
}

/// Primary corrupt; backup decrypts successfully.
final class EncryptedJsonReadCorruptPrimaryValidBackup
    extends EncryptedJsonReadOutcome {
  const EncryptedJsonReadCorruptPrimaryValidBackup(this.value);
  final dynamic value;
}

/// Neither primary nor backup could be decrypted.
final class EncryptedJsonReadBothCopiesCorrupt
    extends EncryptedJsonReadOutcome {
  const EncryptedJsonReadBothCopiesCorrupt();
}

/// No file present — treated as empty archive, not corruption.
final class EncryptedJsonReadMissing extends EncryptedJsonReadOutcome {
  const EncryptedJsonReadMissing();
}

/// Structured outcome of writing an encrypted JSON file.
sealed class EncryptedJsonWriteOutcome {
  const EncryptedJsonWriteOutcome();
}

final class EncryptedJsonWriteSuccess extends EncryptedJsonWriteOutcome {
  const EncryptedJsonWriteSuccess();
}

final class EncryptedJsonWriteKeyUnavailable extends EncryptedJsonWriteOutcome {
  const EncryptedJsonWriteKeyUnavailable();
}

final class EncryptedJsonWriteDiskFailure extends EncryptedJsonWriteOutcome {
  const EncryptedJsonWriteDiskFailure(this.message);
  final String message;
}

final class EncryptedJsonWriteVerificationFailed
    extends EncryptedJsonWriteOutcome {
  const EncryptedJsonWriteVerificationFailed(this.message);
  final String message;
}
