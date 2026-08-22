import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/features/widget_release_risk/widget_release_risk_gate_copy.dart';

/// Widget release risk gate — ensure excluded native capabilities stay out of beta.
abstract final class WidgetReleaseRiskGate {
  WidgetReleaseRiskGate._();

  static const checkCount = 8;
  static const canonicalAppGroupId = 'group.com.voicememory.mobile';
  static const canonicalWidgetRoute = '/record';

  static bool get _betaExcludesNativeExtensions =>
      !V1CapabilityRegistry.nativeExtensions;

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
          _betaExcludesNativeExtensions ||
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

  static bool detectExtensionTargetPresent(String pbxprojContents) => RegExp(
    r'isa = PBXNativeTarget;[\s\S]*?name = TodayCheckWidget;',
    multiLine: true,
  ).hasMatch(pbxprojContents);

  static bool detectTodayCheckWidgetGroupInProject(String pbxprojContents) =>
      pbxprojContents.contains('path = TodayCheckWidget;');

  static bool detectObjectiveWidgetStorageInRunner(String pbxprojContents) =>
      pbxprojContents.contains('ObjectiveWidgetStorage.swift in Sources');

  static bool detectAppGroupInRunnerEntitlements(String runnerEntitlements) =>
      runnerEntitlements.contains(canonicalAppGroupId);

  static bool detectAndroidWidgetReceiver(String androidManifest) =>
      androidManifest.contains('TodayCheckWidgetProvider');

  static bool detectAndroidNotificationBootReceiver(String androidManifest) =>
      androidManifest.contains('ScheduledNotificationBootReceiver');

  static bool detectWidgetMethodChannelInMainActivity(String mainActivityKt) =>
      mainActivityKt.contains('archive_me/current_objective_widget');

