import '../product/consumer_ui_copy.dart';
import 'archive_pro_feature_map.dart';
import 'paywall_trigger_model.dart';
import 'pro_value_preview_engine.dart';

/// Builds paywall triggers for long-term memory limits and Pro archive features.
PaywallTriggerContext? buildPaywallTrigger({
  required ArchiveFeature feature,
  required bool isPro,
  required bool firstLoopClosed,
  int momentCount = 0,
  int checkInCount = 0,
  int weekCount = 0,
  String sourceRoute = '',
}) {
  if (isPro || !firstLoopClosed) return null;

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
    case ArchiveFeature.archiveTimeline:
      return PaywallTrigger.archiveTimelineFull;
    case ArchiveFeature.whatArchiveMeRemembers:
      return PaywallTrigger.archiveMemoryFull;
    case ArchiveFeature.monthlyReview:
      return PaywallTrigger.monthlyReview;
    case ArchiveFeature.privateRecapExport:
      return PaywallTrigger.privateExport;
    default:
      return null;
  }
}
