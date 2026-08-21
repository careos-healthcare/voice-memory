import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/next_action/next_best_action_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Small subordinate next-step line for Record and Patterns.
class NextBestActionLine extends StatelessWidget {
  const NextBestActionLine({
    required this.action, required this.surface, super.key,
  });

  final NextBestActionResult action;
  final NextBestActionSurface surface;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: Key('next_best_action_line_${surface.name}_${action.kind.name}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          action.titleLine,
          key: Key('next_best_action_title_${action.kind.name}'),
          style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          action.helperLine,
          key: Key('next_best_action_helper_${action.kind.name}'),
          style: ArchiveMobileTypography.explanationBody(context).copyWith(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}