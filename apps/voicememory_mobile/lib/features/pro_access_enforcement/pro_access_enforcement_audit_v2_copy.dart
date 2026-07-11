import 'pro_access_enforcement_audit_copy.dart';

/// Pro access enforcement audit v2 copy — developer dashboard wiring.
abstract final class ProAccessEnforcementAuditV2Copy {
  ProAccessEnforcementAuditV2Copy._();

  static const headline = 'Pro access enforcement';

  static const body =
      'Developer-only enforcement classifier. Shows what Pro access is enforced '
      'locally, via RevenueCat, not yet, or blocking production.';

  static const sectionTitle = 'Enforcement dimensions';
  static const decisionLabel = 'Release posture';
  static const blockerSummary = 'production blockers';
  static const gapSummary = 'documented gaps';

  static const decisionTestFlightAcceptable = 'TestFlight acceptable';
  static const decisionProductionBlocked = 'Production blocked';
  static const decisionEnforcementDocumented = 'Enforcement documented';

  static const guardrail =
      'Pro access enforcement audit v2 classifies enforcement only. Do not build '
      'account system, add backend sync, or change purchase behavior.';

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield sectionTitle;
    yield decisionLabel;
    yield blockerSummary;
    yield gapSummary;
    yield decisionTestFlightAcceptable;
    yield decisionProductionBlocked;
    yield decisionEnforcementDocumented;
    yield guardrail;
    yield ProAccessEnforcementAuditCopy.headline;
    yield ProAccessEnforcementAuditCopy.guardrail;
  }
}
