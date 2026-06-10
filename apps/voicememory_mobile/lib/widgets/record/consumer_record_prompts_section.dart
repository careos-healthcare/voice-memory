import 'package:flutter/material.dart';

import '../../features/pressure_retention/personal_return_prompt_model.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';
import 'record_help_prompt_sheet.dart';

class ConsumerRecordPromptsSection extends StatelessWidget {
  const ConsumerRecordPromptsSection({
    super.key,
    required this.onSelectPrompt,
    this.selectedPrompt,
    this.personalPrompts,
  });

  final ValueChanged<String> onSelectPrompt;
  final String? selectedPrompt;

  /// Prompts built from the user's own entries; when null or empty the
  /// generic starter prompts are shown.
  final PersonalReturnPromptSet? personalPrompts;

  @override
  Widget build(BuildContext context) {
    final personalized = personalPrompts?.personalized == true &&
        personalPrompts!.prompts.isNotEmpty;
    final prompts = personalized
        ? personalPrompts!.prompts
        : ConsumerUiCopy.recordStarterPrompts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ConsumerUiCopy.trySayingOneOfThese,
          style: VoiceMemoryTypography.metadataStyle(
            color: AppColors.accentPrimary,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        if (personalized) ...[
          const SizedBox(height: 2),
          Text(
            PersonalReturnPromptSet.personalizedLabel,
            key: const Key('personal_prompts_label'),
            style: VoiceMemoryTypography.metadataStyle(
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        for (final prompt in prompts)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: _StarterCard(
              prompt: prompt,
              selected: selectedPrompt == prompt,
              onTap: () => onSelectPrompt(prompt),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Or pick a topic',
          style: VoiceMemoryTypography.metadataStyle(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final topic in ConsumerUiCopy.recordTopicChips)
              FilterChip(
                label: Text(topic),
                selected: selectedPrompt == topic,
                onSelected: (_) => onSelectPrompt(topic),
                selectedColor: AppColors.accentLight,
                checkmarkColor: AppColors.accentPrimary,
                side: const BorderSide(color: AppColors.borderSubtle),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: VoiceMemoryTypography.metadataStyle(),
            ),
            onPressed: () => showRecordHelpPromptSheet(
              context: context,
              onSelect: onSelectPrompt,
              selected: selectedPrompt,
            ),
            child: Text(ConsumerUiCopy.showMorePromptIdeas),
          ),
        ),
      ],
    );
  }
}

class _StarterCard extends StatelessWidget {
  const _StarterCard({
    required this.prompt,
    required this.selected,
    required this.onTap,
  });

  final String prompt;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: prompt,
      child: Material(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    selected ? AppColors.accentPrimary : AppColors.borderSubtle,
                width: selected ? 1.5 : 1,
              ),
              color: selected
                  ? AppColors.accentLight
                  : AppColors.backgroundSecondary,
            ),
            child: Text(
              prompt,
              style: VoiceMemoryTypography.bodyStyle(),
            ),
          ),
        ),
      ),
    );
  }
}
