/// Core metrics beta reducer copy — classify beta decision metrics only.
abstract final class CoreMetricsBetaReducerCopy {
  CoreMetricsBetaReducerCopy._();

  static const headline = 'Core metrics beta reducer';

  static const body =
      'Reduce beta decisions to a tiny core metric set. Everything else stays '
      'diagnostic and not release-blocking.';

  static const coreLine =
      'Core beta decisions: app opened, first save, second save, first useful '
      'proof seen, proof accepted, proof corrected, Pro promise seen, Pro tapped, '
      'purchase started, purchase completed, restore succeeded, entitlement active, '
      'crash or blocker.';

  static const diagnosticLine =
      'Diagnostic only: not a decision metric and not release-blocking.';

  static const revenueLine =
      'Revenue metrics: purchase started and purchase completed.';

  static const releaseBlockingLine =
      'Release-blocking: crash or blocker reported.';

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
  static const metricRestoreSucceeded = 'Restore succeeded';
  static const metricEntitlementActive = 'Entitlement active';
  static const metricCrashOrBlocker = 'Crash or blocker';

  static const bucketDecisionMetric = 'Decision metric';
  static const bucketRevenueMetric = 'Revenue metric';
  static const bucketReleaseBlocking = 'Release blocking';
  static const bucketDiagnosticOnly = 'Diagnostic only';

  static const guardrail =
      'Core metrics beta reducer classifies events only. Do not delete analytics, '
      'do not stop existing analytics, and do not change emission.';

  static String labelFor(CoreMetricsBetaMetricId id) => switch (id) {
        CoreMetricsBetaMetricId.appOpened => metricAppOpened,
        CoreMetricsBetaMetricId.firstSave => metricFirstSave,
        CoreMetricsBetaMetricId.secondSave => metricSecondSave,
        CoreMetricsBetaMetricId.firstUsefulProofSeen =>
          metricFirstUsefulProofSeen,
        CoreMetricsBetaMetricId.proofAccepted => metricProofAccepted,
        CoreMetricsBetaMetricId.proofCorrected => metricProofCorrected,
        CoreMetricsBetaMetricId.proPromiseSeen => metricProPromiseSeen,
        CoreMetricsBetaMetricId.proTapped => metricProTapped,
        CoreMetricsBetaMetricId.purchaseStarted => metricPurchaseStarted,
        CoreMetricsBetaMetricId.purchaseCompleted => metricPurchaseCompleted,
        CoreMetricsBetaMetricId.restoreSucceeded => metricRestoreSucceeded,
        CoreMetricsBetaMetricId.entitlementActive => metricEntitlementActive,
        CoreMetricsBetaMetricId.crashOrBlocker => metricCrashOrBlocker,
      };

  static String bucketLabelFor(CoreMetricsBetaBucket bucket) => switch (bucket) {
        CoreMetricsBetaBucket.decisionMetric => bucketDecisionMetric,
        CoreMetricsBetaBucket.revenueMetric => bucketRevenueMetric,
        CoreMetricsBetaBucket.releaseBlocking => bucketReleaseBlocking,
        CoreMetricsBetaBucket.diagnosticOnly => bucketDiagnosticOnly,
      };

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield coreLine;
    yield diagnosticLine;
    yield revenueLine;
    yield releaseBlockingLine;
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
    yield metricRestoreSucceeded;
    yield metricEntitlementActive;
    yield metricCrashOrBlocker;
    yield bucketDecisionMetric;
    yield bucketRevenueMetric;
    yield bucketReleaseBlocking;
    yield bucketDiagnosticOnly;
    yield guardrail;
  }
}

enum CoreMetricsBetaMetricId {
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
  restoreSucceeded,
  entitlementActive,
  crashOrBlocker,
}

enum CoreMetricsBetaBucket {
  decisionMetric,
  revenueMetric,
  releaseBlocking,
  diagnosticOnly,
}
