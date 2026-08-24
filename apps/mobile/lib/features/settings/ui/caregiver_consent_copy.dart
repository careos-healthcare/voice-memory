/// Copy for Settings → Caregiver Access & Permissions.
///
/// The brief asked for a permission panel with mood trends, crisis alerts,
/// and caregiver-requested check-ins, plus a banner that called journal
/// entries "strictly local". Those controls and that absolute are not this
/// product:
///
/// * a caregiver grant shows the opening words of recent moments
///   (`CaregiverGrantCopy.canSeeRecent`), not full recordings or a database
///   export (`CaregiverSessionGuard` on this device);
/// * audio is local; the journal is local-first with opt-in remote features
///   (`RemoteProcessingConsentStore`), so "strictly local" would be false;
/// * mood and sentiment trends were removed from the UI — there is no working
///   share bit;
/// * `thresholdAlerts` exists on retired consent types and is defaulted true
///   on `CaregiverPermissions.defaultScopes`, but no reachable screen offers
///   that choice, so an ON switch would invent consent;
/// * caregivers cannot request check-ins in this build.
///
/// Master and revoke map to `CaregiverGrantFlow` and
/// `MultiPartyAccessService.revokeGrant`. The granular rows are labels, not
/// switches.
abstract final class CaregiverConsentCopy {
  CaregiverConsentCopy._();

  static const String settingsTileTitle = 'Caregiver Consent & Sharing';

  static const String settingsTileSubtitle =
      'Grant access, see what is shared, and revoke it on this device';

  static const String screenTitle = 'Caregiver Access & Permissions';

  /// Accurate replacement for the requested "strictly local" banner.
  static const String banner =
      'If you grant access, a caregiver can see the opening words of your '
      'recent moments. They cannot play your original audio or export the '
      'database from this app. Journal entries stay on this phone unless you '
      'choose a remote feature.';

  static const String masterTitle = 'Enable Caregiver Access';

  static const String statusOff =
      'Not connected. Turning this on starts the grant steps on this device.';

  static const String statusOnAnonymous =
      'Caregiver access is on for an active grant on this device.';

  static const String sharingOptionsHeading = 'Additional sharing';

  static const String moodTitle = 'Share Daily Mood & Sentiment Trends';

  static const String moodBody =
      'Not available in this version. This build does not compute or share '
      'mood or sentiment trends.';

  static const String alertsTitle =
      'Send Automatic Crisis / Disorientation Alerts';

  static const String alertsBody =
      'Not available in this version. This build has no reachable control '
      'for crisis or disorientation alerts.';

  static const String checkInsTitle = 'Allow Caregiver to Request Check-ins';

  static const String checkInsBody =
      'Not available in this version. Caregivers cannot request check-ins '
      'in this build.';

  static const String revokeCta = 'Revoke Caregiver Access';

  static const String revokeDisabled =
      'No active caregiver grant to revoke on this device.';

  static const String revokeConfirmTitle = 'Revoke caregiver access?';

  static const String revokeConfirmBody =
      'This takes effect on this device right away. Turning access off here '
      'also tells our server to stop honouring the pass. If you are offline, '
      'we finish that as soon as you reconnect.';

  static const String revokeCancel = 'Cancel';

  static String statusOn({required List<String> partyLabels}) {
    if (partyLabels.isEmpty) return statusOnAnonymous;
    return 'Connected on this device: ${partyLabels.join(', ')}.';
  }
}
