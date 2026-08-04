import '../../product/core_product_vision.dart';

/// Copy for first-run revenue positioning — education only, no Pro CTA.
abstract final class FirstRunPositioningCopy {
  FirstRunPositioningCopy._();

  static const title = 'Your voice becomes your life story';

  static const body = CoreProductVision.valueProposition;

  static const footer =
      'Free shows the first useful proof. Pro keeps the longer proof trail.';

  static Iterable<String> allVisibleStrings() sync* {
    yield title;
    yield body;
    yield footer;
  }
}
