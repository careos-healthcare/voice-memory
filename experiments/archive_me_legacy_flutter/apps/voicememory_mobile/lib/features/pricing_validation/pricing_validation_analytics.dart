import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import 'pricing_validation_model.dart';

enum PricingValidationEventType {
  seen('pricing_validation_seen'),
  priceSelected('pricing_validation_price_selected'),
  reasonSelected('pricing_validation_reason_selected'),
  ctaTapped('pricing_validation_cta_tapped');

  const PricingValidationEventType(this.analyticsName);

  final String analyticsName;
}

@immutable
class PricingValidationEvent {
  const PricingValidationEvent({
    required this.type,
    required this.source,
    required this.entryCount,
    required this.hasUsefulProof,
    required this.activeRepairMode,
    this.selectedPrice,
    this.selectedReason,
  });

  final PricingValidationEventType type;
  final String source;
  final int entryCount;
  final bool hasUsefulProof;
  final String activeRepairMode;
  final PricingValidationPriceOption? selectedPrice;
  final PricingValidationReasonOption? selectedReason;

  Map<String, Object> get analyticsProperties => {
    'source': source,
    'entry_count': entryCount,
    'has_useful_proof': hasUsefulProof,
    'active_repair_mode': activeRepairMode,
    if (selectedPrice case final value?)
      'pricing_value_state': value.valueStateToken,
    if (selectedReason case final value?) 'pricing_reason': value.reasonToken,
  };
}

abstract final class PricingValidationAnalytics {
  PricingValidationAnalytics._();

  static final seenEvent = PricingValidationEventType.seen.analyticsName;
  static final priceSelectedEvent =
      PricingValidationEventType.priceSelected.analyticsName;
  static final reasonSelectedEvent =
      PricingValidationEventType.reasonSelected.analyticsName;
  static final ctaTappedEvent =
      PricingValidationEventType.ctaTapped.analyticsName;

  @visibleForTesting
  static void Function(PricingValidationEvent event)? captureForTest;

  static void seen({required PricingValidationResult result}) {
    _emit(PricingValidationEventType.seen, result: result);
  }

  static void priceSelected({
    required PricingValidationResult result,
    required PricingValidationPriceOption price,
  }) {
    _emit(
      PricingValidationEventType.priceSelected,
      result: result,
      selectedPrice: price,
    );
  }

  static void reasonSelected({
    required PricingValidationResult result,
    required PricingValidationReasonOption reason,
  }) {
    _emit(
      PricingValidationEventType.reasonSelected,
      result: result,
      selectedReason: reason,
    );
  }

  static void ctaTapped({required PricingValidationResult result}) {
    _emit(PricingValidationEventType.ctaTapped, result: result);
  }

  static void _emit(
    PricingValidationEventType type, {
    required PricingValidationResult result,
    PricingValidationPriceOption? selectedPrice,
    PricingValidationReasonOption? selectedReason,
  }) {
    final event = PricingValidationEvent(
      type: type,
      source: result.source,
      entryCount: result.entryCount,
      hasUsefulProof: result.hasUsefulProof,
      activeRepairMode: result.activeRepairMode,
      selectedPrice: selectedPrice,
      selectedReason: selectedReason,
    );
    captureForTest?.call(event);
    ActivationFunnelAnalytics.track(
      type.analyticsName,
      source: result.source,
      entryCount: result.entryCount,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_PRICING_VALIDATION event=${type.analyticsName} '
        'source=${result.source} '
        'entry_count=${result.entryCount} '
        'has_useful_proof=${result.hasUsefulProof} '
        'active_repair_mode=${result.activeRepairMode} '
        'pricing_value_state=${selectedPrice?.valueStateToken} '
        'pricing_reason=${selectedReason?.reasonToken}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
