/// Muted trust indicators for archive and settings footers.
abstract final class TrustStatusFooterCopy {
  TrustStatusFooterCopy._();

  static const encryptedAtRest = 'Encrypted at Rest';
  static const processedOnDevice = 'Processed On-Device';

  /// Local journal storage and the encrypted SQLite vault on this device.
  static const encryptedSemanticLabel =
      'Encrypted at rest. Local journal storage and the SQLite vault are '
      'encrypted on this device.';

  /// On-device language model processing before any cloud fallback.
  static const onDeviceSemanticLabel =
      'Processed on-device. Local language models run on this device first.';
}