  static bool detectAppGroupConfigured({
    required String runnerEntitlements,
    required String extensionEntitlements,
    required String objectiveWidgetStorageSwift,
    required String todayCheckWidgetSwift,
  }) {
    if (detectAppGroupInRunnerEntitlements(runnerEntitlements)) return true;
    for (final source in [
      extensionEntitlements,
      objectiveWidgetStorageSwift,
      todayCheckWidgetSwift,
    ]) {
      if (source.contains(canonicalAppGroupId)) return true;
    }
    return false;
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
    required String androidManifest,
    required String mainActivityKt,
    String extensionEntitlements = '',
    String objectiveWidgetStorageSwift = '',
    String todayCheckWidgetSwift = '',
    required String widgetExporterDart,
    required String widgetPrepDoc,
    bool testFlightInstallWorks = true,
    bool signingPasses = true,
    bool noCrashOnLaunch = true,
    bool noStaleBrokenDefaultState = true,
  }) => WidgetReleaseRiskGateInput(
    extensionTargetPresent: detectExtensionTargetPresent(pbxprojContents),
    todayCheckWidgetGroupPresent: detectTodayCheckWidgetGroupInProject(
      pbxprojContents,
    ),
    objectiveWidgetStorageInRunner: detectObjectiveWidgetStorageInRunner(
      pbxprojContents,
    ),
    appGroupConfigured: detectAppGroupConfigured(
      runnerEntitlements: runnerEntitlements,
      extensionEntitlements: extensionEntitlements,
      objectiveWidgetStorageSwift: objectiveWidgetStorageSwift,
      todayCheckWidgetSwift: todayCheckWidgetSwift,
    ),
    androidWidgetReceiverPresent: detectAndroidWidgetReceiver(androidManifest),
    androidNotificationBootReceiverPresent:
        detectAndroidNotificationBootReceiver(androidManifest),
    widgetMethodChannelPresent: detectWidgetMethodChannelInMainActivity(
      mainActivityKt,
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
  ) {
    if (_betaExcludesNativeExtensions) {
      return [
        _absenceCheck(
          id: WidgetReleaseRiskGateCheckId.extensionTargetPresent,
          artifactPresent: input.extensionTargetPresent,
        ),
        _absenceCheck(
          id: WidgetReleaseRiskGateCheckId.appGroupConfigured,
          artifactPresent: input.appGroupConfigured,
        ),
        _absenceCheck(
          id: WidgetReleaseRiskGateCheckId.androidWidgetReceiverAbsent,
          artifactPresent: input.androidWidgetReceiverPresent,
        ),
        _absenceCheck(
          id: WidgetReleaseRiskGateCheckId.androidNotificationBootReceiverAbsent,
          artifactPresent: input.androidNotificationBootReceiverPresent,
        ),
        _absenceCheck(
          id: WidgetReleaseRiskGateCheckId.objectiveWidgetStorageAbsent,
          artifactPresent:
              input.objectiveWidgetStorageInRunner ||
              input.todayCheckWidgetGroupPresent,
        ),
        _absenceCheck(
          id: WidgetReleaseRiskGateCheckId.widgetMethodChannelAbsent,
          artifactPresent: input.widgetMethodChannelPresent,
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
      ];
    }

    return [
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
  }

  static WidgetReleaseRiskGateCheck _absenceCheck({
    required WidgetReleaseRiskGateCheckId id,
    required bool artifactPresent,
  }) => _check(
    id: id,
    pass: !artifactPresent,
    failDetail: WidgetReleaseRiskGateCopy.detailExcludedArtifactPresent,
  );

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
    if (_betaExcludesNativeExtensions) {
      if (input.extensionTargetPresent ||
          input.todayCheckWidgetGroupPresent ||
          input.objectiveWidgetStorageInRunner ||
          input.appGroupConfigured ||
          input.androidWidgetReceiverPresent ||
          input.androidNotificationBootReceiverPresent ||
          input.widgetMethodChannelPresent) {
        return WidgetReleaseRiskGateDecision.widgetBlocksRelease;
      }
      if (!input.testFlightInstallWorks ||
          !input.signingPasses ||
          !input.noCrashOnLaunch) {
        return WidgetReleaseRiskGateDecision.widgetBlocksRelease;
      }
      return WidgetReleaseRiskGateDecision.widgetSafe;
    }

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
          _betaExcludesNativeExtensions
              ? WidgetReleaseRiskGateCopy.betaReleaseAlignedLine
              : WidgetReleaseRiskGateCopy.widgetSafeLine,
        WidgetReleaseRiskGateDecision.widgetNeedsManualXcodeCheck =>
          WidgetReleaseRiskGateCopy.widgetNeedsManualXcodeCheckLine,
        WidgetReleaseRiskGateDecision.widgetDisableForRelease =>
          WidgetReleaseRiskGateCopy.widgetDisableForReleaseLine,
        WidgetReleaseRiskGateDecision.widgetBlocksRelease =>
          _betaExcludesNativeExtensions
              ? WidgetReleaseRiskGateCopy.betaExcludedArtifactPresentLine
              : WidgetReleaseRiskGateCopy.widgetBlocksReleaseLine,
      };

  static String _recommendationFor(
    WidgetReleaseRiskGateDecision decision,
  ) => switch (decision) {
    WidgetReleaseRiskGateDecision.widgetSafe =>
      _betaExcludesNativeExtensions
          ? 'Beta release artifacts match V1CapabilityRegistry (widgets/notifications excluded).'
          : 'Ship widget with TestFlight.',
    WidgetReleaseRiskGateDecision.widgetNeedsManualXcodeCheck =>
      'Run docs/TODAYS_CHECK_WIDGET_QA.md before enabling widget.',
    WidgetReleaseRiskGateDecision.widgetDisableForRelease =>
      'Defer widget extension; ship main app TestFlight without widget target.',
    WidgetReleaseRiskGateDecision.widgetBlocksRelease =>
      _betaExcludesNativeExtensions
          ? 'Remove excluded widget/notification artifacts from release targets and manifests.'
          : 'Remove or disable TodayCheckWidget extension before archive upload.',
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
    this.todayCheckWidgetGroupPresent = false,
    this.objectiveWidgetStorageInRunner = false,
    required this.appGroupConfigured,
    this.androidWidgetReceiverPresent = false,
    this.androidNotificationBootReceiverPresent = false,
    this.widgetMethodChannelPresent = false,
    required this.widgetOpensCorrectRoute,
    required this.noPrivateTranscriptShown,
    required this.testFlightInstallWorks,
    required this.signingPasses,
    required this.noCrashOnLaunch,
    required this.noStaleBrokenDefaultState,
  });

  final bool extensionTargetPresent;
  final bool todayCheckWidgetGroupPresent;
  final bool objectiveWidgetStorageInRunner;
  final bool appGroupConfigured;
  final bool androidWidgetReceiverPresent;
  final bool androidNotificationBootReceiverPresent;
  final bool widgetMethodChannelPresent;
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
