import 'package:archiveme_mobile/features/pro_interest/pro_interest_copy.dart';
import 'package:archiveme_mobile/features/pro_interest/pro_interest_models.dart';

/// Deterministic Pro interest interpretation — local only.
class ProInterestEngine {
  const ProInterestEngine();

  List<String> interpretations(ProInterestState state) {
    final lines = <String>[];
    if (!state.hasCapture) {
      lines.add(ProInterestCopy.interpretationNotCaptured);
      return lines;
    }
    if (state.selectedValueIds.isEmpty) {
      lines.add(ProInterestCopy.interpretationProValueUnclear);
    }
    if (state.pricingIntentId == ProInterestPricingIntentId.lowMonthly ||
        state.pricingIntentId == ProInterestPricingIntentId.yearly) {
      if (state.selectedValueIds.isNotEmpty) {
        lines.add(ProInterestCopy.interpretationRevenueSignal);
      }
    }
    if (state.pricingIntentId == ProInterestPricingIntentId.freeFirst ||
        state.pricingIntentId == ProInterestPricingIntentId.notEnoughValue) {
      lines.add(ProInterestCopy.interpretationValueNeedsProof);
    }
    return lines;
  }
}