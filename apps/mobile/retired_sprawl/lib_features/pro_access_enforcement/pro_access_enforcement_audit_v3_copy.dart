import 'package:archiveme_mobile/features/pro_access_enforcement/pro_access_enforcement_audit_copy.dart';

/// Pro access enforcement audit v3 copy — store readiness bridge + CI enforcement.
abstract final class ProAccessEnforcementAuditV3Copy {
  ProAccessEnforcementAuditV3Copy._();

  static const headline = 'Pro access enforcement bridge';

  static const body =
      'Cross-tag store readiness billing steps with Pro access enforcement '
      'classifications and enforce the audit bundle in CI.';

  static const bridgeSectionTitle = 'Store readiness bridge';
  static const alignedLabel = 'Aligned';
  static const misalignedLabel = 'Misaligned';
  static const storeDecisionLabel = 'Store readiness decision';
  static const enforcementDecisionLabel = 'Enforcement decision';

  static const guardrail =
      'Pro access enforcement audit v3 bridges classifications only. Do not change '
      'store readiness, purchase, or RevenueCat behavior.';

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield bridgeSectionTitle;
    yield alignedLabel;
    yield misalignedLabel;
    yield storeDecisionLabel;
    yield enforcementDecisionLabel;
    yield guardrail;
    yield ProAccessEnforcementAuditCopy.headline;
  }
}