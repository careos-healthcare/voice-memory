/// Copy for SQLCipher lifecycle unlock surfaces.
abstract final class SecureDatabaseCopy {
  SecureDatabaseCopy._();

  static const title = 'Unlock local archive';
  static const body =
      'Face ID, Touch ID, or your device password is required to '
      'open your encrypted on-device database.';
  static const biometricReason = 'Unlock your encrypted archive database';
  static const unlockAction = 'Unlock with biometrics';
  static const unavailable =
      'Biometric unlock is unavailable on this device.';
}
