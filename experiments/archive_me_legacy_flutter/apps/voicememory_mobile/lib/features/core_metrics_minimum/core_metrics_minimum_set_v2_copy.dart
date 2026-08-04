import 'core_metrics_minimum_set_copy.dart';

/// Core metrics minimum set v2 copy — developer dashboard + CI enforcement.
abstract final class CoreMetricsMinimumSetV2Copy {
  CoreMetricsMinimumSetV2Copy._();

  static const headline = 'Core metrics minimum set';

  static const body =
      'Release-beta metrics only. Diagnostic funnel events stay visible but do '
      'not block release or paid-intent decisions.';

  static const coreSectionTitle = 'Core beta metrics';
  static const diagnosticSectionTitle = 'Diagnostic only';

  static const statusObserved = 'Observed';
  static const statusMissing = 'Missing';
  static const tagCoreBeta = 'Core beta';
  static const tagDiagnosticOnly = 'Diagnostic only';
  static const tagPaidIntent = 'Paid-intent signal';

  static const guardrail =
      'Core metrics minimum set v2 classifies events only. Do not delete analytics '
      'or change emission.';

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield coreSectionTitle;
    yield diagnosticSectionTitle;
    yield statusObserved;
    yield statusMissing;
    yield tagCoreBeta;
    yield tagDiagnosticOnly;
    yield tagPaidIntent;
    yield guardrail;
    yield CoreMetricsMinimumSetCopy.headline;
    yield CoreMetricsMinimumSetCopy.diagnosticLine;
  }
}
