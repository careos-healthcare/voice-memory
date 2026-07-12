/// B2B workplace pressure future copy — future landing positioning only.
abstract final class B2bWorkplacePressureFutureCopy {
  B2bWorkplacePressureFutureCopy._();

  static const headline = 'B2B workplace pressure future gate';

  static const body =
      'Define future B2B-lite expansion around work pressure without changing V1. '
      'Landing-page positioning and documentation only.';

  static const positioning =
      'B2B-lite workplace pressure stays future landing-page positioning — not live V1 product surfaces.';

  static const orderLine =
      'Audiences: founders, managers, carers, high-responsibility workers, people who overcommit, '
      'people who say yes with no capacity.';

  static const prereqOrderLine =
      'Prerequisites: TestFlight uploaded and paid-intent beta complete.';

  static const guardrail =
      'B2B workplace pressure future gate classifies B2B-lite positioning only. No employer dashboard. No employee surveillance. No medical or treatment-style claims. No live B2B UI. Future landing-page positioning only until TestFlight and paid-intent beta pass.';

  static const b2bFrozenLine =
      'Keep B2B-lite workplace pressure frozen until TestFlight and paid-intent beta proof are complete.';

  static const futureLandingPositioningDocumentedLine =
      'Beta proof complete. Document B2B-lite workplace pressure as future landing-page positioning only — not in V1 UI.';

  static const detailPass = 'Pass';
  static const detailPending = 'Pending';
  static const detailFail = 'Fail';

  static const detailBlockedBeforeBetaProof = 'Blocked before beta proof';
  static const detailFutureLandingPositioningDocumented =
      'Future landing positioning documented only';

  static String labelFor(B2bWorkplacePressureAudienceId id) => switch (id) {
        B2bWorkplacePressureAudienceId.founders => 'Founders',
        B2bWorkplacePressureAudienceId.managers => 'Managers',
        B2bWorkplacePressureAudienceId.carers => 'Carers',
        B2bWorkplacePressureAudienceId.highResponsibilityWorkers =>
          'High-responsibility workers',
        B2bWorkplacePressureAudienceId.peopleWhoOvercommit =>
          'People who overcommit',
        B2bWorkplacePressureAudienceId.peopleWhoSayYesWithNoCapacity =>
          'People who say yes with no capacity',
      };

  static String positioningFor(B2bWorkplacePressureAudienceId id) =>
      switch (id) {
        B2bWorkplacePressureAudienceId.founders =>
          'For founders carrying work pressure without a private proof trail.',
        B2bWorkplacePressureAudienceId.managers =>
          'For managers noticing overcommit patterns in high-responsibility roles.',
        B2bWorkplacePressureAudienceId.carers =>
          'For carers juggling responsibility pressure outside a clinical frame.',
        B2bWorkplacePressureAudienceId.highResponsibilityWorkers =>
          'For high-responsibility workers who keep absorbing more than they can hold.',
        B2bWorkplacePressureAudienceId.peopleWhoOvercommit =>
          'For people who overcommit when work pressure spikes.',
        B2bWorkplacePressureAudienceId.peopleWhoSayYesWithNoCapacity =>
          'For people who say yes with no capacity left.',
      };

  static String prereqLabelFor(B2bWorkplacePressureFuturePrereqId id) =>
      switch (id) {
        B2bWorkplacePressureFuturePrereqId.testFlightUploaded =>
          'TestFlight uploaded',
        B2bWorkplacePressureFuturePrereqId.paidIntentBetaComplete =>
          'Paid-intent beta complete',
      };

  static String ruleLabelFor(B2bWorkplacePressureFutureRuleId id) =>
      switch (id) {
        B2bWorkplacePressureFutureRuleId.noEmployerDashboard =>
          'No employer dashboard',
        B2bWorkplacePressureFutureRuleId.noEmployeeSurveillance =>
          'No employee surveillance',
        B2bWorkplacePressureFutureRuleId.noMedicalTherapyClaims =>
          'No medical or treatment-style claims',
        B2bWorkplacePressureFutureRuleId.noLiveB2bUi => 'No live B2B UI',
        B2bWorkplacePressureFutureRuleId.futureLandingPositioningOnly =>
          'Future landing-page positioning only',
      };

  static String messageFor(B2bWorkplacePressureFutureGateDecision decision) =>
      switch (decision) {
        B2bWorkplacePressureFutureGateDecision.b2bFrozen => b2bFrozenLine,
        B2bWorkplacePressureFutureGateDecision.futureLandingPositioningDocumented =>
          futureLandingPositioningDocumentedLine,
      };

  static String recommendationFor(
    B2bWorkplacePressureFutureGateDecision decision,
  ) =>
      switch (decision) {
        B2bWorkplacePressureFutureGateDecision.b2bFrozen =>
          'Finish TestFlight upload and paid-intent beta before using B2B-lite workplace pressure in landing-page planning.',
        B2bWorkplacePressureFutureGateDecision.futureLandingPositioningDocumented =>
          'Use B2B-lite workplace pressure in future landing-page docs only. Do not add employer dashboards, surveillance, or live B2B UI.',
      };

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield positioning;
    yield orderLine;
    yield prereqOrderLine;
    yield guardrail;
    yield b2bFrozenLine;
    yield futureLandingPositioningDocumentedLine;
    yield detailPass;
    yield detailPending;
    yield detailFail;
    yield detailBlockedBeforeBetaProof;
    yield detailFutureLandingPositioningDocumented;
    for (final id in B2bWorkplacePressureAudienceId.values) {
      yield labelFor(id);
      yield positioningFor(id);
    }
    for (final id in B2bWorkplacePressureFuturePrereqId.values) {
      yield prereqLabelFor(id);
    }
    for (final id in B2bWorkplacePressureFutureRuleId.values) {
      yield ruleLabelFor(id);
    }
    for (final decision in B2bWorkplacePressureFutureGateDecision.values) {
      yield messageFor(decision);
      yield recommendationFor(decision);
    }
  }
}

enum B2bWorkplacePressureAudienceId {
  founders,
  managers,
  carers,
  highResponsibilityWorkers,
  peopleWhoOvercommit,
  peopleWhoSayYesWithNoCapacity,
}

enum B2bWorkplacePressureFuturePrereqId {
  testFlightUploaded,
  paidIntentBetaComplete,
}

enum B2bWorkplacePressureFuturePrereqStatus {
  pass,
  pending,
  fail,
}

enum B2bWorkplacePressureAudienceStatus {
  blockedBeforeBetaProof,
  futureLandingPositioningDocumented,
}

enum B2bWorkplacePressureFutureRuleId {
  noEmployerDashboard,
  noEmployeeSurveillance,
  noMedicalTherapyClaims,
  noLiveB2bUi,
  futureLandingPositioningOnly,
}

enum B2bWorkplacePressureFutureRuleStatus {
  pass,
  fail,
}

enum B2bWorkplacePressureFutureGateDecision {
  b2bFrozen,
  futureLandingPositioningDocumented,
}
