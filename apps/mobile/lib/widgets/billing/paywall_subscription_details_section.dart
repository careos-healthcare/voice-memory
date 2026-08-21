import 'package:archiveme_mobile/billing/revenuecat_diagnostics_log.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/paywall/archive_loop_entitlements.dart';
import 'package:archiveme_mobile/features/pro_packaging/pro_value_copy.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Required auto-renewable subscription metadata for App Store review (3.1.2c).
class PaywallSubscriptionDetailsSection extends StatelessWidget {
  const PaywallSubscriptionDetailsSection({
    super.key,
    this.monthlyPrice,
    this.yearlyPrice,
    this.plansAvailable = true,
  });

  final String? monthlyPrice;
  final String? yearlyPrice;
  final bool plansAvailable;

  static Future<void> openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      RevenueCatDiagnosticsLog.externalLinkFailed(url: url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthlyPriceText =
        monthlyPrice ?? ArchiveLoopPaywallCopy.subscriptionPriceUnavailable;
    final yearlyPriceText =
        yearlyPrice ?? ArchiveLoopPaywallCopy.subscriptionPriceUnavailable;
    final priceLines = <String>[
      '${ArchiveLoopPaywallCopy.subscriptionMonthlyTitle}: '
          '$monthlyPriceText · ${ArchiveLoopPaywallCopy.subscriptionMonthlyDuration}',
      '${ArchiveLoopPaywallCopy.subscriptionYearlyTitle}: '
          '$yearlyPriceText · ${ArchiveLoopPaywallCopy.subscriptionYearlyDuration}',
    ];
    if (!plansAvailable) {
      priceLines.add(ArchiveLoopPaywallCopy.subscriptionPlansUnavailable);
    }

    return Container(
      key: const Key('paywall_subscription_details'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: VoiceMemoryColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ProPackagingCopy.title,
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: 6),
          Text(
            ArchiveLoopPaywallCopy.subscriptionAutoRenewingSummary,
            style: ArchiveMobileTypography.responsiveBody(context),
          ),
          const SizedBox(height: 10),
          Text(
            ArchiveLoopPaywallCopy.subscriptionDetailsTitle,
            style: ArchiveMobileTypography.cardLabel(context),
          ),
          for (final line in priceLines) ...[
            const SizedBox(height: 6),
            Text(
              line,
              style: ArchiveMobileTypography.responsiveHelper(context),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            ArchiveLoopPaywallCopy.subscriptionAutoRenewal,
            style: ArchiveMobileTypography.responsiveHelper(context),
          ),
          const SizedBox(height: 4),
          Text(
            ArchiveLoopPaywallCopy.subscriptionCancellation,
            style: ArchiveMobileTypography.responsiveHelper(context),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              TextButton(
                key: const Key('paywall_terms_of_use_link'),
                onPressed: () => openUrl(ArchiveLoopPaywallCopy.eulaUrl),
                child: const Text(ArchiveLoopPaywallCopy.eulaLabel),
              ),
              TextButton(
                key: const Key('paywall_privacy_policy_link'),
                onPressed: () =>
                    openUrl(ArchiveLoopPaywallCopy.privacyPolicyUrl),
                child: const Text(ArchiveLoopPaywallCopy.privacyPolicyLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}