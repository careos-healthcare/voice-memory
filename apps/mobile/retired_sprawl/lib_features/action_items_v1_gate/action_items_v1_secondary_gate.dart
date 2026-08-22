import 'package:archiveme_mobile/features/action_items_v1_gate/action_items_v1_secondary_gate_copy.dart';

/// Gate — ensure action items do not become core to first release.
abstract final class ActionItemsV1SecondaryGate {
  ActionItemsV1SecondaryGate._();

  static const checkCount = 8;

  static const blockedTaskManagementPhrases = [
    'task manager',
    'task management',
    'to-do list',
    'todo app',
    'todo list',
    'get things done',
    'productivity tasks',
    'action item tracker',
    'manage your tasks',
    'task inbox',
  ];

  static const allowedSecondaryPhrases = [
    'remember this',
    'things you chose to remember',
    'user-confirmed',
    'secondary hidden',
    'hide action items',
  ];

  static ActionItemsV1SecondaryGateResult build(
    ActionItemsV1SecondaryGateInput input,
  ) {
    final checks = _buildChecks(input);
    final decision = _resolveDecision(checks);
    return ActionItemsV1SecondaryGateResult(
      decision: decision,
      message: _messageFor(decision),
      recommendation: _recommendationFor(decision),
      checks: checks,
      earliestViolation: _earliestViolation(checks),
      violatesGate:
          decision ==
          ActionItemsV1SecondaryGateDecision.actionItemsViolatesGate,
    );
  }

  static ActionItemsV1SecondaryGateReport report(
    ActionItemsV1SecondaryGateResult result,
  ) => ActionItemsV1SecondaryGateReport(
    headline: ActionItemsV1SecondaryGateCopy.headline,
    body: ActionItemsV1SecondaryGateCopy.body,
    orderLine: ActionItemsV1SecondaryGateCopy.orderLine,
    guardrail: ActionItemsV1SecondaryGateCopy.guardrail,
    result: result,
  );

  static ActionItemsV1SecondaryGateCopyResult evaluateCopy(String copy) {
    final lower = copy.toLowerCase().trim();
    if (lower.isEmpty) {
      return const ActionItemsV1SecondaryGateCopyResult(
        action: ActionItemsV1SecondaryGateCopyAction.allowed,
        reason: ActionItemsV1SecondaryGateCopyReason.allowedSecondaryLanguage,
      );
    }

    if (_isAntiTaskManagementInstruction(lower)) {
      return const ActionItemsV1SecondaryGateCopyResult(
        action: ActionItemsV1SecondaryGateCopyAction.allowed,
        reason: ActionItemsV1SecondaryGateCopyReason.allowedSecondaryLanguage,
      );
    }

    for (final phrase in blockedTaskManagementPhrases) {
      if (lower.contains(phrase) && !_isNegated(lower, phrase)) {
        return ActionItemsV1SecondaryGateCopyResult(
          action: ActionItemsV1SecondaryGateCopyAction.block,
          reason: ActionItemsV1SecondaryGateCopyReason.blockedTaskManagement,
          matchedPhrase: phrase,
        );
      }
    }

    return const ActionItemsV1SecondaryGateCopyResult(
      action: ActionItemsV1SecondaryGateCopyAction.allowed,
      reason: ActionItemsV1SecondaryGateCopyReason.allowedSecondaryLanguage,
    );
  }

  static bool passesCopy(String copy) =>
      evaluateCopy(copy).action != ActionItemsV1SecondaryGateCopyAction.block;

  static bool detectSecondaryScope(String v1SurfaceScopeAuditSource) =>
      v1SurfaceScopeAuditSource.contains('V1VisibleSurface.actionItems') &&
      v1SurfaceScopeAuditSource.contains('secondarySurfaces');

  static bool detectHiddenInFirstFiveMinutes(
    String firstFiveMinutesSimplificationSource,
  ) =>
      firstFiveMinutesSimplificationSource.contains(
        'FirstFiveMinutesSurface.actionItems',
      ) &&
      firstFiveMinutesSimplificationSource.contains('hideActionItemsTooEarly');

