/// Core metrics minimum set copy — release beta metrics only.
abstract final class CoreMetricsMinimumSetCopy {
  CoreMetricsMinimumSetCopy._();

  static const headline = 'Core metrics minimum set';

  static const body =
      'These fourteen metrics are the only release-beta signals that can block '
      'release or inform paid-intent decisions. Everything else is diagnostic only.';

  static const coreLine =
      'Core beta: app opened, first save, second save, first useful proof seen, '
      'proof accepted, proof corrected, Pro promise seen, Pro tapped, purchase '
      'started, purchase completed, restore tapped, restore succeeded, entitlement '
      'active, crash or blocker reported.';

  static const diagnosticLine =
      'Diagnostic only: not release-blocking and not used for paid-intent decisions.';

  static const metricAppOpened = 'App opened';
  static const metricFirstSave = 'First save';
  static const metricSecondSave = 'Second save';
  static const metricFirstUsefulProofSeen = 'First useful proof seen';
  static const metricProofAccepted = 'Proof accepted';
  static const metricProofCorrected = 'Proof corrected';
  static const metricProPromiseSeen = 'Pro promise seen';
  static const metricProTapped = 'Pro tapped';
  static const metricPurchaseStarted = 'Purchase started';
  static const metricPurchaseCompleted = 'Purchase completed';
  static const metricRestoreTapped = 'Restore tapped';
  static const metricRestoreSucceeded = 'Restore succeeded';
  static const metricEntitlementActive = 'Entitlement active';
  static const metricCrashOrBlockerReported = 'Crash or blocker reported';

  static const guardrail =
      'Core metrics minimum set classifies events only. Do not delete analytics, '
      'change emission, or add product surfaces.';

  static String labelFor(CoreMetricsMinimumMetricId id) => switch (id) {
    CoreMetricsMinimumMetricId.appOpened => metricAppOpened,
    CoreMetricsMinimumMetricId.firstSave => metricFirstSave,
    CoreMetricsMinimumMetricId.secondSave => metricSecondSave,
    CoreMetricsMinimumMetricId.firstUsefulProofSeen =>
      metricFirstUsefulProofSeen,
    CoreMetricsMinimumMetricId.proofAccepted => metricProofAccepted,
    CoreMetricsMinimumMetricId.proofCorrected => metricProofCorrected,
    CoreMetricsMinimumMetricId.proPromiseSeen => metricProPromiseSeen,
    CoreMetricsMinimumMetricId.proTapped => metricProTapped,
    CoreMetricsMinimumMetricId.purchaseStarted => metricPurchaseStarted,
    CoreMetricsMinimumMetricId.purchaseCompleted => metricPurchaseCompleted,
    CoreMetricsMinimumMetricId.restoreTapped => metricRestoreTapped,
    CoreMetricsMinimumMetricId.restoreSucceeded => metricRestoreSucceeded,
    CoreMetricsMinimumMetricId.entitlementActive => metricEntitlementActive,
    CoreMetricsMinimumMetricId.crashOrBlockerReported =>
      metricCrashOrBlockerReported,
  };

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield coreLine;
    yield diagnosticLine;
    yield metricAppOpened;
    yield metricFirstSave;
    yield metricSecondSave;
    yield metricFirstUsefulProofSeen;
    yield metricProofAccepted;
    yield metricProofCorrected;
    yield metricProPromiseSeen;
    yield metricProTapped;
    yield metricPurchaseStarted;
    yield metricPurchaseCompleted;
    yield metricRestoreTapped;
    yield metricRestoreSucceeded;
    yield metricEntitlementActive;
    yield metricCrashOrBlockerReported;
  }
}

/// Metric ids referenced by copy labels.
enum CoreMetricsMinimumMetricId {
  appOpened,
  firstSave,
  secondSave,
  firstUsefulProofSeen,
  proofAccepted,
  proofCorrected,
  proPromiseSeen,
  proTapped,
  purchaseStarted,
  purchaseCompleted,
  restoreTapped,
  restoreSucceeded,
  entitlementActive,
  crashOrBlockerReported,
}
