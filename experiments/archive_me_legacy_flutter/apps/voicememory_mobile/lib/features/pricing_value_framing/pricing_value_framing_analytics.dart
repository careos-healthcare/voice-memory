import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import 'pricing_value_framing_model.dart';

abstract final class PricingValueFramingAnalytics {
  PricingValueFramingAnalytics._();

  static const seenEvent = 'pricing_value_framing_seen';
  static const ctaTappedEvent = 'pricing_value_framing_cta_tapped';
  static const feedbackSelectedEvent =
      'pricing_value_framing_feedback_selected';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void seen({required PricingValueFramingResult result}) {
    _emit(seenEvent, result: result);
  }

  static void ctaTapped({required PricingValueFramingResult result}) {
    _emit(ctaTappedEvent, result: result);
  }

  static void feedbackSelected({
    required PricingValueFramingResult result,
    required PricingValueFramingFeedbackType feedback,
  }) {
    final props = <String, Object>{
      'source': result.source,
      'entry_count': result.entryCount,
      'feedback': feedback.analyticsValue,
      'has_useful_proof': result.hasUsefulProof,
      'active_repair_mode': result.activeRepairMode,
    };
    captureForTest?.call(feedbackSelectedEvent, props);
    ActivationFunnelAnalytics.track(
      feedbackSelectedEvent,
      source: result.source,
      entryCount: result.entryCount,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_PRICING_VALUE_FRAMING event=$feedbackSelectedEvent '
        'source=${result.source} entry_count=${result.entryCount} '
        'feedback=${feedback.analyticsValue} '
        'has_useful_proof=${result.hasUsefulProof} '
        'active_repair_mode=${result.activeRepairMode}',
      );
    }
  }

  static void _emit(String event, {required PricingValueFramingResult result}) {
    final props = <String, Object>{
      'source': result.source,
      'entry_count': result.entryCount,
      'has_useful_proof': result.hasUsefulProof,
      'active_repair_mode': result.activeRepairMode,
    };
    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: result.source,
      entryCount: result.entryCount,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_PRICING_VALUE_FRAMING event=$event source=${result.source} '
        'entry_count=${result.entryCount} '
        'has_useful_proof=${result.hasUsefulProof} '
        'active_repair_mode=${result.activeRepairMode}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
