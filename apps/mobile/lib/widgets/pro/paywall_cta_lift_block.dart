import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/paywall_cta_lift/paywall_cta_lift_analytics.dart';
import 'package:archiveme_mobile/features/paywall_cta_lift/paywall_cta_lift_model.dart';
import 'package:archiveme_mobile/features/revenue_lift_experiment_v2/revenue_lift_experiment_v2_analytics.dart';
import 'package:archiveme_mobile/features/revenue_lift_experiment_v2/revenue_lift_experiment_v2_copy.dart';
import 'package:archiveme_mobile/features/revenue_lift_experiment_v2/revenue_lift_experiment_v2_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

class PaywallCtaLiftBlock extends StatefulWidget {
  const PaywallCtaLiftBlock({required this.result, super.key});

  const PaywallCtaLiftBlock.test({required this.result, super.key});

  final PaywallCtaLiftResult result;

  @override
  State<PaywallCtaLiftBlock> createState() => _PaywallCtaLiftBlockState();
}

class _PaywallCtaLiftBlockState extends State<PaywallCtaLiftBlock> {
  var _trackedSeen = false;

  void _trackSeenOnce() {
    if (_trackedSeen || !widget.result.shouldShow) return;
    _trackedSeen = true;
    PaywallCtaLiftAnalytics.seen(result: widget.result);
    RevenueLiftExperimentV2Analytics.seen(
      context: RevenueLiftExperimentV2SeenContext(
        source: widget.result.source,
        surface: 'paywall_cta_lift_block',
        entryCount: 0,
        area: RevenueLiftExperimentV2Area.paywallCta,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.result.shouldShow) {
      return const SizedBox.shrink(key: Key('paywall_cta_lift_block_hidden'));
    }

    _trackSeenOnce();

    final titleStyle = ArchiveMobileTypography.responsiveSectionTitle(context);
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);

    return Column(
      key: const Key('paywall_cta_lift_block'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.result.title,
          key: const Key('paywall_cta_lift_title'),
          style: titleStyle,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          widget.result.body,
          key: const Key('paywall_cta_lift_body'),
          style: bodyStyle.copyWith(color: AppColors.textPrimary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          widget.result.supportLine,
          key: const Key('paywall_cta_lift_support_line'),
          style: bodyStyle,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}