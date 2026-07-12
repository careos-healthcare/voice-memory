/// Private reports future copy — later upgrade, not launch headline.
abstract final class PrivateReportsFutureCopy {
  PrivateReportsFutureCopy._();

  static const headline = 'Private reports future gate';

  static const body =
      'Keep private reports as a later upgrade, not a launch headline. '
      'Classification and documentation only.';

  static const positioning =
      'Private reports stay a later upgrade after first proof — never the launch headline.';

  static const orderLine =
      'Rules: only after first proof, no treatment-style framing, no clinical-label '
      'framing, no medical claims, no therapist-ready claims, not primary Pro promise, '
      'future Pro add-on only after longer proof trail converts.';

  static const guardrail =
      'Private reports future gate defers reports from launch headlines. Reports only '
      'after first proof. Not the primary Pro promise. Future Pro add-on only after longer '
      'proof trail converts. Avoid treatment-style, clinical-label, medical, and '
      'therapist-ready claims.';

  static const laterUpgradeOnlyLine =
      'Keep private reports deferred. Do not make them a launch headline or primary Pro promise.';

  static const futureProAddOnAllowedLine =
      'Longer proof trail converts. Private reports may be documented as a future Pro add-on only.';

  static const detailPass = 'Pass';
  static const detailFail = 'Fail';

  static const detailLaterUpgradeOnly = 'Later upgrade only';
  static const detailFutureProAddOnDocumented = 'Future Pro add-on documented';

  static String ruleLabelFor(PrivateReportsFutureRuleId id) => switch (id) {
        PrivateReportsFutureRuleId.onlyAfterFirstProof => 'Only after first proof',
        PrivateReportsFutureRuleId.notTherapy => 'No treatment-style framing',
        PrivateReportsFutureRuleId.notDiagnosis => 'No clinical-label framing',
        PrivateReportsFutureRuleId.notMedical => 'No medical claims',
        PrivateReportsFutureRuleId.notTherapistReadyClaim =>
          'No therapist-ready claims',
        PrivateReportsFutureRuleId.notPrimaryProPromise => 'Not primary Pro promise',
        PrivateReportsFutureRuleId.futureProAddOnAfterTrailConverts =>
          'Future Pro add-on after trail converts',
      };

  static String messageFor(PrivateReportsFutureGateDecision decision) =>
      switch (decision) {
        PrivateReportsFutureGateDecision.laterUpgradeOnly => laterUpgradeOnlyLine,
        PrivateReportsFutureGateDecision.futureProAddOnAllowed =>
          futureProAddOnAllowedLine,
      };

  static String recommendationFor(PrivateReportsFutureGateDecision decision) =>
      switch (decision) {
        PrivateReportsFutureGateDecision.laterUpgradeOnly =>
          'Keep private reports out of launch headlines and primary Pro promise copy.',
        PrivateReportsFutureGateDecision.futureProAddOnAllowed =>
          'Document private reports as a future Pro add-on only. Keep proof trail as the primary promise.',
      };

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield positioning;
    yield orderLine;
    yield guardrail;
    yield laterUpgradeOnlyLine;
    yield futureProAddOnAllowedLine;
    yield detailPass;
    yield detailFail;
    yield detailLaterUpgradeOnly;
    yield detailFutureProAddOnDocumented;
    for (final id in PrivateReportsFutureRuleId.values) {
      yield ruleLabelFor(id);
    }
    for (final decision in PrivateReportsFutureGateDecision.values) {
      yield messageFor(decision);
      yield recommendationFor(decision);
    }
  }
}

enum PrivateReportsFutureRuleId {
  onlyAfterFirstProof,
  notTherapy,
  notDiagnosis,
  notMedical,
  notTherapistReadyClaim,
  notPrimaryProPromise,
  futureProAddOnAfterTrailConverts,
}

enum PrivateReportsFutureRuleStatus {
  pass,
  fail,
}

enum PrivateReportsFutureGateDecision {
  laterUpgradeOnly,
  futureProAddOnAllowed,
}
