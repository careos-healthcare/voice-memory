/// Price objection feedback copy — collect why users do not buy after Pro tap.
abstract final class PriceObjectionFeedbackCopy {
  PriceObjectionFeedbackCopy._();

  static const headline = 'Price objection feedback gate';

  static const body =
      'Collect why users do not buy after Pro tap without adding pricing experiments. '
      'Classification and interpretation only.';

  static const positioning =
      'Price objection feedback stays post-tap only — feeds paid-intent beta interpretation, not product changes.';

  static const promptTitle = 'What held you back?';

  static const promptSubtitle =
      'One tap helps us interpret paid-intent beta signals. No price changes.';

  static const skipLabel = 'Skip';

  static const thanksLine =
      'Thanks — noted for paid-intent beta interpretation.';

  static const reasonOrderLine =
      'Reasons: need stronger proof, too expensive, not clear what Pro keeps, not ready yet, '
      'wanted sync/backup, wanted reports, other.';

  static const orderLine =
      'Rules: show only after Pro tap without purchase, do not change price, do not add discounts, '
      'do not add new features, feed paid-intent beta interpretation only.';

  static const guardrail =
      'Price objection feedback gate collects why users do not buy after Pro tap without purchase. '
      'Show only after Pro tap without purchase. Do not change price. Do not add discounts. '
      'Do not add new features. Feed paid-intent beta interpretation only.';

  static const objectionFeedbackFrozenLine =
      'Keep price objection feedback hidden until Pro tap without purchase.';

  static const objectionFeedbackDocumentedLine =
      'Price objection feedback documented. Collect one-tap reasons after Pro tap without purchase only.';

  static const detailPass = 'Pass';
  static const detailFail = 'Fail';

  static const detailObjectionFeedbackFrozen =
      'Objection feedback frozen before Pro tap without purchase';
  static const detailObjectionFeedbackDocumented =
      'Objection feedback ready after Pro tap without purchase';

  static String labelFor(PriceObjectionReasonId id) => switch (id) {
    PriceObjectionReasonId.needStrongerProof => 'Need stronger proof',
    PriceObjectionReasonId.tooExpensive => 'Too expensive',
    PriceObjectionReasonId.notClearWhatProKeeps => 'Not clear what Pro keeps',
    PriceObjectionReasonId.notReadyYet => 'Not ready yet',
    PriceObjectionReasonId.wantedSyncBackup => 'Wanted sync/backup',
    PriceObjectionReasonId.wantedReports => 'Wanted reports',
    PriceObjectionReasonId.other => 'Other',
  };

  static String positioningFor(PriceObjectionReasonId id) => switch (id) {
    PriceObjectionReasonId.needStrongerProof =>
      'Need stronger proof — value not landed yet.',
    PriceObjectionReasonId.tooExpensive =>
      'Too expensive — price objection without discount experiments.',
    PriceObjectionReasonId.notClearWhatProKeeps =>
      'Not clear what Pro keeps — promise clarity gap.',
    PriceObjectionReasonId.notReadyYet =>
      'Not ready yet — timing objection, not product scope.',
    PriceObjectionReasonId.wantedSyncBackup =>
      'Wanted sync/backup — future-scope signal only.',
    PriceObjectionReasonId.wantedReports =>
      'Wanted reports — future-scope signal only.',
    PriceObjectionReasonId.other => 'Other — free-text bucket for beta notes.',
  };

  static String ruleLabelFor(PriceObjectionFeedbackRuleId id) => switch (id) {
    PriceObjectionFeedbackRuleId.showOnlyAfterProTapWithoutPurchase =>
      'Show only after Pro tap without purchase',
    PriceObjectionFeedbackRuleId.doNotChangePrice => 'Do not change price',
    PriceObjectionFeedbackRuleId.doNotAddDiscounts => 'Do not add discounts',
    PriceObjectionFeedbackRuleId.doNotAddNewFeatures =>
      'Do not add new features',
    PriceObjectionFeedbackRuleId.feedPaidIntentBetaInterpretationOnly =>
      'Feed paid-intent beta interpretation only',
  };

  static String messageFor(PriceObjectionFeedbackGateDecision decision) =>
      switch (decision) {
        PriceObjectionFeedbackGateDecision.objectionFeedbackFrozen =>
          objectionFeedbackFrozenLine,
        PriceObjectionFeedbackGateDecision.objectionFeedbackDocumented =>
          objectionFeedbackDocumentedLine,
      };

  static String recommendationFor(
    PriceObjectionFeedbackGateDecision decision,
  ) => switch (decision) {
    PriceObjectionFeedbackGateDecision.objectionFeedbackFrozen =>
      'Wait for Pro tap without purchase before surfacing objection feedback.',
    PriceObjectionFeedbackGateDecision.objectionFeedbackDocumented =>
      'Collect one-tap objection reasons for paid-intent beta interpretation only. Keep price, discounts, and features unchanged.',
  };

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield positioning;
    yield promptTitle;
    yield promptSubtitle;
    yield skipLabel;
    yield thanksLine;
    yield reasonOrderLine;
    yield orderLine;
    yield guardrail;
    yield objectionFeedbackFrozenLine;
    yield objectionFeedbackDocumentedLine;
    yield detailPass;
    yield detailFail;
    yield detailObjectionFeedbackFrozen;
    yield detailObjectionFeedbackDocumented;
    for (final id in PriceObjectionReasonId.values) {
      yield labelFor(id);
      yield positioningFor(id);
    }
    for (final id in PriceObjectionFeedbackRuleId.values) {
      yield ruleLabelFor(id);
    }
    for (final decision in PriceObjectionFeedbackGateDecision.values) {
      yield messageFor(decision);
      yield recommendationFor(decision);
    }
  }
}

enum PriceObjectionReasonId {
  needStrongerProof,
  tooExpensive,
  notClearWhatProKeeps,
  notReadyYet,
  wantedSyncBackup,
  wantedReports,
  other,
}

enum PriceObjectionFeedbackRuleId {
  showOnlyAfterProTapWithoutPurchase,
  doNotChangePrice,
  doNotAddDiscounts,
  doNotAddNewFeatures,
  feedPaidIntentBetaInterpretationOnly,
}

enum PriceObjectionFeedbackRuleStatus { pass, fail }

enum PriceObjectionFeedbackGateDecision {
  objectionFeedbackFrozen,
  objectionFeedbackDocumented,
}
