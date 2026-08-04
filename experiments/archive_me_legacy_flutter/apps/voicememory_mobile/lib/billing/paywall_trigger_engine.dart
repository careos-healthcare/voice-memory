import '../product/consumer_ui_copy.dart';
import '../features/monetization/domain/access_policy_engine.dart';
import 'paywall_trigger_model.dart';
import 'pro_value_preview_engine.dart';

/// Builds paywall triggers for long-term memory limits and Pro archive features.
PaywallTriggerContext? buildPaywallTrigger({
  required CapabilityId capability,
  required EntitlementSnapshot entitlement,
  required ProductValueState valueState,
  UsageSnapshot usage = const UsageSnapshot(),
  bool explicitlyRequestedPro = false,
  int momentCount = 0,
  int checkInCount = 0,
  int weekCount = 0,
  String sourceRoute = '',
}) {
  final policy = MonetizationPolicy.capability(capability);
  if (policy.accessClass == AccessClass.userOwned ||
      policy.accessClass == AccessClass.freeProof ||
      capability == CapabilityId.readExistingGeneratedOutput) {
    return null;
  }
  if (!explicitlyRequestedPro &&
      !valueState.hasGenerated(CapabilityId.firstEarlyComparison)) {
    return null;
  }
  final decision = AccessPolicyEngine.decide(
    capability: capability,
    entitlement: entitlement,
    usage: usage,
    productValue: valueState,
  );
  if (decision.allowed) return null;

  final trigger = _triggerForFeature(capability: capability);
  if (trigger == null) return null;

  final context = PaywallTriggerContext(
    trigger: trigger,
    sourceRoute: sourceRoute,
    momentCount: momentCount,
    checkInCount: checkInCount,
    weekCount: weekCount,
    previewTitle: '',
    previewBody: '',
    ctaLabel: ConsumerUiCopy.unlockFullMemoryCta,
  );
  final preview = buildProValuePreview(context);
  return context.copyWith(
    previewTitle: preview.title,
    previewBody: preview.body,
    ctaLabel: preview.ctaLabel,
  );
}

PaywallTrigger? _triggerForFeature({required CapabilityId capability}) {
  switch (capability) {
    case CapabilityId.advancedEvidenceGrouping:
      return PaywallTrigger.patternMapFull;
    case CapabilityId.deepArchiveSynthesis:
      return PaywallTrigger.archiveMemoryFull;
    case CapabilityId.periodicReviewGeneration:
      return PaywallTrigger.monthlyReview;
    default:
      return null;
  }
}
