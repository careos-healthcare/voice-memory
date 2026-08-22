/// Return tomorrow ritual copy — future retention without daily homework.
abstract final class ReturnTomorrowRitualCopy {
  ReturnTomorrowRitualCopy._();

  static const headline = 'Return tomorrow ritual gate';

  static const body =
      'Prepare a future retention ritual without making daily homework. '
      'Classification and documentation only.';

  static const positioning =
      'Return-tomorrow ritual stays future retention positioning — observational, optional, no pressure.';

  static const allowedLanguageLine =
      'Allowed: "Watch this tomorrow", "Did this come back?", "Save another moment only if it really returned".';

  static const orderLine =
      'Blocked categories: streaks, homework framing, mandatory check-ins, recording pressure, habit tracking.';

  static const guardrail =
      'Return tomorrow ritual gate classifies future retention only. Allowed language stays observational and optional. Do not add streaks, daily homework, required check-ins, pressure to record, or habit tracker language. No new live V1 UI.';

  static const ritualFrozenLine =
      'Keep return-tomorrow ritual frozen until paid-intent beta proof is complete.';

  static const futureRetentionDocumentedLine =
      'Beta proof complete. Document return-tomorrow ritual as future retention only — not daily homework and not new live V1 UI.';

  static const detailPass = 'Pass';
  static const detailFail = 'Fail';

  static const detailRitualFrozen = 'Ritual frozen before beta proof';
  static const detailFutureRetentionDocumented =
      'Future retention documented only';

  static String ruleLabelFor(ReturnTomorrowRitualRuleId id) => switch (id) {
    ReturnTomorrowRitualRuleId.allowedLanguageDocumented =>
      'Allowed language documented',
    ReturnTomorrowRitualRuleId.noBlockedRetentionPressure =>
      'No blocked retention pressure',
    ReturnTomorrowRitualRuleId.futureRetentionOnly => 'Future retention only',
    ReturnTomorrowRitualRuleId.noNewLiveV1Ui => 'No new live V1 UI',
  };

  static String messageFor(ReturnTomorrowRitualGateDecision decision) =>
      switch (decision) {
        ReturnTomorrowRitualGateDecision.ritualFrozen => ritualFrozenLine,
        ReturnTomorrowRitualGateDecision.futureRetentionDocumented =>
          futureRetentionDocumentedLine,
      };

  static String recommendationFor(
    ReturnTomorrowRitualGateDecision decision,
  ) => switch (decision) {
    ReturnTomorrowRitualGateDecision.ritualFrozen =>
      'Keep return-tomorrow language observational. Do not add streaks, homework, or recording pressure.',
    ReturnTomorrowRitualGateDecision.futureRetentionDocumented =>
      'Document return-tomorrow ritual as future retention only. Keep allowed language optional and calm.',
  };

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield positioning;
    yield allowedLanguageLine;
    yield orderLine;
    yield guardrail;
    yield ritualFrozenLine;
    yield futureRetentionDocumentedLine;
    yield detailPass;
    yield detailFail;
    yield detailRitualFrozen;
    yield detailFutureRetentionDocumented;
    for (final id in ReturnTomorrowRitualRuleId.values) {
      yield ruleLabelFor(id);
    }
    for (final decision in ReturnTomorrowRitualGateDecision.values) {
      yield messageFor(decision);
      yield recommendationFor(decision);
    }
  }
}

enum ReturnTomorrowRitualRuleId {
  allowedLanguageDocumented,
  noBlockedRetentionPressure,
  futureRetentionOnly,
  noNewLiveV1Ui,
}

enum ReturnTomorrowRitualRuleStatus { pass, fail }

enum ReturnTomorrowRitualGateDecision {
  ritualFrozen,
  futureRetentionDocumented,
}