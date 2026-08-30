import 'package:archiveme_mobile/billing/magic_moments_counter.dart';
import 'package:archiveme_mobile/billing/archive_pro_feature_map.dart';
import 'package:archiveme_mobile/billing/paywall_trigger_model.dart';
import 'package:archiveme_mobile/billing/pro_value_preview_engine.dart';
import 'package:archiveme_mobile/core/config/v1_billing_capability.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';

/// Builds paywall triggers for long-term memory limits and Pro archive features.
PaywallTriggerContext? buildPaywallTrigger({
  required ArchiveFeature feature,
  required bool isPro,
  required bool firstLoopClosed,
  int momentCount = 0,
  int magicMomentsCount = 0,
  int checkInCount = 0,
  int weekCount = 0,
  String sourceRoute = '',
}) {
  if (!V1BillingCapability.isProductionReachable) return null;
  if (isPro || !firstLoopClosed) return null;
  if (magicMomentsCount < MagicMomentsCounter.paywallThreshold) return null;

  final trigger = _triggerForFeature(
    feature: feature,
    momentCount: momentCount,
  );
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

PaywallTrigger? _triggerForFeature({
  required ArchiveFeature feature,
  required int momentCount,
}) {
  switch (feature) {
    case ArchiveFeature.keyMomentsSearch:
    case ArchiveFeature.fullHistory:
      if (momentCount <= ArchiveProFeatureMap.freeKeyMomentsLimit) {
        return null;
      }
      return feature == ArchiveFeature.keyMomentsSearch
          ? PaywallTrigger.keyMomentsLimit
          : PaywallTrigger.fullHistory;
    case ArchiveFeature.patternMap:
      return PaywallTrigger.patternMapFull;
    case ArchiveFeature.whatArchiveMeRemembers:
      return PaywallTrigger.archiveMemoryFull;
    case ArchiveFeature.monthlyReview:
      return PaywallTrigger.monthlyReview;
    default:
      return null;
  }
}