/// User-facing copy for caregiver monitoring flows.
abstract final class CaregiverCopy {
  CaregiverCopy._();

  static const dashboardTitle = 'Caregiver monitoring';
  // Says what this device refuses, not just what this view omits. The export
  // surfaces, the sealed backup, capture, and both audio playback paths run
  // `CaregiverSessionGuard` and deny a caregiver session — and deny again when
  // the persona cannot be read. The manual local-backup share does not, and no
  // server checks the session role at all, so keep the device scope in the
  // sentence.
  static const dashboardSubtitle =
      'Read-only summaries and alerts for the categories the archive owner '
      'approved. On this device, recording, exporting, and playing back the '
      'original audio are refused while this session is active.';

  static const consentTitle = 'Share archive access';
  static const consentIntro =
      'Choose which summary categories a trusted caregiver may view. The '
      'caregiver view shows counts, short labels, and summaries — not the '
      'recording or its full text.';

  static const stepScopeTitle = 'Choose what to share';
  static const stepReviewTitle = 'Review permissions';
  static const stepConfirmTitle = 'Confirm and sign';

  static const evidenceTrailLabel = 'Evidence trail';
  static const timelineSummariesLabel = 'Timeline summaries';
  static const thresholdAlertsLabel = 'Priority insight alerts';

  static const activeAccessLabel = 'Active access';
  static const accessLogLabel = 'Access history';
  static const revokeAccessCta = 'Revoke access';
  static const noActiveAccessMessage = 'No active caregiver grants on this device.';
  static const emptyAccessLogMessage = 'No access events recorded yet.';
  static const grantedAtLabel = 'Granted';
  static const expiresAtLabel = 'Expires';
  static const currentSessionBadge = 'Current session';

  static const readOnlyBadge = 'Read-only';
  static const auditNotice =
      'Every view is logged locally on this device for transparency.';

  static const grantAccessCta = 'Grant caregiver access';
  static const continueCta = 'Continue';
  static const backCta = 'Back';
  static const switchToSelfCta = 'Return to personal mode';
  static const enterMonitoringCta = 'Enter monitoring view';

  static const noSessionMessage =
      'Monitoring access requires a verified consent token.';
  static const sessionExpiredMessage =
      'Caregiver access has expired. Complete consent again to continue.';
  static const verificationFailedMessage =
      'Consent token could not be verified. Check the token and try again.';

  static const emptyEvidenceMessage =
      'No shared evidence yet. The archive owner can record moments first.';
}