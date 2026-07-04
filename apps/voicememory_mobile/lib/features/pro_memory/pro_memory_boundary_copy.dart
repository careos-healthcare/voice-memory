/// Copy for longer archive memory Pro boundaries — display/gating only.
abstract final class ProMemoryBoundaryCopy {
  ProMemoryBoundaryCopy._();

  static const upgradeBridgeTitle = 'Go deeper with ArchiveMe Pro';
  static const upgradeBridgeBody =
      'Keep a longer view of what repeats, what changes, and what helps.';
  static const seeProCta = 'See Pro';
  static const notNowCta = 'Not now';

  static const weeklyReviewPreviewTitle = 'Preview of your weekly review';
  static const weeklyReviewPreviewBody =
      'Free shows what repeated. Pro unlocks the full weekly review.';

  static const olderEvidenceTitle = 'Older evidence moments';
  static const olderEvidenceBody =
      'Free keeps your first proof moments. Pro shows the full evidence trail.';

  static const privateReportPreviewTitle = 'Private report preview';
  static const privateReportPreviewBody =
      'Free shows a preview. Pro unlocks the full private report and export.';

  static const offeringsUnavailableBody =
      'Plans are temporarily unavailable. You can still use ArchiveMe.';

  static Iterable<String> allVisibleCopy() sync* {
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
