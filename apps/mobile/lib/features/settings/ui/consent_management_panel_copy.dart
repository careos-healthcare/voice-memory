/// Copy for settings consent management — user control over multi-party access.
abstract final class ConsentManagementPanelCopy {
  ConsentManagementPanelCopy._();

  static const sectionTitle = 'Shared access';
  static const helperText =
      'Every grant is HMAC-signed and verified by the server before anyone '
      'can view your archive. You can revoke access instantly — no one keeps '
      'access unless you explicitly allow it.';
  static const emptyMessage =
      'No active caregiver or observer grants on this device.';
  static const revokeAccessCta = 'Revoke Access';
  static const revokeConfirmTitle = 'Revoke access?';
  static const revokeConfirmBody =
      'This immediately ends access for this grant. They will need a new '
      'signed consent from you to view anything again.';
  static const revokeSuccessSnack = 'Access revoked.';
  static const grantedLabel = 'Granted';
  static const expiresLabel = 'Expires';
  static const roleLabel = 'Role';
  static const currentSessionBadge = 'Active now';
}
