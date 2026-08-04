/// Immutable identifiers of the established production application.
///
/// Native project files cannot import Dart, so focused release tests compare
/// every native declaration against these canonical values.
abstract final class ReleaseIdentity {
  static const appName = 'ArchiveMe';
  static const applicationId = 'com.voicememory.mobile';
  static const appGroupId = 'group.com.voicememory.mobile';
  static const sharedKeychainSuffix = 'com.voicememory.mobile.shared';
  static const primaryUrlScheme = 'archiveme';
}
