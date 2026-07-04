import '../../product/consumer_ui_copy.dart';
import 'pro_value_copy.dart';
import 'pro_value_model.dart';

/// Builds display-only Pro packaging — no entitlement or billing logic.
abstract final class ProPackagingEngine {
  ProPackagingEngine._();

  static ProPackagingDisplay build({
    required bool offeringsAvailable,
    required bool showPlanPrices,
    String? purchaseCta,
  }) {
    return ProPackagingDisplay(
      title: ProPackagingCopy.title,
      subtitle: ProPackagingCopy.subtitle,
      free: const ProPackagingSection(
        title: ProPackagingCopy.freeSectionTitle,
        bullets: ProPackagingCopy.freeBullets,
      ),
      pro: const ProPackagingSection(
        title: ProPackagingCopy.proSectionTitle,
        bullets: ProPackagingCopy.proBullets,
      ),
      offeringsAvailable: offeringsAvailable,
      showPlanPrices: showPlanPrices && offeringsAvailable,
      unavailableBody: ProPackagingCopy.offeringsUnavailableBody,
      continueCta: ProPackagingCopy.continueCta,
      purchaseCta: purchaseCta ?? ConsumerUiCopy.paywallPrimaryCta,
      restoreLabel: ProPackagingCopy.restorePurchases,
    );
  }
}
