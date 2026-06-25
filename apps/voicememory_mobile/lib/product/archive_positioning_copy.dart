/// Public ArchiveMe positioning — umbrella brand with capacity-yes as first path.
abstract final class ArchivePositioningCopy {
  ArchivePositioningCopy._();

  // ——— Public umbrella ———
  static const umbrellaHeadline =
      'A private mind map of what keeps repeating.';
  static const umbrellaBody =
      'Save real moments. ArchiveMe connects them into patterns, changes, '
      'and next things to watch.';

  // ——— First guided path (capacity yes) ———
  static const capacityPathLabel = 'Start with one pattern';
  static const capacityPathHeadline = 'Saying yes when you have no capacity';
  static const capacityPathBody =
      'Use the first path to catch the yes before it costs you — before, '
      'after, or when the cost shows up later.';
  static const capacityPathContext =
      'This is the first path in your private pattern map.';
  static const capacityWedgeHeadline = 'Catch the yes before it costs you.';
  static const capacityCta = 'Start with yes moments';

  // ——— Generic CTAs ———
  static const genericCta = 'Start your map';
  static const recordAnyMoment = 'Record any moment';
  static const quickYesMoment = 'Quick yes moment';

  // ——— Before / after / later yes capture ———
  static const beforeYesCaptureLabel = 'Before yes';
  static const beforeYesCaptureBody = 'I am about to say yes';
  static const afterYesCaptureLabel = 'After yes';
  static const afterYesCaptureBody = 'I just said yes';
  static const laterCostCaptureLabel = 'Later cost';
  static const laterCostCaptureBody = 'That yes cost me something';
  static const yesCaptureModesIntro =
      'Save before you agree, right after, or when the cost shows up later — '
      'all feed the same pattern map.';

  static const List<String> yesCaptureModeLabels = [
    beforeYesCaptureLabel,
    afterYesCaptureLabel,
    laterCostCaptureLabel,
  ];

  static const List<String> yesCaptureModeBodies = [
    beforeYesCaptureBody,
    afterYesCaptureBody,
    laterCostCaptureBody,
  ];

  static List<String> allVisibleStrings() => [
        umbrellaHeadline,
        umbrellaBody,
        capacityPathLabel,
        capacityPathHeadline,
        capacityPathBody,
        capacityPathContext,
        capacityWedgeHeadline,
        capacityCta,
        genericCta,
        recordAnyMoment,
        quickYesMoment,
        yesCaptureModesIntro,
        ...yesCaptureModeLabels,
        ...yesCaptureModeBodies,
      ];

  /// Public/general surfaces scanned by positioning tests.
  static const publicSurfacePaths = [
    'lib/product/archive_positioning_copy.dart',
    'lib/product/acquisition_start_copy.dart',
    'lib/screens/about_screen.dart',
    'lib/screens/loop_start_screen.dart',
    'lib/features/demo/sample_archive_copy.dart',
    'docs/APP_STORE_COPY.md',
    'docs/PLAY_STORE_COPY.md',
    'docs/BETA_TESTER_MESSAGE.md',
  ];
}
