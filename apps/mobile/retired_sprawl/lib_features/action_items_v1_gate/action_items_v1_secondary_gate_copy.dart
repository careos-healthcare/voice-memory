/// Action items v1 secondary gate copy — keep action items secondary for release.
abstract final class ActionItemsV1SecondaryGateCopy {
  ActionItemsV1SecondaryGateCopy._();

  static const headline = 'Action items v1 secondary gate';

  static const body =
      'Ensure action items stay secondary and never become core to the first release.';

  static const orderLine =
      'Checks: secondary scope, first five minutes, Pro promise, first proof, '
      'onboarding, task-management copy, user-confirmed access, expansion guard.';

  static const checkSecondaryScope = 'Action items are secondary';
  static const checkNotInFirstFiveMinutes = 'Hidden in first five minutes';
  static const checkNotInProPromise = 'Not part of the Pro promise';
  static const checkNotBlockingFirstProof = 'Does not block first proof';
  static const checkNotRequiredOnboarding = 'Not required onboarding';
  static const checkNotTaskManagement = 'Not positioned as task management';
  static const checkUserConfirmedAccess = 'User-confirmed access only';
  static const checkNoExpansion = 'No action-items expansion guarded';

  static const detailPass = 'Verified';
  static const detailFail = 'Gate violation';
  static const detailWarn = 'Needs review';

  static const actionItemsSecondaryOkLine =
      'Action items remain correctly secondary for v1 release.';

  static const actionItemsWarnReviewLine =
      'Action items placement needs manual review before widening visibility.';

  static const actionItemsViolatesGateLine =
      'Action items are drifting toward core release surfaces. Keep them secondary.';

  static const guardrail =
      'Do not delete action items. Do not expand action items. No reminders expansion. '
      'No task manager positioning.';

  static String labelFor(ActionItemsV1SecondaryGateCheckId id) => switch (id) {
    ActionItemsV1SecondaryGateCheckId.actionItemsSecondary =>
      checkSecondaryScope,
    ActionItemsV1SecondaryGateCheckId.notInFirstFiveMinutes =>
      checkNotInFirstFiveMinutes,
    ActionItemsV1SecondaryGateCheckId.notInProPromise => checkNotInProPromise,
    ActionItemsV1SecondaryGateCheckId.notBlockingFirstProof =>
      checkNotBlockingFirstProof,
    ActionItemsV1SecondaryGateCheckId.notRequiredOnboarding =>
      checkNotRequiredOnboarding,
    ActionItemsV1SecondaryGateCheckId.notTaskManagementPositioning =>
      checkNotTaskManagement,
    ActionItemsV1SecondaryGateCheckId.userConfirmedAccessOnly =>
      checkUserConfirmedAccess,
    ActionItemsV1SecondaryGateCheckId.noExpansionGuarded => checkNoExpansion,
  };

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield orderLine;
    yield checkSecondaryScope;
    yield checkNotInFirstFiveMinutes;
    yield checkNotInProPromise;
    yield checkNotBlockingFirstProof;
    yield checkNotRequiredOnboarding;
    yield checkNotTaskManagement;
    yield checkUserConfirmedAccess;
    yield checkNoExpansion;
    yield detailPass;
    yield detailFail;
    yield detailWarn;
    yield actionItemsSecondaryOkLine;
    yield actionItemsWarnReviewLine;
    yield actionItemsViolatesGateLine;
    yield guardrail;
  }
}

enum ActionItemsV1SecondaryGateCheckId {
  actionItemsSecondary,
  notInFirstFiveMinutes,
  notInProPromise,
  notBlockingFirstProof,
  notRequiredOnboarding,
  notTaskManagementPositioning,
  userConfirmedAccessOnly,
  noExpansionGuarded,
}
