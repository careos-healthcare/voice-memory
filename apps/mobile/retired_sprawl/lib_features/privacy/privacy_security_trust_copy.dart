import 'package:archiveme_mobile/security/privacy_claim_catalogue.dart';
import 'package:archiveme_mobile/security/privacy_copy_policy.dart';

/// Factual copy for Settings → Privacy & Security infrastructure guarantees.
///
/// Avoids unsupported claims (no "zero-knowledge", no "military-grade").
/// See [docs/security/SQLCIPHER_KEY_MODEL.md] for the key-derivation model.
///
/// The two sensitive claims come from [PrivacyCopyPolicy] rather than being
/// worded again here, because both were previously wrong in this file:
///
/// * encryption at rest named SQLCipher as the journal's protection. It is
///   not: `JournalStore` writes an AES-GCM envelope through
///   `EncryptedJsonFileStore` on every platform, while SQLCipher covers
///   `archiveme.db` — the index that searches the journal — and only on iOS
///   and Android (`SqliteDatabaseInitializer.encryptionEnabled`);
/// * on-device processing described cloud work as an automatic "rare
///   fallback". Nothing is sent automatically. `CaptureProofAnalyzer
///   .isPurposeGranted` returns false while `OnDeviceProcessingStore.enabled`
///   is set, which it is by default, and otherwise defers to
///   `RemoteProcessingConsentStore`, whose unset state is `consented: false`.
///   A user who declined at onboarding was being told their data went to the
///   cloud anyway.
abstract final class PrivacySecurityTrustCopy {
  PrivacySecurityTrustCopy._();

  static const sectionTitle = PrivacyClaimCatalogue.privacyAndSecurityTitle;

  static const encryptedAtRestTitle = PrivacyCopyPolicy.encryptedAtRestScoped;
  static const encryptedAtRestBody =
      '${PrivacyCopyPolicy.encryptionBaselineDetail} '
      'Opening ArchiveMe can require Face ID or Touch ID.';

  static const onDeviceProcessingTitle =
      PrivacyClaimCatalogue.onDeviceByDefaultHeading;
  static const onDeviceProcessingBody =
      '${PrivacyClaimCatalogue.remoteProcessingIsAChoice} '
      'Remote processing is off until you turn it on, and transcription and '
      'reflection are granted separately.';

  static const caregiverAccessTitle = 'Consent-based sharing';
  static const caregiverAccessBody =
      'Caregiver or coach access requires your explicit consent, '
      'is time-scoped, and can be revoked at any time.';

  static const linkSecuritySettings = 'App lock & security settings';
  static const linkOnDeviceToggle = 'Never send to server setting';
  static const linkCaregiverAccess = 'Manage caregiver access';
}
