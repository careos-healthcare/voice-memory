import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/bulk_actions/archive_selection_controller.dart';
import '../../features/bulk_actions/bulk_archive_action.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Select-mode bar: selected count, select all, clear, cancel, and the
/// bulk actions entry point.
class ArchiveSelectionBar extends StatelessWidget {
  const ArchiveSelectionBar({
    super.key,
    required this.controller,
    required this.allIds,
    required this.onActions,
  });

  final ArchiveSelectionController controller;

  /// Ids "Select all" selects — the surface's currently visible entries.
  final List<String> allIds;

  /// Opens the bulk action sheet for the current selection.
  final VoidCallback onActions;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Container(
          key: const Key('archive_selection_bar'),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  BulkActionsCopy.selectedCount(controller.count),
                  key: const Key('selection_count_label'),
                  style: ArchiveMobileTypography.cardLabel(context),
                ),
              ),
              TextButton(
                key: const Key('selection_select_all'),
                style: _compact,
                onPressed: () => controller.selectAll(allIds),
                child: const Text(BulkActionsCopy.selectAll),
              ),
              TextButton(
                key: const Key('selection_clear'),
                style: _compact,
                onPressed: controller.count == 0 ? null : controller.clear,
                child: const Text(BulkActionsCopy.clearSelection),
              ),
              IconButton(
                key: const Key('selection_actions'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.more_horiz, size: 20),
                onPressed: controller.count == 0 ? null : onActions,
              ),
              TextButton(
                key: const Key('selection_cancel'),
                style: _compact,
                onPressed: controller.cancel,
                child: const Text(BulkActionsCopy.cancel),
              ),
            ],
          ),
        );
      },
    );
  }

  static final ButtonStyle _compact = TextButton.styleFrom(
    minimumSize: const Size(0, 32),
    padding: const EdgeInsets.symmetric(horizontal: 6),
  );
}
