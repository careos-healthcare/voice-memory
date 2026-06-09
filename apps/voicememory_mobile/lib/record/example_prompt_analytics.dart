import '../services/product_analytics.dart';

/// First-recording conversation starter analytics.
abstract final class ExamplePromptAnalytics {
  ExamplePromptAnalytics._();

  static Future<void> shown({required String surface}) {
    return ProductAnalytics.track(
      'example_prompt_shown',
      parameters: {'surface': surface},
    );
  }

  static Future<void> tapped({
    required String promptText,
    required String surface,
    required String captureMode,
  }) {
    return ProductAnalytics.track(
      'example_prompt_tapped',
      parameters: {
        'prompt_text': promptText,
        'surface': surface,
        'capture_mode': captureMode,
      },
    );
  }
}
