import 'package:archiveme_mobile/features/caregiver/caregiver_models.dart';
import 'package:archiveme_mobile/security/privacy_claim_catalogue.dart';
import 'package:archiveme_mobile/security/privacy_copy_policy.dart';

/// Copy for the Privacy & Security Control Center.
abstract final class PrivacySecurityControlCenterCopy {
  PrivacySecurityControlCenterCopy._();

  static const screenTitle = PrivacyClaimCatalogue.privacyAndSecurityTitle;

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

  // A revoke CTA, a two-stage confirmation body, and a confirmed/queued snack
  // pair used to live here. This screen has never had a revoke control: it
  // links to `/caregiver-access`, which owns the grant list and its revoke
  // action, so nothing read any of them. They were the third parallel set of
  // revocation wording in the app, after `CaregiverAccessCopy` on the screen
  // that actually revokes and `ConsentAuditCopy` on the audit trail, and the
  // only one of the three that no user could reach — while
  // `docs/security/CAREGIVER_ACCESS_PRELAUNCH_BLOCKERS.md` cited this set as
  // the disclosure that already describes the two-stage revoke. Wording for a
  // control belongs next to the control; put it back here only if this screen
  // grows one.

  static const settingsEntryTitle = 'Privacy, Encryption & Caregiver Access';
  static const settingsEntrySubtitle =
      'SQLCipher status, biometric gate, and caregiver consent';

  static const whyAmISeeingThis = 'Why am I seeing this?';

  /// The expansion repeats the pillar's own heading, so it aliases it rather
  /// than retyping it — one heading, one place to change it.
  static const pillar3ExplanationTitle = pillar3Heading;

  /// The baseline comes from [PrivacyCopyPolicy] rather than being described
  /// again here. This block used to say the journal lived in a
  /// "SQLCipher-encrypted SQLite file", which names the wrong store: the
  /// journal is an AES-GCM envelope written by `EncryptedJsonFileStore` on
  /// every platform, and SQLCipher covers `archiveme.db`, the index that
  /// searches it, only on iOS and Android.
  static const pillar3ExplanationBody =
      '${PrivacyCopyPolicy.encryptionBaselineDetail} '
      'Optional biometrics add another gate before the database reopens '
      'after backgrounding. That gate sits on top of the protection '
      'described here rather than replacing it.';

  static const pillar4ExplanationTitle = pillar4Heading;

  /// Said access "can be revoked here at any time" while this screen had no
  /// revoke control and never has — revoking is on `/caregiver-access`, which
  /// the link in this section opens. The lifetime is the one the server
  /// declares: `CAREGIVER_CONSENT_DEFAULT_TTL_MS` in
  /// `packages/shared/lib/consent/consent-token-ttl.ts`, 7 days, which
  /// `CaregiverGrantCopy.stopPassLifetime` states in words on the grant
  /// screen. The audit-log sentence points at `AccessRevocationAuditLogView`,
  /// which does render directly below this section, and it records
  /// [auditActionLabel] values only.
  static const pillar4ExplanationBody =
      'Caregiver or coach access requires your explicit consent and uses '
      'time-scoped tokens. You can end a grant at any time from the caregiver '
      'access screen linked in this section. Revocation and access events are '
      'recorded in the audit log below without storing journal content.';

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
