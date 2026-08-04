import 'widget_release_risk_gate_copy.dart';

/// Widget release risk gate — ensure widgets cannot block TestFlight release.
abstract final class WidgetReleaseRiskGate {
  WidgetReleaseRiskGate._();

  static const checkCount = 8;
  static const canonicalAppGroupId = 'group.com.voicememory.mobile';
  static const canonicalWidgetRoute = '/record';

  static WidgetReleaseRiskGateResult build(WidgetReleaseRiskGateInput input) {
    final checks = _buildChecks(input);
    final decision = _resolveDecision(input);
    return WidgetReleaseRiskGateResult(
      decision: decision,
      message: _messageFor(decision),
      recommendation: _recommendationFor(decision),
      checks: checks,
      earliestRisk: _earliestRisk(checks),
      testFlightBlockedByWidget:
          decision == WidgetReleaseRiskGateDecision.widgetBlocksRelease,
      widgetShouldBeDisabled:
          decision == WidgetReleaseRiskGateDecision.widgetDisableForRelease ||
          decision == WidgetReleaseRiskGateDecision.widgetBlocksRelease,
    );
  }

  static WidgetReleaseRiskGateReport report(
    WidgetReleaseRiskGateResult result,
  ) => WidgetReleaseRiskGateReport(
    headline: WidgetReleaseRiskGateCopy.headline,
    body: WidgetReleaseRiskGateCopy.body,
    orderLine: WidgetReleaseRiskGateCopy.orderLine,
    guardrail: WidgetReleaseRiskGateCopy.guardrail,
    result: result,
  );

  static bool detectExtensionTargetPresent(String pbxprojContents) =>
      pbxprojContents.contains('/* ArchiveMeWidgets */ = {') &&
      pbxprojContents.contains('name = ArchiveMeWidgets;') &&
      pbxprojContents.contains('ArchiveMeWidgets.appex');

  static bool detectAppGroupConfigured({
    required String runnerEntitlements,
    required String extensionEntitlements,
    required String objectiveWidgetStorageSwift,
    required String todayCheckWidgetSwift,
  }) {
    for (final source in [
      runnerEntitlements,
      extensionEntitlements,
      objectiveWidgetStorageSwift,
      todayCheckWidgetSwift,
    ]) {
      if (!source.contains(canonicalAppGroupId)) return false;
    }
    return true;
  }

  static bool detectWidgetOpensCorrectRoute(String widgetExporterDart) =>
      widgetExporterDart.contains("kWidgetPayloadDefaultRoute = '/record'") &&
      widgetExporterDart.contains("'route': kWidgetPayloadDefaultRoute");

  static bool detectNoPrivateTranscriptPolicy(String widgetPrepDoc) {
    final lower = widgetPrepDoc.toLowerCase();
    return lower.contains('do not expose full reflection text') &&
        lower.contains('no pattern titles');
  }

  static WidgetReleaseRiskGateInput fromRepoSignals({
    required String pbxprojContents,
    required String runnerEntitlements,
    required String extensionEntitlements,
    required String objectiveWidgetStorageSwift,
    required String todayCheckWidgetSwift,
    required String widgetExporterDart,
    required String widgetPrepDoc,
    bool testFlightInstallWorks = true,
    bool signingPasses = true,
    bool noCrashOnLaunch = true,
    bool noStaleBrokenDefaultState = true,
  }) => WidgetReleaseRiskGateInput(
    extensionTargetPresent: detectExtensionTargetPresent(pbxprojContents),
    appGroupConfigured: detectAppGroupConfigured(
      runnerEntitlements: runnerEntitlements,
      extensionEntitlements: extensionEntitlements,
      objectiveWidgetStorageSwift: objectiveWidgetStorageSwift,
      todayCheckWidgetSwift: todayCheckWidgetSwift,
    ),
    widgetOpensCorrectRoute: detectWidgetOpensCorrectRoute(widgetExporterDart),
    noPrivateTranscriptShown: detectNoPrivateTranscriptPolicy(widgetPrepDoc),
    testFlightInstallWorks: testFlightInstallWorks,
    signingPasses: signingPasses,
    noCrashOnLaunch: noCrashOnLaunch,
    noStaleBrokenDefaultState: noStaleBrokenDefaultState,
  );

  static List<WidgetReleaseRiskGateCheck> _buildChecks(
    WidgetReleaseRiskGateInput input,
  ) => [
    _check(
      id: WidgetReleaseRiskGateCheckId.extensionTargetPresent,
      pass: input.extensionTargetPresent,
      failDetail: WidgetReleaseRiskGateCopy.detailDefer,
    ),
    _check(
      id: WidgetReleaseRiskGateCheckId.appGroupConfigured,
      pass: input.appGroupConfigured,
      failDetail: WidgetReleaseRiskGateCopy.detailDefer,
    ),
    _check(
      id: WidgetReleaseRiskGateCheckId.widgetOpensCorrectRoute,
      pass: input.widgetOpensCorrectRoute,
      failDetail: WidgetReleaseRiskGateCopy.detailManual,
    ),
    _check(
      id: WidgetReleaseRiskGateCheckId.noPrivateTranscriptShown,
      pass: input.noPrivateTranscriptShown,
      failDetail: WidgetReleaseRiskGateCopy.detailManual,
    ),
    _check(
      id: WidgetReleaseRiskGateCheckId.testFlightInstallWorks,
      pass: input.testFlightInstallWorks,
      failDetail: WidgetReleaseRiskGateCopy.detailFail,
    ),
    _check(
      id: WidgetReleaseRiskGateCheckId.signingPasses,
      pass: input.signingPasses,
      failDetail: WidgetReleaseRiskGateCopy.detailFail,
    ),
    _check(
      id: WidgetReleaseRiskGateCheckId.noCrashOnLaunch,
      pass: input.noCrashOnLaunch,
      failDetail: WidgetReleaseRiskGateCopy.detailFail,
    ),
    _check(
      id: WidgetReleaseRiskGateCheckId.noStaleBrokenDefaultState,
      pass: input.noStaleBrokenDefaultState,
      failDetail: WidgetReleaseRiskGateCopy.detailManual,
    ),
  ];

