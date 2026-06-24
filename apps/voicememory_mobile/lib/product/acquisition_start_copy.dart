/// Loop-specific acquisition start screen copy — no banned language.
abstract class AcquisitionStartCopy {
  AcquisitionStartCopy._();

  static const String capacityTitle = 'Catch the yes before it costs you.';
  static const String capacityBody =
      'ArchiveMe helps you spot why you keep agreeing before checking your capacity.';
  static const List<String> capacitySteps = [
    'Save a yes moment',
    'See what pulled you in',
    'Review what changed',
  ];
  static const String capacityProductLine =
      'ArchiveMe is a private archive for patterns that repeat.';
  static const String capacityStartCta = 'Save yes moment';
  static const String capacityHowItWorksCta = 'How it works';
  static const String capacityHowItWorksBody =
      'Save real yes moments when they happen. Mark what pulled you toward yes. '
      'After a few moments, review what keeps repeating — privately on this device.';

  static const String proveTitle =
      'Catch the moment you do more to feel enough';
  static const String proveBody =
      'Record a short moment. ArchiveMe will help you test whether the proving-enough loop keeps repeating.';
  static const String genericTitle = 'ArchiveMe remembers what keeps repeating';
  static const String genericBody =
      'Record short moments. ArchiveMe looks for loops that repeat, change, or fade.';

  static const String startLoopCta = 'Start this loop';
  static const String startGenericCta = 'Start';
  static const String chooseAnotherLoop = 'Choose another loop';

  static List<String> capacityVisibleStrings() => [
        capacityTitle,
        capacityBody,
        ...capacitySteps,
        capacityProductLine,
        capacityStartCta,
        capacityHowItWorksCta,
        capacityHowItWorksBody,
      ];
}
