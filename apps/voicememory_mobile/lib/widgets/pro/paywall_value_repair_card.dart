import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/paywall_value_repair/paywall_value_repair_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

class PaywallValueRepairCard extends StatefulWidget {
  const PaywallValueRepairCard({
    super.key,
    required this.result,
    required this.onSeePro,
    this.compact = false,
  });

  const PaywallValueRepairCard.test({
    super.key,
    required this.result,
    required this.onSeePro,
    this.compact = false,
  });

  final PaywallValueRepairResult result;
  final VoidCallback onSeePro;
  final bool compact;

  @override
  State<PaywallValueRepairCard> createState() => _PaywallValueRepairCardState();
}

class _PaywallValueRepairCardState extends State<PaywallValueRepairCard> {
  var _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed || !widget.result.shouldShow) {
      return const SizedBox.shrink(
        key: Key('paywall_value_repair_card_hidden'),
      );
    }

    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.45,
    );

    return Container(
      key: const Key('paywall_value_repair_card'),
      width: double.infinity,
      padding: EdgeInsets.all(widget.compact ? AppSpacing.sm : AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.result.title,
            key: const Key('paywall_value_repair_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          SizedBox(height: widget.compact ? AppSpacing.xs : AppSpacing.sm),
          Text(
            widget.result.body,
            key: const Key('paywall_value_repair_body'),
            style: bodyStyle.copyWith(color: AppColors.textPrimary),
          ),
          SizedBox(height: widget.compact ? AppSpacing.sm : AppSpacing.md),
          for (final bullet in widget.result.bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: bodyStyle.copyWith(color: AppColors.textPrimary)),
                  Expanded(
                    child: Text(
                      bullet,
                      key: Key('paywall_value_repair_bullet_$bullet'),
                      style: bodyStyle.copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          Text(
            widget.result.supportLine,
            key: const Key('paywall_value_repair_support'),
            style: bodyStyle,
          ),
          SizedBox(height: widget.compact ? AppSpacing.sm : AppSpacing.md),
          FilledButton(
            key: const Key('paywall_value_repair_primary_cta'),
            onPressed: widget.onSeePro,
            child: Text(widget.result.primaryCta),
          ),
          TextButton(
            key: const Key('paywall_value_repair_secondary_cta'),
            onPressed: () => setState(() => _dismissed = true),
            child: Text(widget.result.secondaryCta),
          ),
        ],
      ),
    );
  }
}
