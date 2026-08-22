/// Tiny example starters — not evidence classification.
enum FirstMomentCaptureExampleType {
  keptPuttingOff,
  feltHeavier,
  somethingHelped,
  dontWantToForget,
}

enum FirstMomentCaptureActionType { saveOneSentence, recordInstead }

/// Card payload for zero-entry first save guidance.
class FirstMomentCaptureResult {
  const FirstMomentCaptureResult({
    required this.shouldShow,
    required this.title,
    required this.body,
    required this.reassurance,
    required this.privacyLine,
    required this.primaryCta,
    required this.secondaryCta,
    required this.examples,
    required this.entryCount,
    required this.source,
  });

  final bool shouldShow;
  final String title;
  final String body;
  final String reassurance;
  final String privacyLine;
  final String primaryCta;
  final String secondaryCta;
  final List<FirstMomentCaptureExample> examples;
  final int entryCount;
  final String source;
}

class FirstMomentCaptureExample {
  const FirstMomentCaptureExample({required this.type, required this.text});

  final FirstMomentCaptureExampleType type;
  final String text;
}