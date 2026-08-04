import '../../billing/paywall_source.dart';
import '../beta/archive_beta_mission_gate.dart';
import 'paywall_cta_lift_copy.dart';
import 'paywall_cta_lift_model.dart';

abstract final class PaywallCtaLiftEngine {
  PaywallCtaLiftEngine._();

  static PaywallCtaLiftResult build({
    required PaywallSource? source,
    required String analyticsSource,
    required bool isPro,
  }) {
    final shouldShow = shouldShowBlock(source: source, isPro: isPro);
    if (!shouldShow) {
      return PaywallCtaLiftResult.hidden;
    }

    return PaywallCtaLiftResult(
      shouldShow: true,
      title: PaywallCtaLiftCopy.title,
      body: PaywallCtaLiftCopy.body,
      supportLine: PaywallCtaLiftCopy.supportLine,
      purchaseCtaLine: PaywallCtaLiftCopy.purchaseCtaLine,
      source: analyticsSource,
      proofConnected: true,
    );
  }

  static bool shouldShowBlock({
    required PaywallSource? source,
    required bool isPro,
  }) {
    if (!ArchiveBetaMissionGate.isEnabled) return false;
    if (isPro) return false;
    return source == PaywallSource.valueMoment;
  }
}
