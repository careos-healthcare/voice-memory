/// Factual copy for Settings → Privacy & Security infrastructure guarantees.
///
/// Avoids unsupported claims (no "zero-knowledge", no "military-grade").
/// See [docs/security/SQLCIPHER_KEY_MODEL.md] for the key-derivation model.
abstract final class PrivacySecurityTrustCopy {
  PrivacySecurityTrustCopy._();

  static const sectionTitle = 'Privacy & Security';

  static const encryptedAtRestTitle = 'Encrypted on this device';
  static const encryptedAtRestBody =
      'Your journal file on this device is encrypted with SQLCipher. '
      'Opening ArchiveMe can require Face ID or Touch ID.';

  static const onDeviceProcessingTitle = 'On-device by default';
  static const onDeviceProcessingBody =
      'Voice transcription and analysis run on your device first. '
      'Cloud processing is only used as a rare fallback when local '
      'confidence is low — unless you turn on Never send to server.';

  static const caregiverAccessTitle = 'Consent-based sharing';
  static const caregiverAccessBody =
      'Caregiver or coach access requires your explicit consent, '
      'is time-scoped, and can be revoked at any time.';

  static const linkSecuritySettings = 'App lock & security settings';
  static const linkOnDeviceToggle = 'Never send to server setting';
  static const linkCaregiverAccess = 'Manage caregiver access';
}
