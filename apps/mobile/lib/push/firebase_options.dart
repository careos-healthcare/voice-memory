/// Dart-define presence check kept so release identity tests still have a
/// config file. No Firebase options object is built, and startup never
/// starts an SDK.
class FirebaseOptionsConfig {
  static bool get isConfigured {
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    return apiKey.isNotEmpty && appId.isNotEmpty && projectId.isNotEmpty;
  }

  static Object? get currentPlatform => null;
}
