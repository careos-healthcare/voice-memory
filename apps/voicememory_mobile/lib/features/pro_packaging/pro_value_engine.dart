import '../beta_improvement/beta_improvement_pack_engine.dart';
import '../beta_improvement/pro_packaging_copy_fix.dart';
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
    final branchHeadline = BetaImprovementPackEngine.paywallHeadline();
    final branchSubhead = BetaImprovementPackEngine.paywallSubheadline();
    final branchBullets = BetaImprovementPackEngine.paywallBullets();

    return ProPackagingDisplay(
      title: branchHeadline ?? ProPackagingCopy.title,
      subtitle: branchSubhead ?? ProPackagingCopy.subtitle,
      free: ProPackagingSection(
        title: ProPackagingCopy.freeSectionTitle,
        bullets: branchHeadline != null
            ? [ProPackagingCopyFix.freeValue]
            : ProPackagingCopy.freeBullets,
      ),
      pro: ProPackagingSection(
        title: ProPackagingCopy.proSectionTitle,
        bullets: branchBullets ?? ProPackagingCopy.proBullets,
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
