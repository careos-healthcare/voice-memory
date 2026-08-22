/// Copy for professional relationship consent management.
abstract final class RelationshipCopy {
  RelationshipCopy._();

  static const consentManagementTitle = 'Professional access';
  static const consentManagementIntro =
      'Manage which professionals can view scoped, read-only ArchiveMe data '
      'after you grant consent. You can change scopes or revoke access anytime.';

  static const addConnectionTitle = 'Connect a professional';
  static const inviteCodeHint = 'Invite code or professional email';
  static const addConnectionCta = 'Send connection request';

  static const noConnectionsTitle = 'No professionals connected';
  static const noConnectionsBody =
      'Add a professional using their invite code to start a consent request.';

  static const professionalDashboardTitle = 'Coach dashboard';
  static const professionalDashboardIntro =
      'Clients who granted consent appear here. All views are read-only.';

  static const noClientsTitle = 'No consenting clients yet';
  static const noClientsBody =
      'When a client grants you access, their scoped archive view will appear here.';

  static const perSeatRequiredTitle = 'Professional seat required';
  static const perSeatRequiredBody =
      'An active professional subscription seat is required to open the coach dashboard.';

  static const readOnlyClientTitle = 'Client archive (read-only)';
  static const revokeAccessCta = 'Revoke access';
  static const activateAccessCta = 'Activate access';

  static String relationshipStatusLabel(String wire) => switch (wire) {
        'pending' => 'Pending consent',
        'active' => 'Active',
        'revoked' => 'Revoked',
        _ => wire,
      };
}