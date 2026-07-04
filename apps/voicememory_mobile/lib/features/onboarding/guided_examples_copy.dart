/// Copy for guided recording examples — style reference only, never saved.
abstract final class GuidedExamplesCopy {
  GuidedExamplesCopy._();

  static const title = 'Examples you can use as a guide';

  static const subtitle = 'Use the style, not the exact words.';

  static const useStyleCta = 'Use this style';

  static const typedCapturePrompt = 'Write your moment in your own words.';

  static String styleHelper(String example) =>
      '$subtitle\n\nExample style: "$example"';
}
