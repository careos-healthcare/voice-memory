import 'action_items_v1_secondary_gate.dart';

/// Action items suppression hardening — keep action items out of core journeys.
abstract final class ActionItemsSuppressionHardening {
  ActionItemsSuppressionHardening._();

  static const ruleCount = 10;

  static const headline = 'Action items suppression hardening';

  static const body =
      'Ensure action items remain secondary and cannot enter first journey, '
      'Pro promise, onboarding, or first proof.';

  static const guardrail =
      'Do not delete action item storage. No reminders expansion. '
      'No task manager language. No new surfaces.';

  static const canonicalRules = [
    'Action items are never part of first five minutes',
    'Action items are never part of Pro promise',
    'Action items are never required onboarding',
    'Action items never block first proof',
    'Action items never appear as a task manager',
    'Remember-this path stays user-confirmed only',
    'No reminders expansion',
    'No task manager language',
    'No new surfaces',
    'Action item storage is preserved',
  ];

  static const ruleNeverInFirstFiveMinutes =
      'Action items are never part of first five minutes';
  static const ruleNeverInProPromise =
      'Action items are never part of Pro promise';
  static const ruleNeverRequiredOnboarding =
      'Action items are never required onboarding';
  static const ruleNeverBlockFirstProof =
      'Action items never block first proof';
  static const ruleNeverTaskManager =
      'Action items never appear as a task manager';
  static const ruleRememberThisUserConfirmed =
      'Remember-this path is user-confirmed only';
  static const ruleNoRemindersExpansion = 'No reminders expansion';
  static const ruleNoTaskManagerLanguage = 'No task manager language';
  static const ruleNoNewSurfaces = 'No new surfaces';
  static const ruleStoragePreserved = 'Action item storage is preserved';

  static const hardenedOkLine =
      'Action items suppression hardening passes for v1 release.';

  static const violatedLine =
      'Action items suppression violated. Move action items back to secondary paths.';

  static const needsReviewLine =
      'Action items suppression needs review before widening access.';

  static const detailPass = 'Verified';
  static const detailFail = 'Suppression violation';
  static const detailReview = 'Needs review';

  static ActionItemsSuppressionHardeningResult build(
    ActionItemsSuppressionHardeningInput input,
  ) {
    final gateResult = ActionItemsV1SecondaryGate.build(
      _toSecondaryInput(input),
    );
    final rules = _buildRules(input);
    final decision = _resolveDecision(gateResult.decision, rules);
    return ActionItemsSuppressionHardeningResult(
      decision: decision,
      message: _messageFor(decision),
      recommendation: _recommendationFor(decision),
      rules: rules,
      gateResult: gateResult,
      earliestViolation: rules.where((rule) => !rule.passes).firstOrNull,
      hardened: decision == ActionItemsSuppressionHardeningDecision.hardened,
    );
  }

  static ActionItemsSuppressionHardeningReport report(
    ActionItemsSuppressionHardeningResult result,
  ) => ActionItemsSuppressionHardeningReport(
    headline: headline,
    body: body,
    guardrail: guardrail,
    result: result,
  );