  static bool detectNotInProPromise(String proSinglePromiseCopySource) {
    final lower = proSinglePromiseCopySource.toLowerCase();
    return !lower.contains('action items');
  }

  static bool detectNotBlockingFirstProof(String featureNoiseReductionSource) =>
      featureNoiseReductionSource.contains('FeatureSurfaceType.actionItems') &&
      featureNoiseReductionSource.contains('hideActionItemsUntilUserIntent');

  static bool detectNotRequiredOnboarding(String onboardingPagesSource) {
    final lower = onboardingPagesSource.toLowerCase();
    return !lower.contains('action items') && !lower.contains('remember this');
  }

  static bool detectUserConfirmedAccessOnly(String rememberThisButtonSource) =>
      rememberThisButtonSource.contains('Creates nothing until the') &&
      rememberThisButtonSource.contains('no auto-extraction');

  static bool detectNoExpansionGuarded({
    required String freezeDriftScannerCopySource,
    required String releaseCandidateFreezeCopySource,
  }) =>
      freezeDriftScannerCopySource.contains('action items') &&
      releaseCandidateFreezeCopySource.contains('action items');

  static bool detectActionItemsCopySafe(String archiveActionItemSource) {
    for (final line in _actionItemsCopyLines(archiveActionItemSource)) {
      if (!passesCopy(line)) return false;
    }
    return archiveActionItemSource.contains('ActionItemsCopy');
  }

  static ActionItemsV1SecondaryGateInput fromRepoSignals({
    required String v1SurfaceScopeAuditSource,
    required String firstFiveMinutesSimplificationSource,
    required String proSinglePromiseCopySource,
    required String featureNoiseReductionSource,
    required String onboardingPagesSource,
    required String rememberThisButtonSource,
    required String freezeDriftScannerCopySource,
    required String releaseCandidateFreezeCopySource,
    required String archiveActionItemSource,
    bool actionItemsInCoreTab = false,
    bool actionItemsInFirstFiveMinutesByDefault = false,
    bool actionItemsInProPromise = false,
    bool actionItemsBlockFirstProof = false,
    bool actionItemsRequiredInOnboarding = false,
    bool remindersExpansionRequested = false,
  }) => ActionItemsV1SecondaryGateInput(
    actionItemsSecondary:
        detectSecondaryScope(v1SurfaceScopeAuditSource) &&
        !actionItemsInCoreTab,
    hiddenInFirstFiveMinutes:
        detectHiddenInFirstFiveMinutes(firstFiveMinutesSimplificationSource) &&
        !actionItemsInFirstFiveMinutesByDefault,
    notInProPromise:
        detectNotInProPromise(proSinglePromiseCopySource) &&
        !actionItemsInProPromise,
    notBlockingFirstProof:
        detectNotBlockingFirstProof(featureNoiseReductionSource) &&
        !actionItemsBlockFirstProof,
    notRequiredOnboarding:
        detectNotRequiredOnboarding(onboardingPagesSource) &&
        !actionItemsRequiredInOnboarding,
    notTaskManagementPositioning: detectActionItemsCopySafe(
      archiveActionItemSource,
    ),
    userConfirmedAccessOnly: detectUserConfirmedAccessOnly(
      rememberThisButtonSource,
    ),
    noExpansionGuarded:
        detectNoExpansionGuarded(
          freezeDriftScannerCopySource: freezeDriftScannerCopySource,
          releaseCandidateFreezeCopySource: releaseCandidateFreezeCopySource,
        ) &&
        !remindersExpansionRequested,
  );

