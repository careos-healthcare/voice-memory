/// Copy for professional coach tier — distinct from caregiver monitoring language.
abstract final class CoachCopy {
  CoachCopy._();

  static const consentTitle = 'Coach access consent';
  static const consentIntro =
      'Share selected archive insights with your coach for session planning. '
      'This is not monitoring — your coach sees read-only summaries you approve.';
  static const stepScopeTitle = 'Choose what your coach can see';
  static const stepReviewTitle = 'Review coach access';
  static const stepConfirmTitle = 'Confirm and sign consent';
  static const factLedgerLabel = 'Saved fact ledger details';
  static const confidenceInsightsLabel = 'Confidence-banded insights';
  static const beliefsLabel = 'Beliefs';
  static const blindSpotsLabel = 'Blind spots';
  static const contradictionsLabel = 'Contradictions';
  static const affirmationCheckbox =
      'I explicitly authorize this coach access. I understand I can revoke it anytime.';
  static const grantAccessCta = 'Grant coach access';
  static const continueCta = 'Continue';
  static const backCta = 'Back';
  static const verificationFailedMessage =
      'Consent verification failed. Try again.';
  static const dashboardTitle = 'Coach session planning';
  static const dashboardSubtitle =
      'Read-only evidence organized for your next session — no alerts or monitoring.';
  static const readOnlyBadge = 'Read-only · Coach tier';
  static const noSessionMessage =
      'No verified coach session. Complete client consent first.';
  static const switchToSelfCta = 'Exit coach mode';
  static const emptySectionMessage = 'Nothing in this section yet.';
  static const auditNotice =
      'Coach access is logged locally. Raw transcripts are never exported.';
  static const localConversationPrivacyNotice =
      'Offline coach replies use only journals stored on this device.';
  static const localConversationEmptyContext =
      'No indexed journal excerpts yet — capture a reflection first.';
  static const accountClientConsentTitle = 'Share with coach';
  static const accountClientConsentSubtitle =
      'Grant read-only access to insights you choose';
  static const accountCoachDashboardTitle = 'Coach dashboard';
  static const accountCoachDashboardSubtitle =
      'Read-only session planning for verified coach access';
}