  static ActionItemsSuppressionHardeningInput fromRepoSignals({
    required String v1SurfaceScopeAuditSource,
    required String firstFiveMinutesSimplificationSource,
    required String proSinglePromiseCopySource,
    required String featureNoiseReductionSource,
    required String onboardingPagesSource,
    required String rememberThisButtonSource,
    required String freezeDriftScannerCopySource,
    required String releaseCandidateFreezeCopySource,
    required String archiveActionItemSource,
    required String actionItemStoreSource,
    bool actionItemsInCoreTab = false,
    bool actionItemsInFirstFiveMinutesByDefault = false,
    bool actionItemsInProPromise = false,
    bool actionItemsBlockFirstProof = false,
    bool actionItemsRequiredInOnboarding = false,
    bool remindersExpansionRequested = false,
  }) {
    final secondary = ActionItemsV1SecondaryGate.fromRepoSignals(
      v1SurfaceScopeAuditSource: v1SurfaceScopeAuditSource,
      firstFiveMinutesSimplificationSource:
          firstFiveMinutesSimplificationSource,
      proSinglePromiseCopySource: proSinglePromiseCopySource,
      featureNoiseReductionSource: featureNoiseReductionSource,
      onboardingPagesSource: onboardingPagesSource,
      rememberThisButtonSource: rememberThisButtonSource,
      freezeDriftScannerCopySource: freezeDriftScannerCopySource,
      releaseCandidateFreezeCopySource: releaseCandidateFreezeCopySource,
      archiveActionItemSource: archiveActionItemSource,
      actionItemsInCoreTab: actionItemsInCoreTab,
      actionItemsInFirstFiveMinutesByDefault:
          actionItemsInFirstFiveMinutesByDefault,
      actionItemsInProPromise: actionItemsInProPromise,
      actionItemsBlockFirstProof: actionItemsBlockFirstProof,
      actionItemsRequiredInOnboarding: actionItemsRequiredInOnboarding,
      remindersExpansionRequested: remindersExpansionRequested,
    );
    return ActionItemsSuppressionHardeningInput(
      hiddenInFirstFiveMinutes: secondary.hiddenInFirstFiveMinutes,
      notInProPromise: secondary.notInProPromise,
      notRequiredOnboarding: secondary.notRequiredOnboarding,
      notBlockingFirstProof: secondary.notBlockingFirstProof,
      notTaskManagerPositioning: secondary.notTaskManagementPositioning,
      userConfirmedAccessOnly: secondary.userConfirmedAccessOnly,
      noRemindersExpansion: secondary.noExpansionGuarded,
      actionItemsSecondary: secondary.actionItemsSecondary,
      storagePreserved: detectStoragePreserved(actionItemStoreSource),
    );
  }

  static bool detectStoragePreserved(String actionItemStoreSource) =>
      actionItemStoreSource.contains('class ActionItemStore') &&
      actionItemStoreSource.contains('Future<ArchiveActionItem?> create') &&
      actionItemStoreSource.contains('loadAll') &&
      !actionItemStoreSource.contains('.deleteAll(');

