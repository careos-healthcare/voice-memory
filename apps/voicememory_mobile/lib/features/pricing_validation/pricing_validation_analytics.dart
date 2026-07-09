import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import 'pricing_validation_model.dart';

abstract final class PricingValidationAnalytics {
  PricingValidationAnalytics._();

  static const seenEvent = 'pricing_validation_seen';
  static const priceSelectedEvent = 'pricing_validation_price_selected';
  static const reasonSelectedEvent = 'pricing_validation_reason_selected';
  static const ctaTappedEvent = 'pricing_validation_cta_tapped';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
      captureForTest;

  static void seen({required PricingValidationResult result}) {
    _emit(seenEvent, result: result);
  }

  static void priceSelected({
    required PricingValidationResult result,
    required PricingValidationPriceOption price,
  }) {
    final props = <String, Object>{
      'source': result.source,
      'entry_count': result.entryCount,
      'selected_price': price.analyticsValue,
      'has_useful_proof': result.hasUsefulProof,
      'active_repair_mode': result.activeRepairMode,
    };
    captureForTest?.call(priceSelectedEvent, props);
    ActivationFunnelAnalytics.track(
      priceSelectedEvent,
      source: result.source,
      entryCount: result.entryCount,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_PRICING_VALIDATION event=$priceSelectedEvent '
        'source=${result.source} entry_count=${result.entryCount} '
        'selected_price=${price.analyticsValue} '
        'has_useful_proof=${result.hasUsefulProof} '
        'active_repair_mode=${result.activeRepairMode}',
      );
    }
  }

  static void reasonSelected({
    required PricingValidationResult result,
    required PricingValidationReasonOption reason,
  }) {
    final props = <String, Object>{
      'source': result.source,
      'entry_count': result.entryCount,
      'selected_reason': reason.analyticsValue,
      'has_useful_proof': result.hasUsefulProof,
      'active_repair_mode': result.activeRepairMode,
    };
    captureForTest?.call(reasonSelectedEvent, props);
    ActivationFunnelAnalytics.track(
      reasonSelectedEvent,
      source: result.source,
      entryCount: result.entryCount,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_PRICING_VALIDATION event=$reasonSelectedEvent '
        'source=${result.source} entry_count=${result.entryCount} '
        'selected_reason=${reason.analyticsValue} '
        'has_useful_proof=${result.hasUsefulProof} '
        'active_repair_mode=${result.activeRepairMode}',
      );
    }
  }

  static void ctaTapped({required PricingValidationResult result}) {
    _emit(ctaTappedEvent, result: result);
  }

  static void _emit(
    String event, {
    required PricingValidationResult result,
  }) {
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
        'ARCHIVEME_PRICING_VALIDATION event=$event source=${result.source} '
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
