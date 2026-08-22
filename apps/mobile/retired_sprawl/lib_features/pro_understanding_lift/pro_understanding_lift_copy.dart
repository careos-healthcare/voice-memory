/// Pro understanding lift copy — metadata-safe, no journal text.
abstract final class ProUnderstandingLiftCopy {
  ProUnderstandingLiftCopy._();

  static const title = 'What Pro actually keeps';
  static const body =
      'Free shows the first proof. Pro keeps the timeline after that — what returns, what changes, what fades, and what you corrected.';
  static const primaryCta = 'See the Pro timeline';
  static const secondaryCta = 'Not now';
  static const supportLine =
      'This is not more chat. It is the record behind the pattern.';

  static const bulletFree = 'Free: the first useful proof';
  static const bulletPro = 'Pro: the longer evidence trail';
  static const bulletControl = 'You stay in control: delete or correct entries';

  static const List<String> bullets = [bulletFree, bulletPro, bulletControl];

  static const diagnosisFixFirstSessionCapture = 'Fix first-session capture';
  static const diagnosisFixProUnderstanding = 'Fix Pro understanding';
  static const diagnosisReadyForMoreTesters = 'Ready for more testers';

  static Iterable<String> allVisibleStrings() sync* {
    yield title;
    yield body;
    yield primaryCta;
    yield secondaryCta;
    yield supportLine;
    yield bulletFree;
    yield bulletPro;
    yield bulletControl;
    yield diagnosisFixFirstSessionCapture;
    yield diagnosisFixProUnderstanding;
    yield diagnosisReadyForMoreTesters;
  }
}

enum ProUnderstandingLiftSurface {
  recordReady,
  recordPostSave,
  archivePatterns,
}

extension ProUnderstandingLiftSurfaceStorage on ProUnderstandingLiftSurface {
  String get analyticsValue => switch (this) {
    ProUnderstandingLiftSurface.recordReady => 'record_ready',
    ProUnderstandingLiftSurface.recordPostSave => 'record_post_save',
    ProUnderstandingLiftSurface.archivePatterns => 'archive_patterns',
  };
}