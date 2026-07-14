import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/paywall/archive_loop_entitlements.dart';
import '../../features/pro_packaging/pro_value_copy.dart';
import '../../theme/voicememory_colors.dart';

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
      debugPrint('PaywallSubscriptionDetailsSection: could not open $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final priceLines = <String>[];
    if (plansAvailable && monthlyPrice != null && yearlyPrice != null) {
      priceLines.add(
        '${ArchiveLoopPaywallCopy.subscriptionMonthlyTitle}: '
        '$monthlyPrice · ${ArchiveLoopPaywallCopy.subscriptionMonthlyDuration}',
      );
      priceLines.add(
        '${ArchiveLoopPaywallCopy.subscriptionYearlyTitle}: '
        '$yearlyPrice · ${ArchiveLoopPaywallCopy.subscriptionYearlyDuration}',
      );
    } else if (plansAvailable && monthlyPrice != null) {
      priceLines.add(
        '${ArchiveLoopPaywallCopy.subscriptionMonthlyTitle}: $monthlyPrice',
      );
    } else if (plansAvailable && yearlyPrice != null) {
      priceLines.add(
        '${ArchiveLoopPaywallCopy.subscriptionYearlyTitle}: $yearlyPrice',
      );
    } else {
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
                onPressed: () => openUrl(ArchiveLoopPaywallCopy.privacyPolicyUrl),
                child: const Text(ArchiveLoopPaywallCopy.privacyPolicyLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
