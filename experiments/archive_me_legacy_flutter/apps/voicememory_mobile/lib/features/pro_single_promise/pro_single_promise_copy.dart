/// Pro single-promise copy — keep the longer proof trail, not feature volume.
abstract final class ProSinglePromiseCopy {
  ProSinglePromiseCopy._();

  static const headline = 'Keep the longer proof trail';

  static const body =
      'Free shows the first useful proof. Pro keeps tracking what happens after — '
      'whether the repeat returns, changes, fades, or gets corrected.';

  static const freeLine = 'Free: first useful proof.';

  static const proLine = 'Pro: longer proof trail.';

  static const whyPayLine =
      'You are paying to keep seeing what happens to the same repeat over time.';

  static const notMoreAiLine =
      'Pro is not more chat or more AI. It keeps the trail.';

  static const notStorageLine =
      'Pro is not extra storage. It preserves the evidence trail.';

  static const notFeatureListLine =
      'No long feature list. The promise is simple: keep the trail.';

  static const valueLine =
      'The value is continuity — seeing what your archive proves later.';

  static const guardrail =
      'Pro messaging must stay focused on keeping the longer proof trail, not more '
      'AI, storage, dashboards, rankings, reports, or feature volume.';

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield freeLine;
    yield proLine;
    yield whyPayLine;
    yield notMoreAiLine;
    yield notStorageLine;
    yield notFeatureListLine;
    yield valueLine;
  }
}
