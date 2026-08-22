/// Copy for SQLCipher lifecycle unlock surfaces.
abstract final class SecureDatabaseCopy {
  SecureDatabaseCopy._();

  static const title = 'Unlock local archive';

  /// Says what the prompt is for, not what protects the file underneath.
  ///
  /// It used to say "your encrypted on-device database", which reads as a
  /// claim about the storage rather than about this screen — and an unscoped
  /// one, since SQLCipher is only in play on iOS and Android. Privacy &
  /// Security reports the live encryption state; this sheet only needs to
  /// explain why it is asking.
  static const body =
      'Face ID, Touch ID, or your device password is required to '
      'open your archive on this device.';
  static const biometricReason = title;
  static const unlockAction = 'Unlock with biometrics';
  static const unavailable =
      'Biometric unlock is unavailable on this device.';
}
