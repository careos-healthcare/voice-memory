import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/archive_packs/archive_pack.dart';
import 'package:archiveme_mobile/features/archive_packs/cross_pack_confirmation.dart';
import 'package:archiveme_mobile/features/memory/memory_control_model.dart';
import 'package:archiveme_mobile/features/memory/memory_scope.dart';
import 'package:archiveme_mobile/features/memory/memory_scope_policy.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Shown before a strong cross-pack memory claim renders.
class CrossPackConfirmationCard extends StatelessWidget {
  const CrossPackConfirmationCard({
    required this.cardType, required this.onChanged, super.key,
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
            child: const Text(ArchivePacksCopy.crossPackConnect),
          ),
          TextButton(
            key: const Key('cross_pack_keep_separate'),
            onPressed: () {
              CrossPackConfirmation.keepSeparate(cardType.id);
              onChanged();
            },
            child: const Text(ArchivePacksCopy.crossPackKeepSeparate),
          ),
        ],
      ),
    );
  }
}