  static WidgetReleaseRiskGateCheck _check({
    required WidgetReleaseRiskGateCheckId id,
    required bool pass,
    required String failDetail,
  }) => WidgetReleaseRiskGateCheck(
    id: id,
    label: WidgetReleaseRiskGateCopy.labelFor(id),
    status: pass
        ? WidgetReleaseRiskGateCheckStatus.pass
        : WidgetReleaseRiskGateCheckStatus.fail,
    detailLabel: pass ? WidgetReleaseRiskGateCopy.detailPass : failDetail,
  );

  static WidgetReleaseRiskGateDecision _resolveDecision(
    WidgetReleaseRiskGateInput input,
  ) {
    if (input.extensionTargetPresent &&
        (!input.signingPasses ||
            !input.testFlightInstallWorks ||
            !input.noCrashOnLaunch)) {
      return WidgetReleaseRiskGateDecision.widgetBlocksRelease;
    }

    if (!input.extensionTargetPresent || !input.appGroupConfigured) {
      return WidgetReleaseRiskGateDecision.widgetDisableForRelease;
    }

    if (!input.widgetOpensCorrectRoute ||
        !input.noPrivateTranscriptShown ||
        !input.noStaleBrokenDefaultState) {
      return WidgetReleaseRiskGateDecision.widgetNeedsManualXcodeCheck;
    }

    return WidgetReleaseRiskGateDecision.widgetSafe;
  }

  static WidgetReleaseRiskGateCheckId? _earliestRisk(
    List<WidgetReleaseRiskGateCheck> checks,
  ) {
    for (final check in checks) {
      if (check.status == WidgetReleaseRiskGateCheckStatus.fail) {
        return check.id;
      }
    }
    return null;
  }

  static String _messageFor(WidgetReleaseRiskGateDecision decision) =>
      switch (decision) {
        WidgetReleaseRiskGateDecision.widgetSafe =>
          WidgetReleaseRiskGateCopy.widgetSafeLine,
        WidgetReleaseRiskGateDecision.widgetNeedsManualXcodeCheck =>
          WidgetReleaseRiskGateCopy.widgetNeedsManualXcodeCheckLine,
        WidgetReleaseRiskGateDecision.widgetDisableForRelease =>
          WidgetReleaseRiskGateCopy.widgetDisableForReleaseLine,
        WidgetReleaseRiskGateDecision.widgetBlocksRelease =>
          WidgetReleaseRiskGateCopy.widgetBlocksReleaseLine,
      };

  static String _recommendationFor(
    WidgetReleaseRiskGateDecision decision,
  ) => switch (decision) {
    WidgetReleaseRiskGateDecision.widgetSafe => 'Ship widget with TestFlight.',
    WidgetReleaseRiskGateDecision.widgetNeedsManualXcodeCheck =>
      'Run the ArchiveMeWidgets device checklist before enabling widgets.',
    WidgetReleaseRiskGateDecision.widgetDisableForRelease =>
      'Defer widget extension; ship main app TestFlight without widget target.',
    WidgetReleaseRiskGateDecision.widgetBlocksRelease =>
      'Remove or disable ArchiveMeWidgets before archive upload.',
  };
}

enum WidgetReleaseRiskGateCheckStatus { pass, fail }

enum WidgetReleaseRiskGateDecision {
  widgetSafe,
  widgetNeedsManualXcodeCheck,
  widgetDisableForRelease,
  widgetBlocksRelease,
}

class WidgetReleaseRiskGateInput {
  const WidgetReleaseRiskGateInput({
    required this.extensionTargetPresent,
    required this.appGroupConfigured,
    required this.widgetOpensCorrectRoute,
    required this.noPrivateTranscriptShown,
    required this.testFlightInstallWorks,
    required this.signingPasses,
    required this.noCrashOnLaunch,
    required this.noStaleBrokenDefaultState,
  });

  final bool extensionTargetPresent;
  final bool appGroupConfigured;
  final bool widgetOpensCorrectRoute;
  final bool noPrivateTranscriptShown;
  final bool testFlightInstallWorks;
  final bool signingPasses;
  final bool noCrashOnLaunch;
  final bool noStaleBrokenDefaultState;
}

class WidgetReleaseRiskGateCheck {
  const WidgetReleaseRiskGateCheck({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final WidgetReleaseRiskGateCheckId id;
  final String label;
  final WidgetReleaseRiskGateCheckStatus status;
  final String detailLabel;
}

class WidgetReleaseRiskGateResult {
  const WidgetReleaseRiskGateResult({
    required this.decision,
    required this.message,
    required this.recommendation,
    required this.checks,
    required this.earliestRisk,
    required this.testFlightBlockedByWidget,
    required this.widgetShouldBeDisabled,
  });

  final WidgetReleaseRiskGateDecision decision;
  final String message;
  final String recommendation;
  final List<WidgetReleaseRiskGateCheck> checks;
  final WidgetReleaseRiskGateCheckId? earliestRisk;
  final bool testFlightBlockedByWidget;
  final bool widgetShouldBeDisabled;
}

class WidgetReleaseRiskGateReport {
  const WidgetReleaseRiskGateReport({
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
  final WidgetReleaseRiskGateResult result;
}
