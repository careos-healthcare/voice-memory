import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/action_items/action_item_store.dart';
import 'package:archiveme_mobile/features/action_items/archive_action_item.dart';
import 'package:archiveme_mobile/features/archive_search/archive_search_filters.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/action_items/action_item_editor_sheet.dart';
import 'package:archiveme_mobile/widgets/action_items/action_item_status_chip.dart';
import 'package:flutter/material.dart';

/// One action item in the list — title, optional note preview, metadata,
/// and mark done / edit / dismiss actions.
class ActionItemCard extends StatelessWidget {
  const ActionItemCard({
    required this.item, required this.store, super.key,
    this.sourceEntry,
    this.packLabel,
    this.threadLabel,
    this.onChanged,
    this.onOpenSource,
  });

  final ArchiveActionItem item;
  final ActionItemStore store;
  final JournalEntry? sourceEntry;
  final String? packLabel;
  final String? threadLabel;
  final VoidCallback? onChanged;
  final VoidCallback? onOpenSource;

  ArchiveDateFilter get _timeBucket {
    final created = sourceEntry?.createdAt ?? item.createdAt;
    return ArchiveDateFilter.bucketFor(created, DateTime.now());
  }

  Future<void> _edit(BuildContext context) async {
    final saved = await showActionItemEditorSheet(
      context,
      store: store,
      existing: item,
      source: 'action_items',
    );
    if (saved) onChanged?.call();
  }

  Future<void> _markDone(BuildContext context) async {
    await store.markDone(item.id);
    onChanged?.call();
  }

  Future<void> _dismiss(BuildContext context) async {
    await store.dismiss(item.id);
    onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('action_item_card_${item.id}'),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: ArchiveMobileTypography.listTitle(context),
                ),
              ),
              ActionItemStatusChip(status: item.status),
            ],
          ),
          if (item.note.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              item.note.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ArchiveMobileTypography.listSubtitle(context),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _metaChip(context, _timeBucket.label),
              if (threadLabel != null) _metaChip(context, threadLabel!),
              if (packLabel != null) _metaChip(context, packLabel!),
              if (item.dueAt != null)
                _metaChip(context, ActionItemsCopy.dueDateLabel),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (item.isOpen)
                TextButton(
                  key: Key('action_item_mark_done_${item.id}'),
                  onPressed: () => _markDone(context),
                  child: const Text(ActionItemsCopy.markDone),
                ),
              TextButton(
                key: Key('action_item_edit_${item.id}'),
                onPressed: () => _edit(context),
                child: const Text(ActionItemsCopy.edit),
              ),
              TextButton(
                key: Key('action_item_dismiss_${item.id}'),
                onPressed: () => _dismiss(context),
                child: const Text(ActionItemsCopy.dismiss),
              ),
              if (onOpenSource != null)
                TextButton(
                  key: Key('action_item_open_source_${item.id}'),
                  onPressed: onOpenSource,
                  child: const Text('Open entry'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaChip(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(
        label,
        style: ArchiveMobileTypography.responsiveHelper(
          context,
        ).copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}