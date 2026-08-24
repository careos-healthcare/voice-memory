/// Copy for Settings → Caregiver Access & Permissions.
///
/// The requested panel used a banner that called recordings and transcripts
/// "100% private and on this phone". That absolute is false: the user can
/// opt into remote transcription, and a caregiver grant shows the opening
/// words of recent moments — not summarized trend alerts.
///
/// Heather is a preview fixture (`previewConnectedName`), not a linked user.
/// Granular mood / emergency-alert / check-in rows are local screen controls
/// and do not grant those shares.
abstract final class CaregiverConsentCopy {
  CaregiverConsentCopy._();

  static const String settingsTileTitle = 'Caregiver Access & Permissions';

  static const String settingsTileSubtitle =
      'Grant access, see what is shared, and revoke it on this device';

  static const String screenTitle = 'Caregiver Access & Permissions';

  /// Accurate replacement for the requested trend-alert / "100% private" banner.
  static const String banner =
      'If you grant access, a caregiver can see the opening words of your '
      'recent moments. Raw audio stays on this phone. They cannot play your '
      'original recording or export the database from this app. Journal '
      'entries stay on this phone unless you choose a remote feature.';

  static const String masterTitle = 'Enable Caregiver Sharing';

  static const String statusOff = 'Sharing disabled';

  static const String statusOnAnonymous = 'Sharing enabled';

  static const String previewConnectedName = 'Heather';

  static const String previewConnectedRole = 'Primary Caregiver';

  static const String moodTitle = 'Share Daily Mood & Sentiment Trends';

  static const String moodBody =
      'Local preview on this screen. This switch does not grant mood sharing.';

  static const String alertsTitle = 'Send Emergency Alerts';

  static const String alertsBody =
      'Local preview on this screen. This switch does not grant emergency '
      'alerts.';

  static const String checkInsTitle = 'Allow Check-in Requests';

  static const String checkInsBody =
      'Local preview on this screen. This switch does not grant check-in '
      'requests.';

  static const String sharingPermissions = 'Sharing Permissions';

  static const String revokeCta = 'Revoke All Caregiver Access';

  static const String revokeConfirmTitle = 'Revoke Caregiver Access?';

  /// Production dialog — generic caregiver, never a preview fixture name.
  static const String revokeConfirmBody =
      'This will immediately stop sharing with your caregiver. '
      'You can re-enable access at any time.';

  static const String revokeCancel = 'Cancel';

  static const String revokeConfirmAction = 'Revoke';

  /// Preview-only dialog. Mentions [previewConnectedName]; do not use in Settings.
  static String get revokeConfirmBodyPreview =>
      'This will immediately stop all data sharing with $previewConnectedName. '
      'You can re-enable access at any time.';

  static String revokeConfirmBodyFor({required bool previewMode}) {
    return previewMode ? revokeConfirmBodyPreview : revokeConfirmBody;
  }

  static String connectedStatus({
    String? caregiverDisplayName,
    String? caregiverRole,
  }) {
    final name = caregiverDisplayName?.trim() ?? '';
    if (name.isEmpty) return statusOnAnonymous;
    final role = caregiverRole?.trim() ?? '';
    if (role.isEmpty) return 'Connected to $name';
    return 'Connected to $name ($role)';
  }

  static String get previewConnectedStatus => connectedStatus(
        caregiverDisplayName: previewConnectedName,
        caregiverRole: previewConnectedRole,
      );
}
