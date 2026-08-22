import 'package:archiveme_mobile/security/privacy_copy_policy.dart';

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
///   asserting a fixed one, and names no storage engine — the search index
///   lives outside the journal store.
///
/// The sensitive promise comes from [PrivacyCopyPolicy] so it stays worded in
/// one place.
abstract final class TrustBadgeCopy {
  TrustBadgeCopy._();

  static const onDeviceProcessing = 'Processing is on-device by default';

  static const onDeviceDetail =
      '${PrivacyCopyPolicy.nothingSentUnlessFeatureChosen} Choose '
      'transcription or sync and that audio and transcript text go to our '
      'servers for that job only.';

  static const storage = 'Storage protection is reported live';

  static const storageDetail =
      'Privacy settings report how this build protects your archive on this '
      'device, instead of asserting it here.';
}
