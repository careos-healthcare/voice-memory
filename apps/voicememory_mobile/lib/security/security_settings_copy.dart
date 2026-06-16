/// Security settings copy — one calm place for device protection, account
/// state, and data actions. Factual lines only: no encryption or sync
/// claims (neither is part of this surface), no fear, no overclaiming.
abstract class SecuritySettingsCopy {
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

  // Data actions.
  static const String wipeLocalArchive = 'Delete all local archive data';
  static const String wipeLocalArchiveBody =
      'Removes every reflection, draft, cached insight, and local recording '
      'on this device. This cannot be undone.';
  static const String wipeConfirmTitle = 'Delete all local data?';
  static const String wipeConfirmBody =
      'Type DELETE MY ARCHIVE to confirm. Your account on the server is not '
      'affected — only data stored on this device is removed.';
  static const String wipeConfirmHint = 'DELETE MY ARCHIVE';
  static const String hideInAppSwitcher = 'Hide ArchiveMe in app switcher';
  static const String hideInAppSwitcherBody =
      'Shows a lock screen preview instead of your archive when switching apps.';
}
