/// Loop packs future copy — acquisition angles without V1 UI.
abstract final class LoopPacksFutureCopy {
  LoopPacksFutureCopy._();

  static const headline = 'Loop packs future gate';

  static const body =
      'Define loop packs as future acquisition angles without adding them to V1 UI. '
      'Positioning and documentation only.';

  static const orderLine =
      'Packs: saying yes with no capacity, trying to prove enough, relationship replay, '
      'avoiding direct conversations, repeating the same habit, feeling behind when stopping.';

  static const prereqOrderLine =
      'Prerequisites: TestFlight uploaded and paid-intent beta complete.';

  static const guardrail =
      'Loop packs future gate classifies acquisition angles only. Do not add new onboarding '
      'UI. Do not add paywall benefits. Packs stay future positioning until TestFlight and '
      'paid-intent beta pass. Avoid clinical framing or treatment-style language.';

  static const packsFrozenLine =
      'Loop packs frozen until TestFlight and paid-intent beta proof are complete.';

  static const packsDocumentedOnlyLine =
      'Beta proof complete. Keep loop packs in acquisition docs only — not in V1 UI.';

  static const detailPass = 'Pass';
  static const detailPending = 'Pending';
  static const detailFail = 'Fail';

  static const detailBlockedBeforeBetaProof = 'Blocked before beta proof';
  static const detailFutureAcquisitionDocumented =
      'Future acquisition documented only';

  static String labelFor(LoopPackFutureId id) => switch (id) {
    LoopPackFutureId.sayingYesNoCapacity => 'Saying yes with no capacity',
    LoopPackFutureId.tryingToProveEnough => 'Trying to prove enough',
    LoopPackFutureId.relationshipReplay => 'Relationship replay',
    LoopPackFutureId.avoidingDirectConversations =>
      'Avoiding direct conversations',
    LoopPackFutureId.repeatingSameHabit => 'Repeating the same habit',
    LoopPackFutureId.feelingBehindWhenStopping =>
      'Feeling behind when stopping',
  };

  static String positioningFor(LoopPackFutureId id) => switch (id) {
    LoopPackFutureId.sayingYesNoCapacity =>
      'For people who keep saying yes when they have no capacity left.',
    LoopPackFutureId.tryingToProveEnough =>
      'For people who keep trying to prove they are doing enough.',
    LoopPackFutureId.relationshipReplay =>
      'For people who replay relationship moments after they happen.',
    LoopPackFutureId.avoidingDirectConversations =>
      'For people who avoid saying something directly.',
    LoopPackFutureId.repeatingSameHabit =>
      'For people who notice the same habit repeating.',
    LoopPackFutureId.feelingBehindWhenStopping =>
      'For people who feel behind when they stop pushing.',
  };

  static String prereqLabelFor(LoopPackFuturePrereqId id) => switch (id) {
    LoopPackFuturePrereqId.testFlightUploaded => 'TestFlight uploaded',
    LoopPackFuturePrereqId.paidIntentBetaComplete =>
      'Paid-intent beta complete',
  };

  static String messageFor(LoopPacksFutureGateDecision decision) =>
      switch (decision) {
        LoopPacksFutureGateDecision.packsFrozen => packsFrozenLine,
        LoopPacksFutureGateDecision.packsDocumentedOnly =>
          packsDocumentedOnlyLine,
      };

  static String recommendationFor(
    LoopPacksFutureGateDecision decision,
  ) => switch (decision) {
    LoopPacksFutureGateDecision.packsFrozen =>
      'Finish TestFlight upload and paid-intent beta before using loop packs in acquisition planning.',
    LoopPacksFutureGateDecision.packsDocumentedOnly =>
      'Use loop packs in acquisition docs and campaigns only. Do not add onboarding or paywall surfaces.',
  };

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield orderLine;
    yield prereqOrderLine;
    yield guardrail;
    yield packsFrozenLine;
    yield packsDocumentedOnlyLine;
    yield detailPass;
    yield detailPending;
    yield detailFail;
    yield detailBlockedBeforeBetaProof;
    yield detailFutureAcquisitionDocumented;
    for (final id in LoopPackFutureId.values) {
      yield labelFor(id);
      yield positioningFor(id);
    }
    for (final id in LoopPackFuturePrereqId.values) {
      yield prereqLabelFor(id);
    }
    for (final decision in LoopPacksFutureGateDecision.values) {
      yield messageFor(decision);
      yield recommendationFor(decision);
    }
  }
}

enum LoopPackFutureId {
  sayingYesNoCapacity,
  tryingToProveEnough,
  relationshipReplay,
  avoidingDirectConversations,
  repeatingSameHabit,
  feelingBehindWhenStopping,
}

enum LoopPackFuturePrereqId { testFlightUploaded, paidIntentBetaComplete }

enum LoopPackFuturePrereqStatus { pass, pending, fail }

enum LoopPackFutureStatus {
  blockedBeforeBetaProof,
  futureAcquisitionDocumented,
}

enum LoopPacksFutureGateDecision { packsFrozen, packsDocumentedOnly }