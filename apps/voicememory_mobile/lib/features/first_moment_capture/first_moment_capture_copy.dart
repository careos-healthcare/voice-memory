import 'first_moment_capture_model.dart';

/// Zero-entry first save copy — tiny, private, impossible to get wrong.
abstract final class FirstMomentCaptureCopy {
  FirstMomentCaptureCopy._();

  static const coreStart = 'Start with one sentence.';

  static const coreAnythingCounts = 'Anything from today counts.';

  static const coreArchiveSense =
      'ArchiveMe only starts making sense after a few real moments.';

  static const title = 'Start with one sentence';

  static const body =
      'Anything from today counts. A thought, decision, win, worry, memory, conversation, pressure, reaction, or random moment.';

  static const reassurance = 'You do not need to know the pattern yet.';

  static const privacyLine = 'Private by default. You can delete it later.';

  static const primaryCta = 'Save one sentence';

  static const secondaryCta = 'Record instead';

  static const keptPuttingOffExample = 'I kept putting this off.';
  static const feltHeavierExample = 'That felt heavier than expected.';
  static const somethingHelpedExample = 'Something helped a little.';
  static const dontWantToForgetExample = 'I do not want to forget this.';

  static const exampleOrder = [
    FirstMomentCaptureExampleType.keptPuttingOff,
    FirstMomentCaptureExampleType.feltHeavier,
    FirstMomentCaptureExampleType.somethingHelped,
    FirstMomentCaptureExampleType.dontWantToForget,
  ];

  static String exampleTextFor(FirstMomentCaptureExampleType type) =>
      switch (type) {
        FirstMomentCaptureExampleType.keptPuttingOff => keptPuttingOffExample,
        FirstMomentCaptureExampleType.feltHeavier => feltHeavierExample,
        FirstMomentCaptureExampleType.somethingHelped => somethingHelpedExample,
        FirstMomentCaptureExampleType.dontWantToForget =>
          dontWantToForgetExample,
      };

  static List<String> allVisibleStrings() => [
        coreStart,
        coreAnythingCounts,
        coreArchiveSense,
        title,
        body,
        reassurance,
        privacyLine,
        primaryCta,
        secondaryCta,
        keptPuttingOffExample,
        feltHeavierExample,
        somethingHelpedExample,
        dontWantToForgetExample,
      ];
}
