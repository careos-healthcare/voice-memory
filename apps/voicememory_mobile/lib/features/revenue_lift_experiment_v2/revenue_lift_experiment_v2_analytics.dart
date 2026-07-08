import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import 'revenue_lift_experiment_v2_copy.dart';
import 'revenue_lift_experiment_v2_model.dart';

abstract final class RevenueLiftExperimentV2Analytics {
  RevenueLiftExperimentV2Analytics._();

  static const seenEvent = 'revenue_lift_v2_seen';
  static const ctaTappedEvent = 'revenue_lift_v2_cta_tapped';
  static const paywallSeenEvent = 'revenue_lift_v2_paywall_seen';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
      captureForTest;

  static void seen({required RevenueLiftExperimentV2SeenContext context}) {
    _emit(
      seenEvent,
      source: context.source,
      surface: context.surface,
      entryCount: context.entryCount,
      experimentArea: context.area,
    );
  }

  static void ctaTapped({required RevenueLiftExperimentV2CtaContext context}) {
    _emit(
      ctaTappedEvent,
      source: context.source,
      surface: context.surface,
      entryCount: context.entryCount,
      experimentArea: context.area,
    );
  }

  static void paywallSeen({
    required RevenueLiftExperimentV2PaywallSeenContext context,
  }) {
    _emit(
      paywallSeenEvent,
      source: context.source,
      surface: context.surface,
      entryCount: context.entryCount,
      experimentArea: RevenueLiftExperimentV2Area.paywallCta,
    );
  }

  static void _emit(
    String event, {
    required String source,
    required String surface,
    required int entryCount,
    required RevenueLiftExperimentV2Area experimentArea,
  }) {
    final props = <String, Object>{
      'source': source,
      'surface': surface,
      'entry_count': entryCount,
      'experiment_area': experimentArea.analyticsValue,
    };
    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: source,
      entryCount: entryCount,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_REVENUE_LIFT_V2 event=$event source=$source '
        'surface=$surface entry_count=$entryCount '
        'experiment_area=${experimentArea.analyticsValue}',
      );
    }
  }

  static bool isMetadataOnly(Map<String, Object> props) {
    const allowed = {'source', 'surface', 'entry_count', 'experiment_area'};
    if (!props.keys.every(allowed.contains)) return false;
    for (final banned in RevenueLiftExperimentV2Copy.bannedPrivateMarkers) {
      for (final value in props.values) {
        if (value.toString().toLowerCase().contains(banned.toLowerCase())) {
          return false;
        }
      }
    }
    return true;
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
