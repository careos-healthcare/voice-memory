import 'package:archiveme_mobile/core/config/beta_surfaces_feature_flags.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Prominent archive-home entry that opens guided Ask My Archive search.
class AskArchiveEntryBar extends StatelessWidget {
  const AskArchiveEntryBar({super.key});

  @override
  Widget build(BuildContext context) {
    if (!BetaSurfacesFeatureFlags.askArchive) {
      return const SizedBox.shrink();
    }
    return Semantics(
      button: true,
      label: 'Ask My Archive',
      child: Material(
        color: const Color(0xFFFFFBF5),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: const Key('ask_archive_entry_bar'),
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push(RouteCatalog.askArchive),
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
                  const Icon(Icons.search, color: AppColors.textSecondary, size: 22),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Ask My Archive',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  Text(
                    'Search moments',
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
    );
  }
}