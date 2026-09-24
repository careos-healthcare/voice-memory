/// Safe sharing future copy — future growth sharing without private text leak.
abstract final class SafeSharingFutureCopy {
  SafeSharingFutureCopy._();

  static const headline = 'Safe sharing future gate';

  static const body =
      'Allow future growth sharing only if private text cannot leak. '
      'Classification and documentation only.';

  static const positioning =
      'Future growth sharing stays explicit and privacy-safe — product insight only, '
      'never raw archive content by default. Not a V1 growth loop.';

  static const orderLine =
      'Rules: no raw private text by default, explicit user share/export, product insight not archive content, '
      'no first-five-minute sharing, no sharing before first useful proof, no live V1 sharing expansion, '
      'no share-to-unlock, no clinical framing, no assessment-style claims.';

  static const prereqOrderLine =
      'Prerequisites: first useful proof seen and paid-intent beta complete.';

  static const guardrail =
      'Safe sharing future gate classifies future growth sharing only. Never share raw private text by default. '
      'Explicit user share or export action required. Share product insight, not archive content. '
      'No sharing in first five minutes or before first useful proof. No new live V1 sharing UI.';

  static const sharingFrozenLine =
      'Keep growth sharing frozen until first useful proof and paid-intent beta proof are complete. '
      'Sharing is not a V1 growth loop.';

  static const futureGrowthSharingDocumentedLine =
      'Proof and beta complete. Document growth sharing as future-only — explicit, product insight, no raw private text leak.';

  static const detailPass = 'Pass';
  static const detailPending = 'Pending';
  static const detailFail = 'Fail';

  static const detailBlockedBeforeSharingProof = 'Blocked before sharing proof';
  static const detailFutureGrowthSharingDocumented =
      'Future growth sharing documented only';

  static String prereqLabelFor(SafeSharingFuturePrereqId id) => switch (id) {
    SafeSharingFuturePrereqId.firstUsefulProofSeen => 'First useful proof seen',
    SafeSharingFuturePrereqId.paidIntentBetaComplete =>
      'Paid-intent beta complete',
  };

  static String ruleLabelFor(SafeSharingFutureRuleId id) => switch (id) {
    SafeSharingFutureRuleId.noRawPrivateTextByDefault =>
      'No raw private text by default',
    SafeSharingFutureRuleId.explicitUserShareOrExport =>
      'Explicit user share or export',
    SafeSharingFutureRuleId.shareProductInsightNotArchive =>
      'Share product insight, not archive content',
    SafeSharingFutureRuleId.noSharingInFirstFiveMinutes =>
      'No sharing in first five minutes',
    SafeSharingFutureRuleId.noSharingBeforeFirstUsefulProof =>
      'No sharing before first useful proof',
    SafeSharingFutureRuleId.noLiveV1SharingExpansion =>
      'No live V1 sharing expansion',
  };

  static String messageFor(SafeSharingFutureGateDecision decision) =>
      switch (decision) {
        SafeSharingFutureGateDecision.sharingFrozen => sharingFrozenLine,
        SafeSharingFutureGateDecision.futureGrowthSharingDocumented =>
          futureGrowthSharingDocumentedLine,
      };

  static String recommendationFor(
    SafeSharingFutureGateDecision decision,
  ) => switch (decision) {
    SafeSharingFutureGateDecision.sharingFrozen =>
      'Do not expand sharing until first useful proof and beta proof complete. Keep sharing explicit and product-only.',
    SafeSharingFutureGateDecision.futureGrowthSharingDocumented =>
      'Document growth sharing as future-only. Never share raw private text by default and never before proof.',
  };

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield positioning;
    yield orderLine;
    yield prereqOrderLine;
    yield guardrail;
    yield sharingFrozenLine;
    yield futureGrowthSharingDocumentedLine;
    yield detailPass;
    yield detailPending;
    yield detailFail;
    yield detailBlockedBeforeSharingProof;
    yield detailFutureGrowthSharingDocumented;
    for (final id in SafeSharingFuturePrereqId.values) {
      yield prereqLabelFor(id);
    }
    for (final id in SafeSharingFutureRuleId.values) {
      yield ruleLabelFor(id);
    }
    for (final decision in SafeSharingFutureGateDecision.values) {
      yield messageFor(decision);
      yield recommendationFor(decision);
    }
  }
}

enum SafeSharingFuturePrereqId { firstUsefulProofSeen, paidIntentBetaComplete }

enum SafeSharingFuturePrereqStatus { pass, pending, fail }

enum SafeSharingFutureRuleId {
  noRawPrivateTextByDefault,
  explicitUserShareOrExport,
  shareProductInsightNotArchive,
  noSharingInFirstFiveMinutes,
  noSharingBeforeFirstUsefulProof,
  noLiveV1SharingExpansion,
}

enum SafeSharingFutureRuleStatus { pass, fail }

enum SafeSharingFutureGateDecision {
  sharingFrozen,
  futureGrowthSharingDocumented,
}
