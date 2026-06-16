import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/bulk_actions/archive_selection_controller.dart';
import '../../features/bulk_actions/bulk_archive_action.dart';
import '../../features/bulk_actions/bulk_archive_action_service.dart';
import '../../features/collections/archive_collection.dart';
import '../../features/collections/archive_collection_store.dart';
import '../../features/memory/memory_scope.dart';
import '../../features/memory/memory_scope_policy.dart';
import '../../features/pressure_retention/pressure_check_in_record.dart';
import '../../models/journal_entry.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../theme/app_spacing.dart';
import '../collections/create_collection_sheet.dart';
import '../export/export_selected_sheet.dart';
import 'bulk_action_sheet.dart';
import 'bulk_delete_confirmation_sheet.dart';

/// One bulk-actions pass for the current selection: pick an action,
/// confirm destructive ones, run it, clear the selection.
///
/// Analytics carries fixed action ids, coarse selection buckets, the
/// surface source id, and the memory scope id — never entry text,
/// exported text, or collection names. Nothing here reads or writes
/// Memory Scope Controls; the scope id is reported, not changed.
Future<bool> runBulkActionsFlow(
  BuildContext context, {
  required ArchiveSelectionController controller,
  required String source,
  required List<JournalEntry> allEntries,
  List<PressureCheckInRecord> records = const [],
  BulkArchiveActionService? service,
  ArchiveCollectionStore? collectionStore,
  Future<void> Function(String contents, String fileName)? onShare,
}) async {
  final selectedIds = controller.selectedIds;
  if (selectedIds.isEmpty) return false;
  final bucket = ActivationFunnelAnalytics.resultCountBucket(
    selectedIds.length,
  );
  final scopeId = MemoryScopePolicy.scope.id;

  final action = await showBulkActionSheet(context);
  if (action == null) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.archiveBulkActionCancelled,
      source: source,
      selectionCountBucket: bucket,
    );
    return false;
  }

  ActivationFunnelAnalytics.track(
    ActivationFunnelAnalytics.archiveBulkActionStarted,
    actionType: action.id,
    source: source,
    selectionCountBucket: bucket,
    memoryScope: scopeId,
  );

  final actions = service ?? BulkArchiveActionService.instance();
  final selectedEntries = allEntries
      .where((e) => selectedIds.contains(e.id))
      .toList();
  var completed = false;

  switch (action) {
    case BulkArchiveAction.exportSelected:
      if (!context.mounted) return false;
      var exported = false;
      await showExportSelectedSheet(
        context,
        selectedEntries: selectedEntries,
        records: records,
        source: source,
        onShare: onShare,
        onExported: () => exported = true,
      );
      completed = exported;
    case BulkArchiveAction.addToCollection:
      if (!context.mounted) return false;
      final store = collectionStore ?? ArchiveCollectionStore.instance();
      final collection = await _pickCollection(context, store);
      if (collection != null) {
        await actions.addEntriesToCollection(collection.id, selectedIds);
        completed = true;
      }
    case BulkArchiveAction.pinSelected:
      await actions.pinEntries(selectedIds);
      completed = true;
    case BulkArchiveAction.unpinSelected:
      await actions.unpinEntries(selectedIds);
      completed = true;
    case BulkArchiveAction.archiveSelected:
      if (!context.mounted) return false;
      if (await showBulkArchiveConfirmation(context)) {
        await actions.archiveEntries(selectedIds);
        ActivationFunnelAnalytics.track(
          ActivationFunnelAnalytics.archiveBulkArchiveCompleted,
          source: source,
          selectionCountBucket: bucket,
        );
        completed = true;
      }
    case BulkArchiveAction.deleteSelected:
      if (!context.mounted) return false;
      if (await showBulkDeleteConfirmation(context)) {
        ActivationFunnelAnalytics.track(
          ActivationFunnelAnalytics.archiveBulkDeleteConfirmed,
          source: source,
          selectionCountBucket: bucket,
        );
        await actions.deleteEntries(selectedIds);
        completed = true;
      }
    case BulkArchiveAction.treatAsNew:
      await actions.treatEntriesAsNew(selectedIds);
      completed = true;
    case BulkArchiveAction.keepExactDetails:
      await actions.keepExactDetailsForEntries(selectedIds);
      completed = true;
  }

  if (completed) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.archiveBulkActionCompleted,
      actionType: action.id,
      source: source,
      selectionCountBucket: bucket,
      memoryScope: scopeId,
    );
    controller.cancel();
  } else {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.archiveBulkActionCancelled,
      actionType: action.id,
      source: source,
      selectionCountBucket: bucket,
    );
  }
  return completed;
}

/// Collection picker for bulk add. Names are shown in the UI only.
Future<ArchiveCollection?> _pickCollection(
  BuildContext context,
  ArchiveCollectionStore store,
) async {
  final collections = await store.loadAll();
  if (!context.mounted) return null;
  return showModalBottomSheet<ArchiveCollection?>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.md,
        ),
        children: [
          Text(
            ArchiveCollectionsCopy.addToCollection,
            style: ArchiveMobileTypography.responsiveSectionTitle(sheetContext),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final collection in collections)
            ListTile(
              key: Key('bulk_collection_${collection.id}'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                collection.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ArchiveMobileTypography.listTitle(sheetContext),
              ),
              onTap: () => Navigator.of(sheetContext).pop(collection),
            ),
          ListTile(
            key: const Key('bulk_collection_new'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.add, size: 20),
            title: Text(
              ArchiveCollectionsCopy.newCollection,
              style: ArchiveMobileTypography.listTitle(sheetContext),
            ),
            onTap: () async {
              final created = await showCreateCollectionSheet(
                sheetContext,
                store: store,
                source: 'bulk_action',
              );
              if (sheetContext.mounted) {
                Navigator.of(sheetContext).pop(created);
              }
            },
          ),
        ],
      ),
    ),
  );
}
