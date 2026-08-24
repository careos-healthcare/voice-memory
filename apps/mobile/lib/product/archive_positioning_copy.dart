import 'package:archiveme_mobile/features/landing_continuity/landing_app_continuity_copy.dart';

/// Public ArchiveMe positioning — umbrella brand with capacity-yes as first path.
abstract final class ArchivePositioningCopy {
  ArchivePositioningCopy._();

  // ——— Public umbrella (landing alignment v1) ———
  static const String umbrellaHeadline = LandingAppContinuityCopy.hero;
  static const String umbrellaShort = LandingAppContinuityCopy.subheadline;
  static const String umbrellaBody = LandingAppContinuityCopy.heroBody;

  // ——— First guided path (capacity yes) ———
  static const firstPathLabel = 'Start with one pattern';
  static const firstPathHeadline = 'Saying yes when you have no capacity';
  static const firstPathIntro =
      'Start with one pattern — saying yes when you have no capacity.';
  static const firstPathBody =
      'Use this first path before you agree, right after you agree, or when '
      'the cost shows up later.';
  static const capacityPathContext =
      'This is the first path in your private timeline.';
  static const capacityTimingFlex =
      'You can save it before you agree, right after, or when the cost shows '
      'up later.';
  static const wedgeHeadline = 'Catch the yes before it costs you.';
  static const capacityCta = 'Start with yes moments';
  static const mapLine =
      'Every saved moment adds to the same private timeline.';

  // ——— First-use onboarding (capacity start) ———
  static const String firstUseTitle = LandingAppContinuityCopy.hero;
  static const firstUseBody =
      'Save one real moment when something stands out. ArchiveMe helps you '
      'see what returned over time.';
  static const firstUseFirstPath =
      'Start with saying yes when you have no capacity.';
  static const firstUseTimingMicro =
      'You can save it before, after, or when the cost shows up later.';
  static const firstUseCta = 'Save first moment';
  static const howItWorksCta = 'See how it works';
  static const List<String> howItWorksSteps = [
    LandingAppContinuityCopy.step1Title,
    'Choose what pulled you in',
    LandingAppContinuityCopy.step2Title,
    LandingAppContinuityCopy.step3Title,
  ];

  // ——— Generic CTAs ———
  static const genericCta = 'Start your archive';
  static const recordAnyMoment = 'Record any moment';
  static const quickYesMoment = 'Quick yes moment';
  static const quickCaptureTimingFlex =
      'Use this before, after, or when the cost shows up later.';

  // ——— Before / after / later yes capture ———
  static const beforeLabel = 'Before';
  static const beforeBody = 'I am about to say yes.';
  static const afterLabel = 'After';
  static const afterBody = 'I just said yes.';
  static const laterLabel = 'Later';
  static const laterBody = 'That yes cost me something.';
  static const yesCaptureModesIntro =
      'Save before you agree, right after, or when the cost shows up later — '
      'all feed the same private timeline.';

  static const List<String> yesCaptureTimingLabels = [
    beforeLabel,
    afterLabel,
    laterLabel,
  ];

  static const List<String> yesCaptureTimingBodies = [
    beforeBody,
    afterBody,
    laterBody,
  ];

  static List<String> allVisibleStrings() => [
    umbrellaHeadline,
    umbrellaShort,
    umbrellaBody,
    firstPathLabel,
    firstPathHeadline,
    firstPathIntro,
    firstPathBody,
    capacityPathContext,
    capacityTimingFlex,
    wedgeHeadline,
    capacityCta,
    genericCta,
    recordAnyMoment,
    quickYesMoment,
    quickCaptureTimingFlex,
    firstUseTitle,
    firstUseBody,
    firstUseFirstPath,
    firstUseTimingMicro,
    firstUseCta,
    howItWorksCta,
    ...howItWorksSteps,
    mapLine,
    yesCaptureModesIntro,
    ...yesCaptureTimingLabels,
    ...yesCaptureTimingBodies,
  ];

  /// Public/general surfaces scanned by positioning tests.
  static const publicSurfacePaths = [
    'lib/product/archive_positioning_copy.dart',
    'lib/product/acquisition_start_copy.dart',
    'lib/features/settings/screens/about_screen.dart',
    'packages/archiveme_research/lib/screens/loop_start_screen.dart',
    'lib/features/demo/sample_archive_copy.dart',
    'docs/APP_STORE_COPY.md',
    'docs/PLAY_STORE_COPY.md',
    'docs/BETA_TESTER_MESSAGE.md',
    'docs/CAPACITY_YES_POSITIONING_ONE_PAGER.md',
    'docs/CAPACITY_YES_LANDING_PAGE_COPY.md',
  ];
}