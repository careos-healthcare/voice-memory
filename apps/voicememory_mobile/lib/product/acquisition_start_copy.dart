/// Loop-specific acquisition start screen copy — no banned language.
abstract class AcquisitionStartCopy {
  AcquisitionStartCopy._();

  static const String capacityTitle = 'See why you keep saying yes.';
  static const String capacityBody =
      'Save real moments where you felt pulled to agree. '
      'After 3 moments, ArchiveMe helps you review what repeated. '
      'Private on this device.';
  static const String capacityStartCta = 'Save yes moment';

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
        capacityStartCta,
      ];
}
