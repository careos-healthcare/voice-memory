/// Pro promise copy audit copy — align paid messaging with one trail promise.
abstract final class ProPromiseCopyAuditCopy {
  ProPromiseCopyAuditCopy._();

  static const headline = 'Pro promise copy audit';

  static const body =
      'Free shows the first useful proof. Pro keeps the longer proof trail. '
      'Find and neutralize copy that promises something else.';

  static const preferredFreeLine = 'Free shows the first useful proof.';

  static const preferredProLine = 'Pro keeps the longer proof trail over time.';

  static const preferredContinuityLine =
      'Track what returns, changes, fades, or gets corrected.';

  static const conflictFullTimelineLine =
      'Replace full-timeline promises with longer proof trail language.';

  static const conflictLongerStoryLine =
      'Replace longer-story promises with proof-trail continuity language.';

  static const conflictMoreAiLine =
      'Remove more-AI promises. Pro keeps the trail, not more chat.';

  static const conflictMoreFeaturesLine =
      'Remove feature-volume promises. Pro is one continuity promise.';

  static const conflictReportsLine =
      'Do not make reports the primary Pro promise.';

  static const conflictDashboardLine =
      'Do not make dashboards the primary Pro promise.';

  static const conflictStorageLine =
      'Do not sell storage or backup as the Pro promise.';

  static const conflictRankingLine =
      'Do not sell ranking or importance scoring as the Pro promise.';

  static const alignedLine = 'Copy aligns with the single Pro promise.';

  static const reviewLine =
      'Review Pro copy for trail continuity language before shipping.';

  static const guardrail =
      'Copy guard only. Do not change paywall mechanics, RevenueCat, products, '
      'pricing, entitlements, or purchase flow.';

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield preferredFreeLine;
    yield preferredProLine;
    yield preferredContinuityLine;
    yield conflictFullTimelineLine;
    yield conflictLongerStoryLine;
    yield conflictMoreAiLine;
    yield conflictMoreFeaturesLine;
    yield conflictReportsLine;
    yield conflictDashboardLine;
    yield conflictStorageLine;
    yield conflictRankingLine;
    yield alignedLine;
    yield reviewLine;
  }
}