/// Three day proof challenge copy — future acquisition without V1 changes.
abstract final class ThreeDayProofChallengeCopy {
  ThreeDayProofChallengeCopy._();

  static const headline = 'Three day proof challenge gate';

  static const body =
      'Prepare a future 3-day proof challenge without changing V1. Acquisition '
      'positioning and documentation only.';

  static const promise =
      'Save 3 real moments in 3 days. See the first useful proof.';

  static const orderLine =
      'Rules: future acquisition only, no streaks, no daily pressure, no required '
      'check-in, no live V1 UI unless paid-intent beta shows users need this.';

  static const guardrail =
      'Three day proof challenge gate classifies future acquisition only. Do not add '
      'streaks, daily pressure, or required check-ins. Do not add live V1 UI unless '
      'paid-intent beta shows users need this challenge.';

  static const futureAcquisitionOnlyLine =
      'Keep the 3-day proof challenge in acquisition docs only. Do not change V1.';

  static const v1SurfacingAllowedLine =
      'Paid-intent beta shows users need this challenge. V1 surfacing may be considered '
      'without streaks, daily pressure, or required check-ins.';

  static const detailPass = 'Pass';
  static const detailFail = 'Fail';

  static const detailFutureAcquisitionOnly = 'Future acquisition only';
  static const detailV1SurfacingAllowed = 'V1 surfacing allowed';

  static String ruleLabelFor(ThreeDayProofChallengeRuleId id) => switch (id) {
    ThreeDayProofChallengeRuleId.futureAcquisitionOnly =>
      'Future acquisition only',
    ThreeDayProofChallengeRuleId.noStreaks => 'No streaks',
    ThreeDayProofChallengeRuleId.noDailyPressure => 'No daily pressure',
    ThreeDayProofChallengeRuleId.noRequiredCheckIn => 'No required check-in',
  };

  static String messageFor(ThreeDayProofChallengeGateDecision decision) =>
      switch (decision) {
        ThreeDayProofChallengeGateDecision.futureAcquisitionOnly =>
          futureAcquisitionOnlyLine,
        ThreeDayProofChallengeGateDecision.v1SurfacingAllowed =>
          v1SurfacingAllowedLine,
      };

  static String recommendationFor(
    ThreeDayProofChallengeGateDecision decision,
  ) => switch (decision) {
    ThreeDayProofChallengeGateDecision.futureAcquisitionOnly =>
      'Keep the challenge promise in docs and campaigns. Leave V1 surfaces unchanged.',
    ThreeDayProofChallengeGateDecision.v1SurfacingAllowed =>
      'If surfacing, keep the canonical promise and all no-pressure rules intact.',
  };

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield promise;
    yield orderLine;
    yield guardrail;
    yield futureAcquisitionOnlyLine;
    yield v1SurfacingAllowedLine;
    yield detailPass;
    yield detailFail;
    yield detailFutureAcquisitionOnly;
    yield detailV1SurfacingAllowed;
    for (final id in ThreeDayProofChallengeRuleId.values) {
      yield ruleLabelFor(id);
    }
    for (final decision in ThreeDayProofChallengeGateDecision.values) {
      yield messageFor(decision);
      yield recommendationFor(decision);
    }
  }
}

enum ThreeDayProofChallengeRuleId {
  futureAcquisitionOnly,
  noStreaks,
  noDailyPressure,
  noRequiredCheckIn,
}

enum ThreeDayProofChallengeRuleStatus { pass, fail }

enum ThreeDayProofChallengeGateDecision {
  futureAcquisitionOnly,
  v1SurfacingAllowed,
}
