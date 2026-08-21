import 'package:archiveme_mobile/config/screenshot_mode.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_return_trigger_models.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

/// Completion or archive-home card for the capacity return trigger.
class CapacityReturnTriggerCard extends StatelessWidget {
  const CapacityReturnTriggerCard({
    required this.result, super.key,
    this.onPrimaryDismiss,
    this.onSecondary,
    this.sampleMode = false,
  });

  const CapacityReturnTriggerCard.test({
    required this.result, super.key,
    this.onPrimaryDismiss,
    this.onSecondary,
    this.sampleMode = false,
  });

  final CapacityReturnTriggerResult result;
  final VoidCallback? onPrimaryDismiss;
  final VoidCallback? onSecondary;
  final bool sampleMode;

  @override
  Widget build(BuildContext context) {
    if (sampleMode || ScreenshotMode.enabled || !result.showCard) {
      return const SizedBox.shrink(
        key: Key('capacity_return_trigger_card_hidden'),
      );
    }

    return Container(
      key: const Key('capacity_return_trigger_card'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.title,
            key: const Key('capacity_return_trigger_card_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.body,
            key: const Key('capacity_return_trigger_card_body'),
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const Key('capacity_return_trigger_card_primary_button'),
            onPressed: () {
              if (result.primaryDismisses) {
                onPrimaryDismiss?.call();
                return;
              }
              if (result.primaryRoute.isNotEmpty) {
                unawaited(context.push(result.primaryRoute));
              }
            },
            child: Text(result.primaryCtaLabel),
          ),
          if (result.showSecondary) ...[
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton(
              key: const Key('capacity_return_trigger_card_secondary_button'),
              onPressed: () {
                if (result.secondaryRoute.isNotEmpty) {
                  unawaited(context.push(result.secondaryRoute));
                  return;
                }
                onSecondary?.call();
              },
              child: Text(result.secondaryCtaLabel),
            ),
          ],
        ],
      ),
    );
  }
}