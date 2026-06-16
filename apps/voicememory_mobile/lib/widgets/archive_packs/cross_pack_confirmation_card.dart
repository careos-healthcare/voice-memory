import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/archive_packs/archive_pack.dart';
import '../../features/archive_packs/cross_pack_confirmation.dart';
import '../../features/memory/memory_control_model.dart';
import '../../features/memory/memory_scope.dart';
import '../../features/memory/memory_scope_policy.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Shown before a strong cross-pack memory claim renders.
class CrossPackConfirmationCard extends StatelessWidget {
  const CrossPackConfirmationCard({
    super.key,
    required this.cardType,
    required this.onChanged,
  });

  final MemoryCardType cardType;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.crossPackConfirmationSeen,
      cardType: cardType.id,
      memoryScope: MemoryScopePolicy.scope.id,
      oncePerSession: true,
    );

    return Container(
      key: const Key('cross_pack_confirmation_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ArchivePacksCopy.crossPackTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ArchivePacksCopy.crossPackBody,
            style: ArchiveMobileTypography.body(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const Key('cross_pack_connect'),
            onPressed: () {
              CrossPackConfirmation.approve(cardType.id);
              onChanged();
            },
            child: Text(ArchivePacksCopy.crossPackConnect),
          ),
          TextButton(
            key: const Key('cross_pack_keep_separate'),
            onPressed: () {
              CrossPackConfirmation.keepSeparate(cardType.id);
              onChanged();
            },
            child: Text(ArchivePacksCopy.crossPackKeepSeparate),
          ),
        ],
      ),
    );
  }
}
