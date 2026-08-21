import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/activation/archive_workspace_quick_actions.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Compact next-step actions for the Archive/Patterns workspace.
class ArchiveWorkspaceQuickActionsCard extends StatelessWidget {
  const ArchiveWorkspaceQuickActionsCard({
    required this.quickActions, required this.onActionTap, super.key,
  });

  final ArchiveWorkspaceQuickActions quickActions;
  final ValueChanged<ArchiveWorkspaceQuickAction> onActionTap;

  @override
  Widget build(BuildContext context) {
    if (!quickActions.showCard) return const SizedBox.shrink();

    final titleStyle = ArchiveMobileTypography.responsiveSectionTitle(context);

    return Container(
      key: const Key('archive_workspace_quick_actions_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: AppColors.backgroundSecondary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            quickActions.title,
            key: const Key('archive_workspace_quick_actions_title'),
            style: titleStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final action in quickActions.actions)
                OutlinedButton(
                  key: Key(
                    'archive_workspace_quick_action_${action.kind.name}',
                  ),
                  onPressed: () => onActionTap(action),
                  child: Text(action.label),
                ),
            ],
          ),
        ],
      ),
    );
  }
}