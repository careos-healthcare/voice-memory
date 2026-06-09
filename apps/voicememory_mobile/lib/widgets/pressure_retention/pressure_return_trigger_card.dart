import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/pressure_retention/pressure_return_trigger_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Offers the return trigger on Pressure Insights. Renders nothing unless the
/// trigger is eligible or already accepted.
///
/// Free users get the full trigger — it is never blocked behind Pro. Pro users
/// see one extra line tying it to their current pattern.
class PressureReturnTriggerCard extends StatelessWidget {
  const PressureReturnTriggerCard({
    super.key,
    required this.trigger,
    required this.isPro,
    required this.onAccept,
    required this.onDismiss,
  });

  final PressureReturnTrigger trigger;
  final bool isPro;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  static const title = 'Come back at the pressure moment';
  static const acceptLabel = "I'll do this";
  static const dismissLabel = 'Not now';

  @override
  Widget build(BuildContext context) {
    if (!trigger.show) return const SizedBox.shrink();

    return Container(
      key: const Key('pressure_return_trigger_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF0F6FF),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.replay_outlined,
                size: 18,
                color: AppColors.accentPrimary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  title,
                  style:
                      ArchiveMobileTypography.responsiveSectionTitle(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            PressureReturnTrigger.triggerCopy,
            style: ArchiveMobileTypography.body(context).copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            PressureReturnTrigger.supportCopy,
            style: ArchiveMobileTypography.body(context).copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (isPro) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              PressureReturnTrigger.proPatternCopy,
              key: const Key('pressure_return_trigger_pro_line'),
              style: ArchiveMobileTypography.body(context).copyWith(
                color: AppColors.accentPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (trigger.accepted)
            Text(
              PressureReturnTrigger.savedCopy,
              key: const Key('pressure_return_trigger_saved'),
              style: ArchiveMobileTypography.body(context).copyWith(
                color: AppColors.accentSecondary,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    key: const Key('pressure_return_trigger_accept'),
                    onPressed: onAccept,
                    child: const Text(acceptLabel),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                    key: const Key('pressure_return_trigger_dismiss'),
                    onPressed: onDismiss,
                    child: const Text(dismissLabel),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
