import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/archive_mobile_typography.dart';
import '../features/bulk_actions/archive_selection_controller.dart';
import '../features/bulk_actions/bulk_archive_action.dart';
import '../features/collections/archive_collection.dart';
import '../features/collections/archive_collection_store.dart';
import '../features/timeline/timeline_entry_display.dart';
import '../models/journal_entry.dart';
import '../services/activation_funnel_analytics.dart';
import '../services/app_services.dart';
import '../storage/journal_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/bulk_actions/archive_selection_bar.dart';
import '../widgets/bulk_actions/bulk_actions_flow.dart';
import '../widgets/pushed_screen_shell.dart';

/// One collection: its entries, rename, and delete. Deleting the
/// collection deletes the group only — every entry stays in the archive.
class CollectionDetailScreen extends StatefulWidget {
  const CollectionDetailScreen({
    super.key,
    required this.collectionId,
    this.store,
    this.journalStore,
  });

  final String collectionId;

  /// Injectable for tests; default to the app stores.
  final ArchiveCollectionStore? store;
  final JournalStore? journalStore;

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  late final ArchiveCollectionStore _store =
      widget.store ?? ArchiveCollectionStore.instance();
  late final JournalStore _journal =
      widget.journalStore ?? AppServices.instance.journalStore;

  var _loading = true;
  ArchiveCollection? _collection;
  List<JournalEntry> _entries = const [];
  final _selection = ArchiveSelectionController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  void _startSelectMode() {
    _selection.start();
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.archiveSelectModeStarted,
      source: 'collection_detail',
    );
    setState(() {});
  }

  Future<void> _runBulkActions() async {
    await runBulkActionsFlow(
      context,
      controller: _selection,
      source: 'collection_detail',
      allEntries: _entries,
    );
    if (mounted) await _load();
  }

  Future<void> _load() async {
    final collection = await _store.getById(widget.collectionId);
    final all = await _journal.loadAll();
    if (!mounted) return;
    setState(() {
      _collection = collection;
      _entries = collection == null
          ? const []
          : all.where((e) => collection.contains(e.id)).toList();
      _loading = false;
    });
  }

  Future<void> _removeEntry(String entryId) async {
    await _store.removeEntry(widget.collectionId, entryId);
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.collectionEntryRemoved,
      source: 'collection_detail',
    );
    await _load();
  }

  Future<void> _rename() async {
    final collection = _collection;
    if (collection == null) return;
    final controller = TextEditingController(text: collection.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(ArchiveCollectionsCopy.renameCollection),
        content: TextField(
          key: const Key('rename_collection_field'),
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: ArchiveCollectionsCopy.nameLabel,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('rename_collection_confirm'),
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text(ArchiveCollectionsCopy.renameCollection),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null) return;
    await _store.rename(widget.collectionId, name);
    await _load();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(ArchiveCollectionsCopy.deleteConfirmTitle),
        content: const Text(ArchiveCollectionsCopy.deleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('delete_collection_confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(ArchiveCollectionsCopy.deleteCollection),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _store.delete(widget.collectionId);
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.collectionDeleted,
      entryCount: _collection?.entryIds.length,
    );
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final collection = _collection;
    return PushedScreenShell(
      title: collection?.name ?? ArchiveCollectionsCopy.screenTitle,
      actions: [
        PopupMenuButton<String>(
          key: const Key('collection_detail_menu'),
          onSelected: (value) {
            if (value == 'rename') _rename();
            if (value == 'delete') _delete();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              key: Key('collection_menu_rename'),
              value: 'rename',
              child: Text(ArchiveCollectionsCopy.renameCollection),
            ),
            PopupMenuItem(
              key: Key('collection_menu_delete'),
              value: 'delete',
              child: Text(ArchiveCollectionsCopy.deleteCollection),
            ),
          ],
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : collection == null
          ? Center(
              child: Text(
                ArchiveCollectionsCopy.emptyTitle,
                style: ArchiveMobileTypography.responsiveHelper(context),
              ),
            )
          : _entries.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  ArchiveCollectionsCopy.emptyHelper,
                  textAlign: TextAlign.center,
                  style: ArchiveMobileTypography.responsiveHelper(
                    context,
                  ).copyWith(color: AppColors.textSecondary),
                ),
              ),
            )
          : ListenableBuilder(
              listenable: _selection,
              builder: (context, _) => ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  if (_selection.selecting)
                    ArchiveSelectionBar(
                      controller: _selection,
                      allIds: [for (final e in _entries) e.id],
                      onActions: _runBulkActions,
                    )
                  else
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        key: const Key('collection_select_button'),
                        onPressed: _startSelectMode,
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text(BulkActionsCopy.select),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xs),
                  for (final entry in _entries) ...[
                    _entryTile(context, entry),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _entryTile(BuildContext context, JournalEntry entry) {
    final tile = ListTile(
      key: Key('collection_entry_${entry.id}'),
      contentPadding: EdgeInsets.zero,
      title: Text(
        timelineEntryTitle(entry),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: ArchiveMobileTypography.listTitle(context),
      ),
      trailing: IconButton(
        key: Key('collection_remove_${entry.id}'),
        icon: const Icon(Icons.remove_circle_outline),
        tooltip: ArchiveCollectionsCopy.removeFromCollection,
        onPressed: () => _removeEntry(entry.id),
      ),
      onTap: _selection.selecting
          ? () => _selection.toggle(entry.id)
          : () => context.push('/entry/${entry.id}'),
    );
    if (!_selection.selecting) return tile;
    return Row(
      children: [
        Checkbox(
          key: Key('select_collection_entry_${entry.id}'),
          value: _selection.isSelected(entry.id),
          onChanged: (_) => _selection.toggle(entry.id),
        ),
        Expanded(child: tile),
      ],
    );
  }
}
