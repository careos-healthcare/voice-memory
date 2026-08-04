import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/memory/memory_control_model.dart';
import '../../features/memory/memory_governance_decision.dart';
import '../../features/memory/memory_priority_decision.dart';
import '../../features/memory/memory_visibility_receipt.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../theme/app_colors.dart';
import 'memory_priority_explanation_sheet.dart';

/// Visible receipt when a memory card used archive context.
class MemoryUsedReceipt extends StatelessWidget {
  const MemoryUsedReceipt({
    super.key,
    required this.cardType,
    required this.memoryUsed,
    this.entryCount = 1,
    this.governance,
    this.priority,
  });

  final MemoryCardType cardType;
  final bool memoryUsed;
  final int entryCount;
  final MemoryGovernanceDecision? governance;
  final MemoryPriorityDecision? priority;

  @override
  Widget build(BuildContext context) {
    if (!MemoryVisibilityReceipt.shouldShow(
      cardType: cardType,
      memoryUsed: memoryUsed,
      entryCount: entryCount,
      governance: governance,
      priority: priority,
    )) {
      return const SizedBox.shrink();
    }

    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.memoryUsedReceiptSeen,
      cardType: cardType.id,
      oncePerSession: true,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          Container(
            key: const Key('memory_used_receipt'),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                const Icon(
                  Icons.inventory_2_outlined,
                  size: 13,
                  color: AppColors.textSecondary,
                ),
                Text(
                  MemoryControlCopy.usedArchiveContextLabel,
                  style: ArchiveMobileTypography.responsiveHelper(context)
                      .copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          TextButton(
            key: Key('memory_used_receipt_why_${cardType.id}'),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              foregroundColor: AppColors.textSecondary,
            ),
            onPressed: () {
              ActivationFunnelAnalytics.track(
                ActivationFunnelAnalytics.memoryUsedReceiptOpened,
                cardType: cardType.id,
              );
              MemoryPriorityExplanationSheet.show(
                context,
                cardType,
                safeExplanationId: priority?.safeExplanationId,
              );
            },
            child: Text(
              MemoryControlCopy.whyLabel,
              style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
