/// User-facing copy for caregiver monitoring flows.
abstract final class CaregiverCopy {
  CaregiverCopy._();

  static const dashboardTitle = 'Caregiver monitoring';
  static const dashboardSubtitle =
      'Read-only view of shared evidence and alerts. You cannot record or edit '
      'on behalf of the archive owner.';

  static const consentTitle = 'Share archive access';
  static const consentIntro =
      'Choose what a trusted caregiver may view. They will not be able to '
      'record, edit, or export raw transcripts.';

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