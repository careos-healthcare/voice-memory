import 'package:archiveme_mobile/security/privacy_claim_catalogue.dart';

/// Plain-language trust statements for the on-device trust badge.
///
/// The compact form of the statement in
/// `lib/features/settings/ui/on_device_architecture_copy.dart`, and it makes
/// the same two claims for the same reasons:
///
/// * on-device *by default*, not exclusively — `RemoteProcessingConsentStore`
///   gates real uploads to `/api/transcribe` and the sync endpoints, so the
///   badge describes remote work as a choice instead of denying it exists;
/// * storage protection is a runtime property of the build
///   (`SecureSqliteLockService.encryptionEnabled`, which has an "unavailable"
///   state), so this points at the live `EncryptionStatusCard` rather than
///   asserting a fixed one, and names no storage engine — the index that
///   searches the journal is SQLCipher tables in `archiveme.db`, while the
///   journal itself is an AES-GCM envelope from `EncryptedJsonFileStore`.
///
/// [onDeviceProcessing] and [storage] are also the titles of onboarding pillars
/// 2 and 3 (see `OnboardingV1Copy`, which aliases them). A single screen must
/// render `TrustBadge` or the pillars section, not both.
///
/// Both claims come from [PrivacyClaimCatalogue] so they stay worded in one
/// place. Only the two titles are this file's own.
abstract final class TrustBadgeCopy {
  TrustBadgeCopy._();

  static const onDeviceProcessing = 'Processing is on-device by default';

  static const onDeviceDetail =
      '${PrivacyClaimCatalogue.remoteProcessingIsAChoice} '
      '${PrivacyClaimCatalogue.remoteProcessingScopedToJob}';

  static const storage = 'Storage protection is reported live';

  static const storageDetail =
      '${PrivacyClaimCatalogue.momentsStayLocal} '
      '${PrivacyClaimCatalogue.storageProtectionReportedLive}';
}
