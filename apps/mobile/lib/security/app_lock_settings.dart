/// App Lock — all consumer-facing copy in one place. Calm, factual lines
/// only: no fear, no overclaiming, no security theater.
abstract class AppLockCopy {
  AppLockCopy._();

  // Security settings.
  static const String settingsTitle = 'Protect this archive';
  static const String settingsBody =
      'This protects the archive on this device.';
  static const String relockTimeoutNote =
      'Relocks after about 2 minutes in the background.';
  static const String settingsBiometricsLabel =
      'Use Face ID or Touch ID when available.';
  static const String settingsChangePin = 'Change PIN';
  static const String settingsTurnOff = 'Turn off app lock';

  // PIN setup.
  static const String setupTitle = 'Create a PIN';
  static const String setupBody =
      'This protects the archive on this device. PINs do not leave this device.';
  static const String setupConfirmTitle = 'Confirm PIN';
  static const String setupPrivacyLine = 'PINs do not leave this device.';
  static const String setupMismatch = 'Try again';
  static const String setupPinHint = '4\u20136 digits';
  static const String setupContinueLabel = 'Continue';
  static const String setupSaveLabel = 'Save PIN';

  // Lock screen.
  static const String lockTitle = 'Unlock ArchiveMe';
  static const String lockBody = 'Enter your PIN';
  static const String lockBiometricsLabel = 'Use biometrics';
  static const String lockTryAgain = 'Try again';
  static const String lockUnlockLabel = 'Unlock';

  /// The reason line passed to the platform biometric prompt.
  static const String biometricReason = 'Unlock ArchiveMe';

  /// Emergency path — wipe local data without PIN (double confirmation).
  static const String emergencyWipeLabel = 'Delete all local archive data';
}