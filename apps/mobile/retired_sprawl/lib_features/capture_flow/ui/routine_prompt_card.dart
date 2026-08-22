import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/capture_flow/routine/routine_prompt_copy.dart';
import 'package:archiveme_mobile/features/insights/rag/routine_rag_models.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

class RoutinePromptCard extends StatelessWidget {
  const RoutinePromptCard({
    required this.prompt,
    required this.onSelectPrompt,
    required this.onDismiss,
    super.key,
  });

  final RoutineJournalPrompt prompt;
  final ValueChanged<String> onSelectPrompt;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final helperStyle = ArchiveMobileTypography.responsiveHelper(context)
        .copyWith(color: AppColors.textSecondary, height: 1.45);

    return Container(
      key: const Key('routine_prompt_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      decoration: VoiceMemoryCards.standard(
        background: AppColors.backgroundSecondary.withValues(alpha: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  RoutinePromptCopy.eyebrow(prompt.routine),
                  key: const Key('routine_prompt_eyebrow'),
                  style: helperStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                key: const Key('routine_prompt_skip'),
                onPressed: onDismiss,
                child: const Text(RoutinePromptCopy.skipAction),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            prompt.primaryPrompt,
            key: const Key('routine_prompt_primary'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context)
                .copyWith(fontSize: 18, height: 1.35),
          ),
          if (prompt.supportingPrompts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final line in prompt.supportingPrompts)
                  ActionChip(
                    label: Text(
                      line,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () => onSelectPrompt(line),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            RoutinePromptCopy.groundedNote,
            style: helperStyle.copyWith(fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            key: const Key('routine_prompt_use_primary'),
            onPressed: () => onSelectPrompt(prompt.primaryPrompt),
            child: const Text('Use this prompt'),
          ),
        ],
      ),
    );
  }
}
