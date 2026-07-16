/// Copy for longer archive memory Pro boundaries — display/gating only.
abstract final class ProMemoryBoundaryCopy {
  ProMemoryBoundaryCopy._();

  static const upgradeBridgeTitle = 'ArchiveMe Pro';
  static const upgradeBridgeBody =
      'Free keeps recent proof. Pro keeps the longer proof trail — older evidence and longer archive history.';
  static const seeProCta = 'See Pro';
  static const notNowCta = 'Not now';

  static const freeHistoryLine =
      'Free keeps recent proof and the first useful repeat.';

  static const proHistoryLine =
      'Pro keeps the longer proof trail — older evidence and longer archive history.';

  static const weeklyReviewPreviewTitle = 'Preview of your weekly review';
  static const weeklyReviewPreviewBody =
      'Free shows what repeated recently. Pro keeps the longer proof trail over time.';

  static const olderEvidenceTitle = 'Older evidence moments';
  static const olderEvidenceBody =
      'Free keeps recent proof. Pro shows older evidence in the longer proof trail.';

  static const privateReportPreviewTitle = 'Private report preview';
  static const privateReportPreviewBody =
      'Private reports are planned — coming after Pro proof. Not part of the V1 purchase promise.';

  static const offeringsUnavailableBody =
      'Monthly and yearly plans will appear when App Store products finish loading.';

  static Iterable<String> allVisibleCopy() sync* {
    yield freeHistoryLine;
    yield proHistoryLine;
    yield upgradeBridgeTitle;
    yield upgradeBridgeBody;
    yield seeProCta;
    yield notNowCta;
    yield weeklyReviewPreviewTitle;
    yield weeklyReviewPreviewBody;
    yield olderEvidenceTitle;
    yield olderEvidenceBody;
    yield privateReportPreviewTitle;
    yield privateReportPreviewBody;
    yield offeringsUnavailableBody;
  }
}
