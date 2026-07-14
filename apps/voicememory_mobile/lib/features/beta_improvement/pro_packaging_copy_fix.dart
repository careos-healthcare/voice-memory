/// Pro packaging when users care but will not pay.
abstract final class ProPackagingCopyFix {
  ProPackagingCopyFix._();

  static const proPromise = 'Pro keeps the longer trail.';

  static const freeLine =
      'Free helps you see the first useful repeat.';

  static const proLine =
      'Pro keeps older evidence, longer history, and change over time.';

  static const proofBridgeLine =
      'This is the kind of trail Pro keeps building.';

  static Iterable<String> allVisibleStrings() sync* {
    yield proPromise;
    yield freeLine;
    yield proLine;
    yield proofBridgeLine;
  }
}
