/// Widget release risk gate copy — ensure widgets cannot block TestFlight.
abstract final class WidgetReleaseRiskGateCopy {
  WidgetReleaseRiskGateCopy._();

  static const headline = 'Widget release risk gate';

  static const body =
      'Classify whether the Today\u2019s Check widget can ship with TestFlight or '
      'should be disabled, manually verified, or treated as a release blocker.';

  static const orderLine =
      'Checks: extension target, App Group, route, privacy, TestFlight install, '
      'signing, launch crash, default state.';

  static const checkExtensionTarget = 'Extension target present';
  static const checkAppGroup = 'App Group configured';
  static const checkWidgetRoute = 'Widget opens correct route';
  static const checkNoPrivateTranscript = 'No private transcript on widget';
  static const checkTestFlightInstall = 'TestFlight install works';
  static const checkSigning = 'Signing passes';
  static const checkNoLaunchCrash = 'No crash on launch';
  static const checkDefaultState = 'No stale or broken default state';

  static const detailPass = 'Verified';
  static const detailFail = 'Risk detected';
  static const detailDefer = 'Disable or defer widget';
  static const detailManual = 'Needs manual Xcode check';
  static const detailExcludedArtifactPresent =
      'Excluded artifact present in release build';

  static const betaReleaseAlignedLine =
      'Beta release artifacts exclude widgets and local notification receivers.';

  static const betaExcludedArtifactPresentLine =
      'Excluded widget or notification artifact found in release configuration.';

  static const checkAndroidWidgetReceiverAbsent =
      'Android widget receiver absent';
  static const checkAndroidNotificationBootReceiverAbsent =
      'Android notification boot receiver absent';
  static const checkObjectiveWidgetStorageAbsent =
      'Objective widget storage absent from Runner';
  static const checkWidgetMethodChannelAbsent = 'Widget method channel absent';

  static const widgetSafeLine =
      'Widget release risk is acceptable. Today\u2019s Check can ship with TestFlight.';

  static const widgetNeedsManualXcodeCheckLine =
      'Widget needs manual Xcode verification before enabling on TestFlight.';

  static const widgetDisableForReleaseLine =
      'Disable or defer the widget extension for this TestFlight build. The main app '
      'can still ship.';

  static const widgetBlocksReleaseLine =
      'Widget extension creates a signing, TestFlight, or launch blocker. Disable the '
      'extension before submission.';

  static const guardrail =
      'Widget release risk gate classifies release risk only. Do not add widget '
      'features, sizes, or analytics.';

  static String labelFor(WidgetReleaseRiskGateCheckId id) => switch (id) {
    WidgetReleaseRiskGateCheckId.extensionTargetPresent => checkExtensionTarget,
    WidgetReleaseRiskGateCheckId.appGroupConfigured => checkAppGroup,
    WidgetReleaseRiskGateCheckId.widgetOpensCorrectRoute => checkWidgetRoute,
    WidgetReleaseRiskGateCheckId.noPrivateTranscriptShown =>
      checkNoPrivateTranscript,
    WidgetReleaseRiskGateCheckId.testFlightInstallWorks =>
      checkTestFlightInstall,
    WidgetReleaseRiskGateCheckId.signingPasses => checkSigning,
    WidgetReleaseRiskGateCheckId.noCrashOnLaunch => checkNoLaunchCrash,
    WidgetReleaseRiskGateCheckId.noStaleBrokenDefaultState => checkDefaultState,
    WidgetReleaseRiskGateCheckId.androidWidgetReceiverAbsent =>
      checkAndroidWidgetReceiverAbsent,
    WidgetReleaseRiskGateCheckId.androidNotificationBootReceiverAbsent =>
      checkAndroidNotificationBootReceiverAbsent,
    WidgetReleaseRiskGateCheckId.objectiveWidgetStorageAbsent =>
      checkObjectiveWidgetStorageAbsent,
    WidgetReleaseRiskGateCheckId.widgetMethodChannelAbsent =>
      checkWidgetMethodChannelAbsent,
  };

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield orderLine;
    yield checkExtensionTarget;
    yield checkAppGroup;
    yield checkWidgetRoute;
    yield checkNoPrivateTranscript;
    yield checkTestFlightInstall;
    yield checkSigning;
    yield checkNoLaunchCrash;
    yield checkDefaultState;
    yield detailPass;
    yield detailFail;
    yield detailDefer;
    yield detailManual;
    yield detailExcludedArtifactPresent;
    yield betaReleaseAlignedLine;
    yield betaExcludedArtifactPresentLine;
    yield widgetSafeLine;
    yield widgetNeedsManualXcodeCheckLine;
    yield widgetDisableForReleaseLine;
    yield widgetBlocksReleaseLine;
    yield guardrail;
  }
}

enum WidgetReleaseRiskGateCheckId {
  extensionTargetPresent,
  appGroupConfigured,
  widgetOpensCorrectRoute,
  noPrivateTranscriptShown,
  testFlightInstallWorks,
  signingPasses,
  noCrashOnLaunch,
  noStaleBrokenDefaultState,
  androidWidgetReceiverAbsent,
  androidNotificationBootReceiverAbsent,
  objectiveWidgetStorageAbsent,
  widgetMethodChannelAbsent,
}