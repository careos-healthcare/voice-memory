import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/memory/memory_control_model.dart';
import 'package:archiveme_mobile/features/memory/memory_priority_decision.dart';
import 'package:archiveme_mobile/features/memory/memory_priority_score.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Safe priority explanation — no notes, ids, dates, or names.
class MemoryPriorityExplanationSheet extends StatelessWidget {
  const MemoryPriorityExplanationSheet({
    required this.cardType, required this.safeExplanationId, super.key,
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