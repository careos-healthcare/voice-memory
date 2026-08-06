import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../record/quick_text_capture_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Collapsible example starters — hidden until the user taps “Examples”.
class FocusedTypeEntryExamplesPanel extends StatelessWidget {
  const FocusedTypeEntryExamplesPanel({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.onStarterSelected,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<String> onStarterSelected;

  @override
  Widget build(BuildContext context) {
    final linkStyle = ArchiveMobileTypography.responsiveHelper(context)
        .copyWith(
          color: AppColors.textSecondary,
          decoration: TextDecoration.underline,
          fontSize: 13,
        );
    final starterStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textPrimary, fontSize: 14, height: 1.4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.center,
          child: TextButton(
            key: const Key('focused_type_entry_examples_toggle'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: AppColors.textSecondary,
            ),
            onPressed: onToggle,
            child: Text(QuickTextCaptureCopy.examplesLabel, style: linkStyle),
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: AppSpacing.xs),
          for (var i = 0; i < QuickTextCaptureCopy.examples.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Align(
                alignment: Alignment.center,
                child: InkWell(
                  key: Key('focused_type_entry_example_$i'),
                  onTap: () =>
                      onStarterSelected(QuickTextCaptureCopy.examples[i]),
                  child: Text(
                    QuickTextCaptureCopy.examples[i],
                    style: starterStyle,
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
