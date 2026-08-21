import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/memory/cross_thread_confirmation.dart';
import 'package:archiveme_mobile/features/memory/memory_authority_framing_engine.dart';
import 'package:archiveme_mobile/features/memory/memory_control_model.dart';
import 'package:archiveme_mobile/features/memory/memory_reliability_check.dart';
import 'package:archiveme_mobile/features/memory/memory_scope.dart';
import 'package:archiveme_mobile/features/memory/memory_scope_policy.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Shown before a strong cross-thread memory claim renders.
class CrossThreadConfirmationCard extends StatelessWidget {
  const CrossThreadConfirmationCard({
    required this.cardType, required this.onChanged, super.key,
  });

  final MemoryCardType cardType;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.crossThreadConfirmationSeen,
      cardType: cardType.id,
      memoryScope: MemoryScopePolicy.scope.id,
      oncePerSession: true,
    );

    return Container(
      key: const Key('cross_thread_confirmation_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            MemoryControlCopy.crossThreadTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            MemoryControlCopy.crossThreadBody,
            style: ArchiveMobileTypography.body(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const Key('cross_thread_connect'),
            onPressed: () {
              CrossThreadConfirmation.approve(cardType);
              onChanged();
            },
            child: const Text(MemoryControlCopy.crossThreadConnectLabel),
          ),
          TextButton(
            key: const Key('cross_thread_keep_separate'),
            onPressed: () {
              CrossThreadConfirmation.keepSeparate(
                cardType,
                threadId: CrossThreadDetector.primaryThreadId(
                  MemoryAuthorityFrameLog.candidatesFor(cardType),
                ),
              );
              ActivationFunnelAnalytics.track(
                ActivationFunnelAnalytics.crossThreadConnectionKeptSeparate,
                cardType: cardType.id,
                memoryScope: MemoryScopePolicy.scope.id,
              );
              onChanged();
            },
            child: const Text(MemoryControlCopy.crossThreadKeepSeparateLabel),
          ),
        ],
      ),
    );
  }
}