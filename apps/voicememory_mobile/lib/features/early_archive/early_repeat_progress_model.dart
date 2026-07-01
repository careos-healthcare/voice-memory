/// Stage of the first-three recording retention loop.
enum EarlyRepeatProgressKind {
  oneMoment,
  twoRelated,
  twoUnrelated,
}

/// Lightweight progress state for entryCount 1–2 on Record.
class EarlyRepeatProgressResult {
  const EarlyRepeatProgressResult({
    required this.kind,
    required this.title,
    required this.body,
    required this.progressLabel,
  });

  final EarlyRepeatProgressKind kind;
  final String title;
  final String body;
  final String progressLabel;

  bool get claimsRepeatForming => kind == EarlyRepeatProgressKind.twoRelated;
}
