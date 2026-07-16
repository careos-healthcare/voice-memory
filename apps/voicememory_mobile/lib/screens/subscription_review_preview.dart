import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../billing/archive_paywall_copy.dart';
import '../features/paywall/archive_loop_entitlements.dart';
import '../product/consumer_ui_copy.dart';
import '../theme/voicememory_colors.dart';
import '../theme/voicememory_typography.dart';

/// Static paywall for App Store subscription review screenshots only.
///
/// Open via `/subscription-review-preview` (iPhone 15 Pro: 393×852 logical).
class SubscriptionReviewPreviewScreen extends StatefulWidget {
  const SubscriptionReviewPreviewScreen({super.key});

  @override
  State<SubscriptionReviewPreviewScreen> createState() =>
      _SubscriptionReviewPreviewScreenState();
}

enum _ReviewPlan { monthly, yearly }

class _SubscriptionReviewPreviewScreenState
    extends State<SubscriptionReviewPreviewScreen> {
  _ReviewPlan _selected = _ReviewPlan.yearly;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: VoiceMemoryColors.background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 36,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _brandHeader(),
                      const SizedBox(height: 22),
                      Text(
                        ConsumerUiCopy.paywallHeadline,
                        style: VoiceMemoryTypography.sectionTitleStyle()
                            .copyWith(
                              fontSize: 26,
                              height: 1.2,
                              letterSpacing: -0.4,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        ConsumerUiCopy.paywallSubhead,
                        style: VoiceMemoryTypography.metadataStyle(),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 22),
                      Text(
                        ArchiveLoopPaywallCopy.subscriptionAutoRenewingSummary,
                        style: VoiceMemoryTypography.metadataStyle(),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      _planCard(
                        plan: _ReviewPlan.monthly,
                        title: ArchiveLoopPaywallCopy.subscriptionMonthlyTitle,
                        price: '£4.99/month',
                        badge: null,
                        helper: ArchiveLoopPaywallCopy.subscriptionMonthlyDuration,
                      ),
                      const SizedBox(height: 12),
                      _planCard(
                        plan: _ReviewPlan.yearly,
                        title: ArchiveLoopPaywallCopy.subscriptionYearlyTitle,
                        price: '£39.99/year',
                        badge: 'Save 33%',
                        helper: ArchiveLoopPaywallCopy.subscriptionYearlyDuration,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () {},
                        style: FilledButton.styleFrom(
                          backgroundColor: VoiceMemoryColors.primaryIndigo,
                          foregroundColor: VoiceMemoryColors.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          ConsumerUiCopy.paywallPrimaryCta,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          TextButton(
                            onPressed: () {},
                            child: const Text(ArchiveLoopPaywallCopy.eulaLabel),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: const Text(
                              ArchiveLoopPaywallCopy.privacyPolicyLabel,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _brandHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        gradient: VoiceMemoryColors.beliefGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'ArchiveMe',
            style: VoiceMemoryTypography.pageTitleStyle(
              color: VoiceMemoryColors.onPrimary,
            ).copyWith(fontSize: 32, letterSpacing: -0.6),
          ),
          const SizedBox(height: 6),
          Text(
            ArchivePaywallCopy.screenTitle,
            style: TextStyle(
              color: VoiceMemoryColors.onPrimary.withValues(alpha: 0.92),
              fontSize: 15,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _planCard({
    required _ReviewPlan plan,
    required String title,
    required String price,
    required String helper,
    required String? badge,
  }) {
    final selected = _selected == plan;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selected = plan),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? VoiceMemoryColors.surface
                : VoiceMemoryColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? VoiceMemoryColors.primaryIndigo
                  : VoiceMemoryColors.border,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: VoiceMemoryColors.primaryIndigo.withValues(
                        alpha: 0.12,
                      ),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected
                    ? VoiceMemoryColors.primaryIndigo
                    : VoiceMemoryColors.textTertiary,
                size: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      price,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: selected
                            ? VoiceMemoryColors.primaryIndigo
                            : VoiceMemoryColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      helper,
                      style: TextStyle(
                        fontSize: 13,
                        color: VoiceMemoryColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: VoiceMemoryColors.discoveryGoldBackground,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: VoiceMemoryColors.discoveryGoldBorder,
                    ),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: VoiceMemoryColors.discoveryGold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
