import 'package:flutter/material.dart';

import '../product/belief_product_copy.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_typography.dart';

class RecordBeliefPromptsSection extends StatelessWidget {
  const RecordBeliefPromptsSection({
    super.key,
    required this.onSelectPrompt,
    this.selectedPrompt,
  });

  final ValueChanged<String> onSelectPrompt;
  final String? selectedPrompt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Question of the day',
          style: VoiceMemoryTypography.metadataStyle(
            color: AppColors.accentPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        _PromptChip(
          label: BeliefProductCopy.questionOfTheDay,
          selected: selectedPrompt == BeliefProductCopy.questionOfTheDay,
          onTap: () => onSelectPrompt(BeliefProductCopy.questionOfTheDay),
          emphasized: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('Other prompts', style: VoiceMemoryTypography.metadataStyle()),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in BeliefProductCopy.recordPrompts)
              _PromptChip(
                label: p,
                selected: selectedPrompt == p,
                onTap: () => onSelectPrompt(p),
              ),
          ],
        ),
      ],
    );
  }
}

class _PromptChip extends StatelessWidget {
  const _PromptChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.emphasized = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.accentLight
          : AppColors.backgroundSecondary,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: emphasized ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.accentPrimary : AppColors.borderSubtle,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: VoiceMemoryTypography.bodyStyle(
              color: emphasized ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
