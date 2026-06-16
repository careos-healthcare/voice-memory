import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/memory/memory_control_model.dart';
import '../../features/memory/memory_priority_decision.dart';
import '../../features/memory/memory_priority_score.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Safe priority explanation — no notes, ids, dates, or names.
class MemoryPriorityExplanationSheet extends StatelessWidget {
  const MemoryPriorityExplanationSheet({
    super.key,
    required this.cardType,
    required this.safeExplanationId,
  });

  final MemoryCardType cardType;
  final String safeExplanationId;

  static Future<void> show(
    BuildContext context,
    MemoryCardType cardType, {
    String? safeExplanationId,
  }) {
    final id =
        safeExplanationId ??
        MemoryPriorityDecisionLog.lastFor(cardType)?.safeExplanationId ??
        MemoryPriorityExplanationId.recentRelated;
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.memoryPriorityExplanationOpened,
      cardType: cardType.id,
      reasonId: id,
    );
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => MemoryPriorityExplanationSheet(
        cardType: cardType,
        safeExplanationId: id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final priorityLine = MemoryPriorityCopy.explanationFor(safeExplanationId);
    return SafeArea(
      child: Padding(
        key: const Key('memory_priority_explanation_sheet'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              MemoryControlCopy.whyTitle,
              style: ArchiveMobileTypography.responsiveSectionTitle(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              priorityLine,
              key: Key('memory_priority_reason_$safeExplanationId'),
              style: ArchiveMobileTypography.body(
                context,
              ).copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              MemoryControlCopy.whyBodyShared,
              style: ArchiveMobileTypography.responsiveHelper(
                context,
              ).copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              MemoryControlCopy.whyCorrectionFooter,
              style: ArchiveMobileTypography.responsiveHelper(
                context,
              ).copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