  static List<ActionItemsV1SecondaryGateCheck> _buildChecks(
    ActionItemsV1SecondaryGateInput input,
  ) => [
    _check(
      id: ActionItemsV1SecondaryGateCheckId.actionItemsSecondary,
      passes: input.actionItemsSecondary,
    ),
    _check(
      id: ActionItemsV1SecondaryGateCheckId.notInFirstFiveMinutes,
      passes: input.hiddenInFirstFiveMinutes,
    ),
    _check(
      id: ActionItemsV1SecondaryGateCheckId.notInProPromise,
      passes: input.notInProPromise,
    ),
    _check(
      id: ActionItemsV1SecondaryGateCheckId.notBlockingFirstProof,
      passes: input.notBlockingFirstProof,
    ),
    _check(
      id: ActionItemsV1SecondaryGateCheckId.notRequiredOnboarding,
      passes: input.notRequiredOnboarding,
    ),
    _check(
      id: ActionItemsV1SecondaryGateCheckId.notTaskManagementPositioning,
      passes: input.notTaskManagementPositioning,
    ),
    _check(
      id: ActionItemsV1SecondaryGateCheckId.userConfirmedAccessOnly,
      passes: input.userConfirmedAccessOnly,
    ),
    _check(
      id: ActionItemsV1SecondaryGateCheckId.noExpansionGuarded,
      passes: input.noExpansionGuarded,
    ),
  ];

  static ActionItemsV1SecondaryGateDecision _resolveDecision(
    List<ActionItemsV1SecondaryGateCheck> checks,
  ) {
    final failures = checks.where((check) => !check.passes).toList();
    if (failures.isEmpty) {
      return ActionItemsV1SecondaryGateDecision.actionItemsSecondaryOk;
    }

    final hardFailures = failures
        .where((check) => check.isHardFailure)
        .toList();
    if (hardFailures.isNotEmpty) {
      return ActionItemsV1SecondaryGateDecision.actionItemsViolatesGate;
    }

    return ActionItemsV1SecondaryGateDecision.actionItemsWarnReview;
  }

  static ActionItemsV1SecondaryGateCheck? _earliestViolation(
    List<ActionItemsV1SecondaryGateCheck> checks,
  ) {
    for (final check in checks) {
      if (!check.passes) return check;
    }
    return null;
  }

  static ActionItemsV1SecondaryGateCheck _check({
    required ActionItemsV1SecondaryGateCheckId id,
    required bool passes,
  }) => ActionItemsV1SecondaryGateCheck(
    id: id,
    label: ActionItemsV1SecondaryGateCopy.labelFor(id),
    passes: passes,
    detailLabel: passes
        ? ActionItemsV1SecondaryGateCopy.detailPass
        : ActionItemsV1SecondaryGateCopy.detailFail,
    isHardFailure: _isHardFailure(id),
  );

  static bool _isHardFailure(ActionItemsV1SecondaryGateCheckId id) =>
      switch (id) {
        ActionItemsV1SecondaryGateCheckId.actionItemsSecondary ||
        ActionItemsV1SecondaryGateCheckId.notInFirstFiveMinutes ||
        ActionItemsV1SecondaryGateCheckId.notInProPromise ||
        ActionItemsV1SecondaryGateCheckId.notBlockingFirstProof ||
        ActionItemsV1SecondaryGateCheckId.notRequiredOnboarding ||
        ActionItemsV1SecondaryGateCheckId.notTaskManagementPositioning ||
        ActionItemsV1SecondaryGateCheckId.noExpansionGuarded => true,
        ActionItemsV1SecondaryGateCheckId.userConfirmedAccessOnly => false,
      };

  static String _messageFor(ActionItemsV1SecondaryGateDecision decision) =>
      switch (decision) {
        ActionItemsV1SecondaryGateDecision.actionItemsSecondaryOk =>
          ActionItemsV1SecondaryGateCopy.actionItemsSecondaryOkLine,
        ActionItemsV1SecondaryGateDecision.actionItemsWarnReview =>
          ActionItemsV1SecondaryGateCopy.actionItemsWarnReviewLine,
        ActionItemsV1SecondaryGateDecision.actionItemsViolatesGate =>
          ActionItemsV1SecondaryGateCopy.actionItemsViolatesGateLine,
      };

  static String _recommendationFor(
    ActionItemsV1SecondaryGateDecision decision,
  ) => switch (decision) {
    ActionItemsV1SecondaryGateDecision.actionItemsSecondaryOk =>
      'Keep action items in settings, entry detail, and other user-confirmed paths only.',
    ActionItemsV1SecondaryGateDecision.actionItemsWarnReview =>
      'Review action-item access paths before release. Do not widen visibility.',
    ActionItemsV1SecondaryGateDecision.actionItemsViolatesGate =>
      'Move action items back behind secondary surfaces. Do not delete the feature.',
  };