  static bool detectModuleHasNoUiImports(String source) {
    for (final line in source.split('\n')) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('import ')) continue;
      if (trimmed.contains('package:flutter/')) return false;
      if (trimmed.contains('widgets/action_items/')) return false;
      if (trimmed.contains('screens/')) return false;
      if (trimmed.contains('onboarding_pages.dart')) return false;
    }
    return true;
  }

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield guardrail;
    for (final rule in canonicalRules) {
      yield rule;
    }
    yield ruleNeverInFirstFiveMinutes;
    yield ruleNeverInProPromise;
    yield ruleNeverRequiredOnboarding;
    yield ruleNeverBlockFirstProof;
    yield ruleNeverTaskManager;
    yield ruleRememberThisUserConfirmed;
    yield ruleNoRemindersExpansion;
    yield ruleNoTaskManagerLanguage;
    yield ruleNoNewSurfaces;
    yield ruleStoragePreserved;
    yield hardenedOkLine;
    yield violatedLine;
    yield needsReviewLine;
    yield detailPass;
    yield detailFail;
    yield detailReview;
  }

  static ActionItemsV1SecondaryGateInput _toSecondaryInput(
    ActionItemsSuppressionHardeningInput input,
  ) => ActionItemsV1SecondaryGateInput(
    actionItemsSecondary: input.actionItemsSecondary,
    hiddenInFirstFiveMinutes: input.hiddenInFirstFiveMinutes,
    notInProPromise: input.notInProPromise,
    notBlockingFirstProof: input.notBlockingFirstProof,
    notRequiredOnboarding: input.notRequiredOnboarding,
    notTaskManagementPositioning: input.notTaskManagerPositioning,
    userConfirmedAccessOnly: input.userConfirmedAccessOnly,
    noExpansionGuarded: input.noRemindersExpansion,
  );

  static List<ActionItemsSuppressionRule> _buildRules(
    ActionItemsSuppressionHardeningInput input,
  ) => [
    _rule(
      id: ActionItemsSuppressionRuleId.neverInFirstFiveMinutes,
      passes: input.hiddenInFirstFiveMinutes,
      isHardFailure: true,
    ),
    _rule(
      id: ActionItemsSuppressionRuleId.neverInProPromise,
      passes: input.notInProPromise,
      isHardFailure: true,
    ),
    _rule(
      id: ActionItemsSuppressionRuleId.neverRequiredOnboarding,
      passes: input.notRequiredOnboarding,
      isHardFailure: true,
    ),
    _rule(
      id: ActionItemsSuppressionRuleId.neverBlockFirstProof,
      passes: input.notBlockingFirstProof,
      isHardFailure: true,
    ),
    _rule(
      id: ActionItemsSuppressionRuleId.neverTaskManager,
      passes: input.notTaskManagerPositioning,
      isHardFailure: true,
    ),
    _rule(
      id: ActionItemsSuppressionRuleId.rememberThisUserConfirmed,
      passes: input.userConfirmedAccessOnly,
      isHardFailure: false,
    ),
    _rule(
      id: ActionItemsSuppressionRuleId.noRemindersExpansion,
      passes: input.noRemindersExpansion,
      isHardFailure: true,
    ),
    _rule(
      id: ActionItemsSuppressionRuleId.noTaskManagerLanguage,
      passes: input.notTaskManagerPositioning,
      isHardFailure: true,
    ),
    _rule(
      id: ActionItemsSuppressionRuleId.noNewSurfaces,
      passes: input.actionItemsSecondary,
      isHardFailure: true,
    ),
    _rule(
      id: ActionItemsSuppressionRuleId.storagePreserved,
      passes: input.storagePreserved,
      isHardFailure: true,
    ),
  ];

  static ActionItemsSuppressionHardeningDecision _resolveDecision(
    ActionItemsV1SecondaryGateDecision gateDecision,
    List<ActionItemsSuppressionRule> rules,
  ) {
    if (gateDecision ==
        ActionItemsV1SecondaryGateDecision.actionItemsViolatesGate) {
      return ActionItemsSuppressionHardeningDecision.violated;
    }
    final hardFailures = rules
        .where((rule) => !rule.passes && rule.isHardFailure)
        .toList();
    if (hardFailures.isNotEmpty) {
      return ActionItemsSuppressionHardeningDecision.violated;
    }
    if (gateDecision ==
        ActionItemsV1SecondaryGateDecision.actionItemsWarnReview) {
      return ActionItemsSuppressionHardeningDecision.needsReview;
    }
    return ActionItemsSuppressionHardeningDecision.hardened;
  }

  static ActionItemsSuppressionRule _rule({
    required ActionItemsSuppressionRuleId id,
    required bool passes,
    required bool isHardFailure,
  }) => ActionItemsSuppressionRule(
    id: id,
    label: _labelFor(id),
    passes: passes,
    detailLabel: passes ? detailPass : detailFail,
    isHardFailure: isHardFailure,
  );

  static String _labelFor(ActionItemsSuppressionRuleId id) => switch (id) {
    ActionItemsSuppressionRuleId.neverInFirstFiveMinutes =>
      ruleNeverInFirstFiveMinutes,
    ActionItemsSuppressionRuleId.neverInProPromise => ruleNeverInProPromise,
    ActionItemsSuppressionRuleId.neverRequiredOnboarding =>
      ruleNeverRequiredOnboarding,
    ActionItemsSuppressionRuleId.neverBlockFirstProof =>
      ruleNeverBlockFirstProof,
    ActionItemsSuppressionRuleId.neverTaskManager => ruleNeverTaskManager,
    ActionItemsSuppressionRuleId.rememberThisUserConfirmed =>
      ruleRememberThisUserConfirmed,
    ActionItemsSuppressionRuleId.noRemindersExpansion =>
      ruleNoRemindersExpansion,
    ActionItemsSuppressionRuleId.noTaskManagerLanguage =>
      ruleNoTaskManagerLanguage,
    ActionItemsSuppressionRuleId.noNewSurfaces => ruleNoNewSurfaces,
    ActionItemsSuppressionRuleId.storagePreserved => ruleStoragePreserved,
  };

  static String _messageFor(ActionItemsSuppressionHardeningDecision decision) =>
      switch (decision) {
        ActionItemsSuppressionHardeningDecision.hardened => hardenedOkLine,
        ActionItemsSuppressionHardeningDecision.needsReview => needsReviewLine,
        ActionItemsSuppressionHardeningDecision.violated => violatedLine,
      };

  static String _recommendationFor(
    ActionItemsSuppressionHardeningDecision decision,
  ) => switch (decision) {
    ActionItemsSuppressionHardeningDecision.hardened =>
      'Keep action items in settings, entry detail, and user-confirmed remember-this paths only.',
    ActionItemsSuppressionHardeningDecision.needsReview =>
      'Review remember-this access before release. Do not widen visibility.',
    ActionItemsSuppressionHardeningDecision.violated =>
      'Restore suppression rules. Do not delete action item storage.',
  };
}

