/// Contradiction change future copy — future premium change detection only.
abstract final class ContradictionChangeFutureCopy {
  ContradictionChangeFutureCopy._();

  static const headline = 'Contradiction change future gate';

  static const body =
      'Document future premium change detection without adding V1 feature scope. '
      'Classification and documentation only.';

  static const positioning =
      'Contradiction change detection stays future premium positioning — evidence-led, correctable, no directive framing.';

  static const futureValueLine =
      'Future value: "You used to say this.", "Now your saved moments show something different.", '
      '"This repeat may be changing.".';

  static const orderLine =
      'Blocked categories: clinical-label framing, directive language, forecast language.';

  static const prereqOrderLine =
      'Prerequisites: strong proof trail complete and paid-intent beta complete.';

  static const guardrail =
      'Contradiction change future gate classifies future premium change detection only. '
      'Requires strong proof trail before surfacing. Correction allowed. '
      'Do not add clinical-label, directive, or forecast language. No new live V1 UI.';

  static const changeFrozenLine =
      'Keep contradiction change detection frozen until strong proof trail and paid-intent beta proof are complete.';

  static const futureChangeDetectionDocumentedLine =
      'Proof trail and beta proof complete. Document contradiction change detection as future premium only — '
      'not in V1 UI.';

  static const detailPass = 'Pass';
  static const detailPending = 'Pending';
  static const detailFail = 'Fail';

  static const detailBlockedBeforeProofTrail = 'Blocked before proof trail proof';
  static const detailFutureChangeDetectionDocumented =
      'Future change detection documented only';

  static String prereqLabelFor(ContradictionChangeFuturePrereqId id) =>
      switch (id) {
        ContradictionChangeFuturePrereqId.strongProofTrailComplete =>
          'Strong proof trail complete',
        ContradictionChangeFuturePrereqId.paidIntentBetaComplete =>
          'Paid-intent beta complete',
      };

  static String ruleLabelFor(ContradictionChangeFutureRuleId id) => switch (id) {
        ContradictionChangeFutureRuleId.futureValueLanguageDocumented =>
          'Future value language documented',
        ContradictionChangeFutureRuleId.strongProofTrailRequired =>
          'Strong proof trail required',
        ContradictionChangeFutureRuleId.correctionAllowed => 'Correction allowed',
        ContradictionChangeFutureRuleId.noClinicalLabelFraming =>
          'No clinical-label framing',
        ContradictionChangeFutureRuleId.noCoachingLanguage => 'No directive language',
        ContradictionChangeFutureRuleId.noForecastLanguage => 'No forecast language',
        ContradictionChangeFutureRuleId.noNewLiveV1Ui => 'No new live V1 UI',
      };

  static String messageFor(ContradictionChangeFutureGateDecision decision) =>
      switch (decision) {
        ContradictionChangeFutureGateDecision.changeFrozen => changeFrozenLine,
        ContradictionChangeFutureGateDecision.futureChangeDetectionDocumented =>
          futureChangeDetectionDocumentedLine,
      };

  static String recommendationFor(ContradictionChangeFutureGateDecision decision) =>
      switch (decision) {
        ContradictionChangeFutureGateDecision.changeFrozen =>
          'Finish strong proof trail and paid-intent beta before documenting contradiction change detection.',
        ContradictionChangeFutureGateDecision.futureChangeDetectionDocumented =>
          'Document contradiction change as future premium only. Keep copy observational, correctable, and proof-led.',
      };

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield positioning;
    yield futureValueLine;
    yield orderLine;
    yield prereqOrderLine;
    yield guardrail;
    yield changeFrozenLine;
    yield futureChangeDetectionDocumentedLine;
    yield detailPass;
    yield detailPending;
    yield detailFail;
    yield detailBlockedBeforeProofTrail;
    yield detailFutureChangeDetectionDocumented;
    for (final id in ContradictionChangeFuturePrereqId.values) {
      yield prereqLabelFor(id);
    }
    for (final id in ContradictionChangeFutureRuleId.values) {
      yield ruleLabelFor(id);
    }
    for (final decision in ContradictionChangeFutureGateDecision.values) {
      yield messageFor(decision);
      yield recommendationFor(decision);
    }
  }
}

enum ContradictionChangeFuturePrereqId {
  strongProofTrailComplete,
  paidIntentBetaComplete,
}

enum ContradictionChangeFuturePrereqStatus {
  pass,
  pending,
  fail,
}

enum ContradictionChangeFutureRuleId {
  futureValueLanguageDocumented,
  strongProofTrailRequired,
  correctionAllowed,
  noClinicalLabelFraming,
  noCoachingLanguage,
  noForecastLanguage,
  noNewLiveV1Ui,
}

enum ContradictionChangeFutureRuleStatus {
  pass,
  fail,
}

enum ContradictionChangeFutureGateDecision {
  changeFrozen,
  futureChangeDetectionDocumented,
}
