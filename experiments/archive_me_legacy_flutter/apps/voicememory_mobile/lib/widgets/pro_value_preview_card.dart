import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/archive_mobile_typography.dart';
import '../features/pro/pro_value_preview_copy.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_cards.dart';

/// Subtle archive-home promo for Pro value — dismissible, 3+ entries only.
class ProValuePreviewPromoCard extends StatelessWidget {
  const ProValuePreviewPromoCard({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('pro_value_preview_promo_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ProValuePreviewCopy.archiveCardTitle,
            key: const Key('pro_value_preview_promo_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('pro_value_preview_promo_dismiss'),
                  onPressed: onDismiss,
                  child: const Text(ProValuePreviewCopy.archiveCardDismiss),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: FilledButton(
                  key: const Key('pro_value_preview_promo_cta'),
                  onPressed: () => context.push('/pro-preview'),
                  child: const Text(ProValuePreviewCopy.archiveCardCta),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
