import 'archive_positioning_copy.dart';

/// Loop-specific acquisition start screen copy — no banned language.
abstract class AcquisitionStartCopy {
  AcquisitionStartCopy._();

  static const String capacityTitle = ArchivePositioningCopy.wedgeHeadline;
  static const String capacityPathContext =
      ArchivePositioningCopy.capacityPathContext;
  static const String capacityTimingFlex =
      ArchivePositioningCopy.capacityTimingFlex;
  static const String capacityBody =
      'ArchiveMe helps you spot why you keep agreeing before checking your capacity.';
  static const List<String> capacitySteps = [
    'Save a yes moment',
    'See what pulled you in',
    'Review what changed',
  ];
  static const String capacityProductLine = ArchivePositioningCopy.umbrellaBody;
  static const String capacityFirstPathLine =
      ArchivePositioningCopy.firstPathIntro;
  static const String capacityStartCta = 'Save yes moment';
  static const String capacityHowItWorksCta = 'How it works';
  static const String capacityHowItWorksBody =
      ArchivePositioningCopy.yesCaptureModesIntro;

  static const String proveTitle =
      'Catch the moment you do more to feel enough';
  static const String proveBody =
      'Record a short moment. ArchiveMe will help you test whether the proving-enough loop keeps repeating.';
  static const String genericTitle = ArchivePositioningCopy.umbrellaHeadline;
  static const String genericFirstPathLine =
      ArchivePositioningCopy.firstPathIntro;
  static const String genericBody = ArchivePositioningCopy.umbrellaBody;

  static const String startLoopCta = 'Start this loop';
  static const String startGenericCta = ArchivePositioningCopy.genericCta;
  static const String chooseAnotherLoop = 'Choose another loop';

  static List<String> capacityVisibleStrings() => [
        capacityTitle,
        capacityPathContext,
        capacityTimingFlex,
        capacityFirstPathLine,
        capacityBody,
        ...capacitySteps,
        capacityProductLine,
        capacityStartCta,
        capacityHowItWorksCta,
        capacityHowItWorksBody,
      ];
}
