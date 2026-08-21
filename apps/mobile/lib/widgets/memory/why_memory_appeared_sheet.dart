import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/memory/memory_control_model.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// High-level "Why this appeared" sheet for memory-based cards.
///
/// Every line is a compile-time constant: no notes, transcripts, entry
/// ids, dates, names, snippets, or belief phrases can ever appear here.
/// Evidence snippets live on the cards themselves, where they already
/// exist — this sheet stays general on purpose.
class WhyMemoryAppearedSheet extends StatelessWidget {
  const WhyMemoryAppearedSheet({required this.cardType, super.key});

  final MemoryCardType cardType;

  static Future<void> show(BuildContext context, MemoryCardType cardType) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.memoryWhyThisAppearedOpened,
      cardType: cardType.id,
    );
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => WhyMemoryAppearedSheet(cardType: cardType),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        key: const Key('why_memory_appeared_sheet'),
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
              cardType.whyBody,
              style: ArchiveMobileTypography.body(
                context,
              ).copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              MemoryControlCopy.whyFooter,
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

/// Small secondary action that opens [WhyMemoryAppearedSheet].
class WhyThisAppearedAction extends StatelessWidget {
  const WhyThisAppearedAction({required this.cardType, super.key});

  final MemoryCardType cardType;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: Key('why_this_appeared_${cardType.id}'),
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        foregroundColor: AppColors.textSecondary,
      ),
      onPressed: () => WhyMemoryAppearedSheet.show(context, cardType),
      child: Text(
        MemoryControlCopy.whyLabel,
        style: ArchiveMobileTypography.responsiveHelper(
          context,
        ).copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
      ),
    );
  }
}