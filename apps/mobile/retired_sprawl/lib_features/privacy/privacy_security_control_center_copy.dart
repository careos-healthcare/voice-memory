import 'package:archiveme_mobile/features/caregiver/caregiver_models.dart';

/// Copy for the Privacy & Security Control Center.
abstract final class PrivacySecurityControlCenterCopy {
  PrivacySecurityControlCenterCopy._();

  static const screenTitle = 'Privacy & Security';

  static const pillar3Heading = 'Encryption at rest';
  static const pillar4Heading = 'Caregiver access';

  static const encryptionActiveLabel = '256-Bit SQLCipher Encrypted';
  static const encryptionActiveBadge = 'Active';
  static const encryptionInactiveLabel = 'Encryption unavailable in this build';
  static const encryptionBody =
      'Your journal file on this device is encrypted. The database key '
      'stays in your device secure storage.';

  static const biometricTileTitle = 'Require biometrics to unlock database';
  static const biometricTileSubtitleEnabled =
      'Face ID, Touch ID, or your device passcode gates access to the '
      'encrypted database after backgrounding.';
  static const biometricTileSubtitleDisabled =
      'The database stays encrypted, but reopens without a biometric prompt '
      'after backgrounding.';
  static const biometricUnavailableSubtitle =
      'Biometric hardware is unavailable on this device. Device passcode '
      'may still be used when supported.';
  static const biometricStatusFaceId = 'Face ID';
  static const biometricStatusTouchId = 'Touch ID';
  static const biometricStatusBiometric = 'Biometrics';
  static const biometricStatusPasscode = 'Device passcode';

  static const caregiverSectionSubtitle =
      'Explicit, time-scoped grants. Revoke access at any time.';

  static const auditLogTitle = 'Access & Revocation Audit Log';
  static const auditLogEmpty = 'No access or revocation events recorded yet.';
  static const revokeAccessCta = 'Revoke Access';
  static const revokeAccessConfirmBody =
      'This immediately ends caregiver access for this grant. '
      'You can issue a new consent later if needed.';
  static const revokeSuccessSnack = 'Caregiver access revoked.';

  static const settingsEntryTitle = 'Privacy, Encryption & Caregiver Access';
  static const settingsEntrySubtitle =
      'SQLCipher status, biometric gate, and caregiver consent';

  static const whyAmISeeingThis = 'Why am I seeing this?';

  static const pillar3ExplanationTitle = 'Encryption at rest';
  static const pillar3ExplanationBody =
      'ArchiveMe stores your journal in a SQLCipher-encrypted SQLite file on '
      'this device. The encryption key stays in secure device storage. '
      'Optional biometrics add another gate before the database reopens '
      'after backgrounding — it does not replace file encryption.';

  static const pillar4ExplanationTitle = 'Caregiver access';
  static const pillar4ExplanationBody =
      'Caregiver or coach access requires your explicit consent, uses '
      'time-scoped tokens, and can be revoked here at any time. '
      'Revocation and access events are recorded in the audit log below '
      'without storing journal content.';

  static String auditActionLabel(CaregiverAuditAction action) =>
      switch (action) {
        CaregiverAuditAction.consentGranted => 'Access granted',
        CaregiverAuditAction.consentRevoked => 'Access revoked',
        CaregiverAuditAction.sessionStarted => 'Session started',
        CaregiverAuditAction.sessionValidated => 'Session validated',
        CaregiverAuditAction.sessionExpired => 'Session expired',
        CaregiverAuditAction.modeSwitched => 'Mode switched',
        CaregiverAuditAction.evidenceStreamRead => 'Evidence viewed',
        CaregiverAuditAction.reviewSummaryRead => 'Summary viewed',
        CaregiverAuditAction.thresholdAlertRead => 'Alert viewed',
        CaregiverAuditAction.dashboardViewed => 'Dashboard viewed',
        CaregiverAuditAction.accessDenied => 'Access denied',
      };
}
