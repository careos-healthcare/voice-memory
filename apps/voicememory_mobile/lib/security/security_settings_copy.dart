/// Security settings copy — one calm place for device protection, account
/// state, and data actions. Factual lines only: no encryption or sync
/// claims (neither is part of this surface), no fear, no overclaiming.
abstract final class SecuritySettingsCopy {
  SecuritySettingsCopy._();

  static const String title = 'Security';
  static const String subtitle =
      'Control how ArchiveMe protects this device and your account.';

  // Sections.
  static const String appLockSection = 'App lock';
  static const String accountSection = 'Account';
  static const String dataSection = 'Data';

  // App lock status.
  static const String statusOn = 'On';
  static const String statusOff = 'Off';

  // Account status and actions.
  static const String signedIn = 'Signed in';
  static const String notSignedIn = 'Not signed in';
  static const String signIn = 'Sign in';
  static const String createAccount = 'Create account';
  static const String signOut = 'Sign out';
}
