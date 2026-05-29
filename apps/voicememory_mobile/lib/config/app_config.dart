/// Backend base URL — set at run time:
/// `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000`
///
/// Defaults (documented for dev):
/// - iOS Simulator / desktop: http://127.0.0.1:3000
/// - Android emulator host machine: http://10.0.2.2:3000
/// - Physical device: your LAN IP, e.g. http://192.168.1.10:3000
///
/// Never commit production secrets here.
class AppConfig {
  AppConfig._();

  static const String appName = 'VoiceMemory';
  static const String bundleId = 'com.voicememory.app';

  static const String defaultDevBaseUrl = 'http://127.0.0.1:3000';

  static String get apiBaseUrl {
    const fromEnv = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: defaultDevBaseUrl,
    );
    return fromEnv.endsWith('/')
        ? fromEnv.substring(0, fromEnv.length - 1)
        : fromEnv;
  }

  /// MVP: capture attest + transcribe + analyze + local journal.
  static const bool coreLoopEnabled = true;

  /// Session magic-link not wired in Flutter.
  static const bool authImplemented = false;

  static const bool nativeBillingImplemented = false;
  static const bool pushImplemented = false;
  static const bool serverJournalSyncImplemented = false;
  static const bool resurfacingImplemented = false;
}
