/// App Lock — all consumer-facing copy in one place. Calm, factual lines
/// only: no fear, no overclaiming, no security theater.
abstract final class AppLockCopy {
  AppLockCopy._();

  // Security settings.
  static const String settingsTitle = 'App lock';
  static const String settingsBody = 'Protect ArchiveMe with a PIN.';
  static const String settingsBiometricsLabel =
      'Use Face ID or Touch ID when available.';
  static const String settingsChangePin = 'Change PIN';
  static const String settingsTurnOff = 'Turn off app lock';

  // PIN setup.
  static const String setupTitle = 'Create a PIN';
  static const String setupBody = 'Use this to unlock ArchiveMe on this device.';
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
}
