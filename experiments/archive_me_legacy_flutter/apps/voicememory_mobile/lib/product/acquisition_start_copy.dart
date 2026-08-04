import 'archive_positioning_copy.dart';

/// Loop-specific acquisition start screen copy — no banned language.
abstract class AcquisitionStartCopy {
  AcquisitionStartCopy._();

  static const String capacityTitle = ArchivePositioningCopy.firstUseTitle;
  static const String capacityBody = ArchivePositioningCopy.firstUseBody;
  static const String capacityFirstPathLabel = 'First path';
  static const String capacityFirstPathHeadline =
      ArchivePositioningCopy.firstUseFirstPath;
  static const String capacityTimingFlex =
      ArchivePositioningCopy.firstUseTimingMicro;
  static const String capacityStartCta = ArchivePositioningCopy.firstUseCta;
  static const String capacityHowItWorksCta =
      ArchivePositioningCopy.howItWorksCta;
  static const List<String> capacityHowItWorksSteps =
      ArchivePositioningCopy.howItWorksSteps;

  static const String proveTitle =
      'Catch the moment you do more to feel enough';
  static const String proveBody =
      'Record a short moment. ArchiveMe will help you test whether the proving-enough loop keeps returning.';
  static const String genericTitle = ArchivePositioningCopy.umbrellaHeadline;
  static const String genericFirstPathLine =
      ArchivePositioningCopy.firstPathIntro;
  static const String genericBody = ArchivePositioningCopy.umbrellaBody;

  static const String startLoopCta = 'Start this loop';
  static const String startGenericCta = ArchivePositioningCopy.genericCta;
  static const String chooseAnotherLoop = 'Choose another loop';

  static List<String> capacityVisibleStrings() => [
    capacityTitle,
    capacityBody,
    capacityFirstPathLabel,
    capacityFirstPathHeadline,
    capacityTimingFlex,
    capacityStartCta,
    capacityHowItWorksCta,
    ...capacityHowItWorksSteps,
  ];
}
