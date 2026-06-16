import 'package:flutter/material.dart';

import '../../product/consumer_ui_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// Light-theme bottom sheet with more reflection prompt ideas.
///
/// The sheet is height-constrained and the prompt list scrolls, so content
/// never overflows on small devices. Tapping a prompt closes the sheet and
/// reports the choice through [onSelect] so it feeds the same selected-prompt
/// state as the prompt cards on the Record screen.
Future<void> showRecordHelpPromptSheet({
  required BuildContext context,
  required ValueChanged<String> onSelect,
  String? selected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.backgroundSecondary,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) =>
        _RecordHelpPromptSheet(selected: selected, onSelect: onSelect),
  );
}

class _RecordHelpPromptSheet extends StatelessWidget {
  const _RecordHelpPromptSheet({required this.onSelect, this.selected});

  final ValueChanged<String> onSelect;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                ConsumerUiCopy.recordHelpSheetTitle,
                style: VoiceMemoryTypography.sectionTitleStyle(),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                ConsumerUiCopy.recordHelpSheetHelper,
                style: VoiceMemoryTypography.bodyStyle(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final prompt
                          in ConsumerUiCopy.recordHelpSheetPrompts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _SheetPromptCard(
                            prompt: prompt,
                            selected: selected == prompt,
                            onTap: () {
                              Navigator.of(context).pop();
                              onSelect(prompt);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetPromptCard extends StatelessWidget {
  const _SheetPromptCard({
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
        color: selected ? AppColors.accentLight : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? AppColors.accentPrimary
                    : AppColors.borderSubtle,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Text(prompt, style: VoiceMemoryTypography.bodyStyle()),
          ),
        ),
      ),
    );
  }
}