  static Iterable<String> _actionItemsCopyLines(String source) sync* {
    final pattern = RegExp(r"static const String \w+ = '([^']*)';");
    for (final match in pattern.allMatches(source)) {
      yield match.group(1)!;
    }
  }

  static bool _isAntiTaskManagementInstruction(String lower) {
    const markers = [
      'hide reports, action items',
      'no reports, dashboards, action items',
      'secondary hidden: reports, dashboards, action items',
      'blocked: new features, new dashboards, rankings, reports, action items',
      'risky drift: new surfaces, dashboards, reports, rankings, action items',
      'do not expand action items',
      'no reminders expansion',
      'no task manager positioning',
    ];
    for (final marker in markers) {
      if (lower.contains(marker)) return true;
    }
    return false;
  }

  static bool _isNegated(String lower, String phrase) {
    final index = lower.indexOf(phrase);
    if (index < 0) return false;
    final before = lower.substring(0, index);
    if (before.contains('avoid')) return true;
    if (before.contains('do not')) return true;
    if (RegExp(r'\bnot\b').hasMatch(before)) return true;
    if (RegExp(r'\bno\b').hasMatch(before)) return true;
    return false;
  }
}

enum ActionItemsV1SecondaryGateDecision {
  actionItemsSecondaryOk,
  actionItemsWarnReview,
  actionItemsViolatesGate,
}

enum ActionItemsV1SecondaryGateCopyAction { allowed, block }

enum ActionItemsV1SecondaryGateCopyReason {
  allowedSecondaryLanguage,
  blockedTaskManagement,
}

class ActionItemsV1SecondaryGateInput {
  const ActionItemsV1SecondaryGateInput({
    required this.actionItemsSecondary,
    required this.hiddenInFirstFiveMinutes,
    required this.notInProPromise,
    required this.notBlockingFirstProof,
    required this.notRequiredOnboarding,
    required this.notTaskManagementPositioning,
    required this.userConfirmedAccessOnly,
    required this.noExpansionGuarded,
  });

  final bool actionItemsSecondary;
  final bool hiddenInFirstFiveMinutes;
  final bool notInProPromise;
  final bool notBlockingFirstProof;
  final bool notRequiredOnboarding;
  final bool notTaskManagementPositioning;
  final bool userConfirmedAccessOnly;
  final bool noExpansionGuarded;
}

class ActionItemsV1SecondaryGateCheck {
  const ActionItemsV1SecondaryGateCheck({
    required this.id,
    required this.label,
    required this.passes,
    required this.detailLabel,
    required this.isHardFailure,
  });

  final ActionItemsV1SecondaryGateCheckId id;
  final String label;
  final bool passes;
  final String detailLabel;
  final bool isHardFailure;
}

class ActionItemsV1SecondaryGateResult {
  const ActionItemsV1SecondaryGateResult({
    required this.decision,
    required this.message,
    required this.recommendation,
    required this.checks,
    required this.earliestViolation,
    required this.violatesGate,
  });

  final ActionItemsV1SecondaryGateDecision decision;
  final String message;
  final String recommendation;
  final List<ActionItemsV1SecondaryGateCheck> checks;
  final ActionItemsV1SecondaryGateCheck? earliestViolation;
  final bool violatesGate;
}

class ActionItemsV1SecondaryGateReport {
  const ActionItemsV1SecondaryGateReport({
    required this.headline,
    required this.body,
    required this.orderLine,
    required this.guardrail,
    required this.result,
  });

  final String headline;
  final String body;
  final String orderLine;
  final String guardrail;
  final ActionItemsV1SecondaryGateResult result;
}

class ActionItemsV1SecondaryGateCopyResult {
  const ActionItemsV1SecondaryGateCopyResult({
    required this.action,
    required this.reason,
    this.matchedPhrase,
  });

  final ActionItemsV1SecondaryGateCopyAction action;
  final ActionItemsV1SecondaryGateCopyReason reason;
  final String? matchedPhrase;
}