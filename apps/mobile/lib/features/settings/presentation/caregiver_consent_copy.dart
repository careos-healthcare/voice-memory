/// Copy for Settings → Caregiver Access & Consent.
///
/// The requested panel asked for mood trends, crisis alerts, and
/// caregiver-requested check-ins, plus a banner that called recordings and
/// transcripts "100% private and on this phone". Those controls and that
/// absolute are not this product:
///
/// * a caregiver grant shows the opening words of recent moments
///   (`CaregiverGrantCopy.canSeeRecent`), not summarized trend alerts;
/// * audio stays on this phone; transcripts can leave if the user opts into
///   a remote feature (`RemoteProcessingConsentStore`);
/// * mood and sentiment trends were removed from the UI — there is no working
///   share bit;
/// * `thresholdAlerts` exists on retired consent types and is defaulted true
///   on `CaregiverPermissions.defaultScopes`, but no reachable screen offers
///   that choice, so an ON switch would invent consent;
/// * caregivers cannot request check-ins in this build.
///
/// Master and revoke map to `CaregiverGrantFlow` and
/// `MultiPartyAccessService.revokeGrant`. The granular rows are labels, not
/// switches. Status uses the live grant display name — never a hard-coded
/// person.
abstract final class CaregiverConsentCopy {
  CaregiverConsentCopy._();

  static const String settingsTileTitle = 'Caregiver Access & Consent';

  static const String settingsTileSubtitle =
      'Grant access, see what is shared, and revoke it on this device';

  static const String screenTitle = 'Caregiver Access & Consent';

  /// Accurate replacement for the requested "summarized trend alerts" /
  /// "100% private" banner.
  static const String banner =
      'If you grant access, a caregiver can see the opening words of your '
      'recent moments. They cannot play your original audio or export the '
      'database from this app. Journal entries stay on this phone unless you '
      'choose a remote feature.';

  static const String masterTitle = 'Enable Caregiver Access';

  static const String statusOff = 'Not Connected';

  static const String statusOnAnonymous = 'Connected';

  static const String sharingOptionsHeading = 'Additional sharing';

  static const String moodTitle = 'Share Daily Mood & Sentiment Trends';

  static const String unavailableInThisVersion = 'Not available in this version.';

  static const String moodBody =
      '$unavailableInThisVersion This build does not compute or share mood '
      'or sentiment trends.';

  static const String alertsTitle =
      'Send Automatic Crisis / Disorientation Alerts';

  static const String alertsBody =
      '$unavailableInThisVersion This build has no reachable control for '
      'crisis or disorientation alerts.';

  static const String checkInsTitle = 'Allow Caregiver to Request Check-ins';

  static const String checkInsBody =
      '$unavailableInThisVersion Caregivers cannot request check-ins in '
      'this build.';

  static const String revokeCta = 'Revoke All Caregiver Access';

  static const String revokeDisabled =
      'No active caregiver grant to revoke on this device.';

  static const String revokeConfirmTitle = 'Revoke caregiver access?';

  static const String revokeConfirmBody =
      'This takes effect on this device right away. Turning access off here '
      'also tells our server to stop honouring the pass. If you are offline, '
      'we finish that as soon as you reconnect.';

  static const String revokeCancel = 'Cancel';

  static String statusOn({required List<String> partyLabels}) {
    final names = [
      for (final label in partyLabels)
        if (label.trim().isNotEmpty) label.trim(),
    ];
    if (names.isEmpty) return statusOnAnonymous;
    return 'Connected to ${names.join(', ')}';
  }
}