enum ActionItemsSuppressionHardeningDecision { hardened, needsReview, violated }

enum ActionItemsSuppressionRuleId {
  neverInFirstFiveMinutes,
  neverInProPromise,
  neverRequiredOnboarding,
  neverBlockFirstProof,
  neverTaskManager,
  rememberThisUserConfirmed,
  noRemindersExpansion,
  noTaskManagerLanguage,
  noNewSurfaces,
  storagePreserved,
}

class ActionItemsSuppressionHardeningInput {
  const ActionItemsSuppressionHardeningInput({
    required this.hiddenInFirstFiveMinutes,
    required this.notInProPromise,
    required this.notRequiredOnboarding,
    required this.notBlockingFirstProof,
    required this.notTaskManagerPositioning,
    required this.userConfirmedAccessOnly,
    required this.noRemindersExpansion,
    required this.actionItemsSecondary,
    required this.storagePreserved,
  });

  final bool hiddenInFirstFiveMinutes;
  final bool notInProPromise;
  final bool notRequiredOnboarding;
  final bool notBlockingFirstProof;
  final bool notTaskManagerPositioning;
  final bool userConfirmedAccessOnly;
  final bool noRemindersExpansion;
  final bool actionItemsSecondary;
  final bool storagePreserved;
}

class ActionItemsSuppressionRule {
  const ActionItemsSuppressionRule({
    required this.id,
    required this.label,
    required this.passes,
    required this.detailLabel,
    required this.isHardFailure,
  });

  final ActionItemsSuppressionRuleId id;
  final String label;
  final bool passes;
  final String detailLabel;
  final bool isHardFailure;
}

class ActionItemsSuppressionHardeningResult {
  const ActionItemsSuppressionHardeningResult({
    required this.decision,
    required this.message,
    required this.recommendation,
    required this.rules,
    required this.gateResult,
    required this.earliestViolation,
    required this.hardened,
  });

  final ActionItemsSuppressionHardeningDecision decision;
  final String message;
  final String recommendation;
  final List<ActionItemsSuppressionRule> rules;
  final ActionItemsV1SecondaryGateResult gateResult;
  final ActionItemsSuppressionRule? earliestViolation;
  final bool hardened;
}

class ActionItemsSuppressionHardeningReport {
  const ActionItemsSuppressionHardeningReport({
    required this.headline,
    required this.body,
    required this.guardrail,
    required this.result,
  });

  final String headline;
  final String body;
  final String guardrail;
  final ActionItemsSuppressionHardeningResult result;
}
