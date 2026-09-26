/// Launch switches for this beta.
///
/// Apple Health is the one health switch. On for this release.
abstract final class LaunchProfile {
  LaunchProfile._();

  static const bool APPLE_HEALTH = true;

  /// Passphrase-sealed journal sync. On for this release.
  static const bool E2EE_SYNC = true;

  /// Weekly encrypted copy of the journal and its media, kept on this device.
  static const bool AUTO_ENCRYPTED_BACKUP = true;
}
