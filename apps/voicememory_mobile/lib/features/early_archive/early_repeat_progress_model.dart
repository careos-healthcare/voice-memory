/// Stage of the first-three recording retention loop.
enum EarlyRepeatProgressKind {
  oneMoment,
  twoRelated,
  twoUnrelated,
}

/// Quiet next-moment guidance below the progress line on Record.
class EarlyRepeatNextMomentCue {
  const EarlyRepeatNextMomentCue({
    required this.label,
    required this.body,
    required this.footer,
  });

  final String label;
  final String body;
  final String footer;
}

/// Lightweight progress state for entryCount 1–2 on Record.
class EarlyRepeatProgressResult {
  const EarlyRepeatProgressResult({
    required this.kind,
    required this.title,
    required this.body,
    required this.progressLabel,
    required this.nextMomentCue,
  });

  final EarlyRepeatProgressKind kind;
  final String title;
  final String body;
  final String progressLabel;
  final EarlyRepeatNextMomentCue nextMomentCue;

  bool get claimsRepeatForming => kind == EarlyRepeatProgressKind.twoRelated;
}
