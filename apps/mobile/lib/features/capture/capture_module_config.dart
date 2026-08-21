/// Runtime SQLite + storage paths shared with the background capture isolate.
class CaptureModuleRuntimeConfig {
  CaptureModuleRuntimeConfig({
    required this.sqliteFilePath,
    this.encryptionPassword,
    this.keyAlias,
  });

  static CaptureModuleRuntimeConfig? _instance;

  static CaptureModuleRuntimeConfig? get instance => _instance;

  static set instance(CaptureModuleRuntimeConfig? value) => _instance = value;

  final String sqliteFilePath;
  final String? encryptionPassword;
  final String? keyAlias;
}

/// Deep-link and widget URI constants for instant capture.
abstract final class CaptureDeepLinkUris {
  CaptureDeepLinkUris._();

  static const scheme = 'archiveme';
  static const recordHost = 'record';
  static const recordUri = '$scheme://$recordHost';

  static const recordRoute = '/record';

  static const recordQueryParameters = <String, String>{
    'autostart': '1',
    'instant': '1',
    'background': '1',
  };

  static String get recordLaunchRoute => Uri(
        path: recordRoute,
        queryParameters: recordQueryParameters,
      ).toString();
}
