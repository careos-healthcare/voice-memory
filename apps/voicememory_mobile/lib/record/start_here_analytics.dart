import '../services/product_analytics.dart';

/// Start Here recording flow analytics.
abstract class StartHereAnalytics {
  StartHereAnalytics._();

  static Future<void> shown({required String surface}) {
    return ProductAnalytics.track(
      'start_here_shown',
      parameters: {'surface': surface},
    );
  }

  static Future<void> selected({
    required String promptText,
    required String surface,
    required String captureMode,
  }) {
    return ProductAnalytics.track(
      'start_here_selected',
      parameters: {
        'prompt_text': promptText,
        'surface': surface,
        'capture_mode': captureMode,
      },
    );
  }
}
