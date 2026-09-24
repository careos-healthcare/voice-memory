import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/design/archive_responsive_layout.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Archive-home entry that opens pattern exploration conversation.
class PatternExplorationEntryCard extends StatelessWidget {
  const PatternExplorationEntryCard({super.key});

  static const Key cardKey = Key('pattern_exploration_entry_card');
  static const String title = 'Talk through your patterns';
  static const String subtitle = 'Ask about a pattern';

  @override
  Widget build(BuildContext context) {
    if (!V1CapabilityRegistry.patternExploration) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.only(bottom: ArchiveResponsiveLayout.gap(context)),
      child: Semantics(
        button: true,
        label: title,
        child: Material(
          color: AppColors.warmSurface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            key: cardKey,
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.push(RouteCatalog.explorePatterns),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.warmBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm + 2,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline,
                      color: AppColors.textSecondary,
                      size: 22,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
