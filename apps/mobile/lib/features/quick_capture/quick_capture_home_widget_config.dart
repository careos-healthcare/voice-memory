/// Names and URIs for the home-screen quick-capture widget and desktop shortcut.
abstract final class QuickCaptureHomeWidgetConfig {
  QuickCaptureHomeWidgetConfig._();

  static const appGroupId = 'group.com.voicememory.mobile';
  static const androidProvider = 'QuickCaptureWidgetProvider';
  static const iosWidgetName = 'QuickCaptureWidget';
  static const desktopArgument = '--quick-capture';
  static const uriScheme = 'archiveme';
  static const uriHost = 'quick-capture';
  static const widgetTextKey = 'quick_capture_text';

  static Uri uriForText(String text) {
    return Uri(
      scheme: uriScheme,
      host: uriHost,
      queryParameters: {'text': text},
    );
  }

  static String? textFromUri(Uri? uri) {
    if (uri == null) return null;
    if (uri.scheme != uriScheme || uri.host != uriHost) return null;
    final text = uri.queryParameters['text']?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  /// Desktop shortcut form: `--quick-capture=saved moment`.
  static String? textFromDesktopArguments(List<String> args) {
    final prefix = '$desktopArgument=';
    for (final arg in args) {
      if (!arg.startsWith(prefix)) continue;
      final text = arg.substring(prefix.length).trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }
}
