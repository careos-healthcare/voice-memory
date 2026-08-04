import 'pro_packaging_boundary_model.dart';

/// Pro packaging when users care but will not pay.
abstract final class ProPackagingCopyFix {
  ProPackagingCopyFix._();

  static const headline = 'Keep the longer trail.';

  static const subheadline =
      'Free helps you see the first useful repeat. Pro keeps the older evidence and change over time.';

  static const freeValue = 'Free: see the first useful repeat.';

  static const proValue =
      'Pro: keep older evidence, longer history, and change over time.';

  static const proofBridge = 'This is the kind of trail Pro keeps building.';

  static const whyPayLine =
      'Paying is not for more AI. It is for keeping the longer proof trail.';

  static const notMoreAiLine =
      'The value is not more AI. It is the longer proof trail.';

  static const unavailableHonestyLine =
      'Purchases are not available right now.';

  static const restoreLine = 'Restore purchases';

  static const longerTrailBullets = <String>[
    'Older evidence stays available',
    'Changes over time are easier to see',
    'Your archive can compare more than the first repeat',
  ];

  /// Legacy aliases used by existing bridge wiring.
  static const proPromise = 'Pro keeps the longer trail.';
  static const freeLine = 'Free helps you see the first useful repeat.';
  static const proLine =
      'Pro keeps older evidence, longer history, and change over time.';
  static const proofBridgeLine = proofBridge;

  static const List<String> bannedWords = [
    'therapy',
    'diagnosis',
    'treatment',
    'trauma',
    'healing',
    'mental health',
    'ai coach',
    'chatbot',
    'breakthrough',
    'unlimited coaching',
    'more ai',
    'cloud backup',
    'cross-device',
  ];

  static ProPackagingBoundary boundary() => const ProPackagingBoundary(
    freeItems: ['First useful repeat', 'First proof', 'Basic archive start'],
    proItems: [
      'Longer trail',
      'Older evidence',
      'Change over time',
      'Longer comparison history',
    ],
  );

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield subheadline;
    yield freeValue;
    yield proValue;
    yield proofBridge;
    yield whyPayLine;
    yield notMoreAiLine;
    yield unavailableHonestyLine;
    yield restoreLine;
    yield* longerTrailBullets;
    yield proPromise;
    yield freeLine;
    yield proLine;
    yield* boundary().freeItems;
    yield* boundary().proItems;
  }
}
