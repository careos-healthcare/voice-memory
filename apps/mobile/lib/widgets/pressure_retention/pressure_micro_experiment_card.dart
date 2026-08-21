import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_pattern_reveal_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// A single, concrete experiment the user can commit to after seeing their
/// pattern. Accepting it stores a local flag (no notifications).
class PressureMicroExperimentCard extends StatelessWidget {
  const PressureMicroExperimentCard({
    required this.onAccept, required this.onDismiss, super.key,
    this.accepted = false,
  });

  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  /// When true, shows a quiet confirmation instead of the actions.
  final bool accepted;

  static const title = 'A small interruption to try';
  static const String body = PressurePatternReveal.experimentCopy;
  static const acceptLabel = "I'll try this";
  static const dismissLabel = 'Not now';
  static const acceptedCopy = 'Noted. Log what changed when you try it.';

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('pressure_micro_experiment_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFEFF7F4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.science_outlined,
                size: 18,
                color: AppColors.accentSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  title,
                  style: ArchiveMobileTypography.responsiveSectionTitle(
                    context,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            style: ArchiveMobileTypography.body(
              context,
            ).copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.md),
          if (accepted)
            Text(
              acceptedCopy,
              key: const Key('pressure_micro_experiment_accepted'),
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
                    key: const Key('pressure_micro_experiment_accept'),
                    onPressed: onAccept,
                    child: const Text(acceptLabel),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                    key: const Key('pressure_micro_experiment_dismiss'),
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