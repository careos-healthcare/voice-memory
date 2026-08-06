import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:voicememory_mobile/design/archive_mobile_typography.dart';
import 'package:voicememory_mobile/features/bulk_actions/archive_selection_controller.dart';
import 'package:voicememory_mobile/features/bulk_actions/bulk_archive_action.dart';
import 'package:voicememory_mobile/features/collections/archive_collection.dart';
import 'package:voicememory_mobile/features/collections/archive_collection_store.dart';
import 'package:voicememory_mobile/features/pins/pinned_evidence_store.dart';
import 'package:voicememory_mobile/features/timeline/timeline_entry_display.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/theme/app_colors.dart';
import 'package:voicememory_mobile/theme/app_spacing.dart';
import 'package:voicememory_mobile/widgets/bulk_actions/archive_selection_bar.dart';
import 'package:voicememory_mobile/widgets/bulk_actions/bulk_actions_flow.dart';
import 'package:voicememory_mobile/widgets/collections/add_to_collection_sheet.dart';
import 'package:voicememory_mobile/features/action_items/action_item_store.dart';
import 'package:voicememory_mobile/widgets/action_items/remember_this_button.dart';
import 'package:voicememory_mobile/widgets/pins/pin_entry_button.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/widgets/retention/tiny_record_again_cta.dart';
import 'package:voicememory_mobile/widgets/pushed_screen_shell.dart';

/// Pinned evidence — saved entries, easy to find again. Read-only over
/// the journal store except for the unpin toggle (safe metadata only).
class PinnedEvidenceScreen extends StatefulWidget {
  const PinnedEvidenceScreen({super.key, this.store});

  /// Injectable for tests; defaults to the app journal store.
  final PinnedEvidenceStore? store;

  @override
  State<PinnedEvidenceScreen> createState() => _PinnedEvidenceScreenState();
}

class _PinnedEvidenceScreenState extends State<PinnedEvidenceScreen> {
  late final PinnedEvidenceStore _store =
      widget.store ?? PinnedEvidenceStore.instance();
  var _loading = true;
  List<JournalEntry> _pinned = const [];
  var _activeEntryCount = 0;
  final _selection = ArchiveSelectionController();

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  void _startSelectMode() {
    _selection.start();
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.archiveSelectModeStarted,
      source: 'pinned_evidence',
    );
    setState(() {});
  }

  Future<void> _runBulkActions() async {
    await runBulkActionsFlow(
      context,
      controller: _selection,
      source: 'pinned_evidence',
      allEntries: _pinned,
    );
    if (mounted) await _load();
  }

  @override
  void initState() {
    super.initState();
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.pinnedEvidenceOpened,
      oncePerSession: true,
    );
    _load();
  }

  Future<void> _load() async {
    final pinned = await _store.pinnedEntries();
    var activeEntryCount = pinned.where((e) => !e.isArchived).length;
    if (widget.store == null && AppServices.isInitialized) {
      final entries = await AppServices.instance.journalStore.loadAll();
      activeEntryCount = entries.where((e) => !e.isArchived).length;
    }
    if (!mounted) return;
    setState(() {
      _pinned = pinned;
      _activeEntryCount = activeEntryCount;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: PinnedEvidenceCopy.screenTitle,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _pinned.isEmpty
          ? _empty(context)
          : ListenableBuilder(
              listenable: _selection,
              builder: (context, _) => ListView(
                key: const Key('pinned_evidence_list'),
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  if (_selection.selecting)
                    ArchiveSelectionBar(
                      controller: _selection,
                      allIds: [for (final e in _pinned) e.id],
                      onActions: _runBulkActions,
                    )
                  else
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        key: const Key('pinned_select_button'),
                        onPressed: _startSelectMode,
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text(BulkActionsCopy.select),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xs),
                  TinyRecordAgainCta(
                    entryCount: _activeEntryCount,
                    source: 'pinned_evidence',
                    onRecord: () => context.go('/record'),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  for (final entry in _pinned) ...[
                    _pinnedTile(context, entry),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _pinnedTile(BuildContext context, JournalEntry entry) {
    final tile = ListTile(
      key: Key('pinned_entry_${entry.id}'),
      contentPadding: EdgeInsets.zero,
      title: Text(
        timelineEntryTitle(entry),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: ArchiveMobileTypography.listTitle(context),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: Key('pinned_add_to_collection_${entry.id}'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.bookmark_add_outlined, size: 20),
            tooltip: ArchiveCollectionsCopy.addToCollection,
            onPressed: () => showAddToCollectionSheet(
              context,
              store: ArchiveCollectionStore.instance(),
              entryId: entry.id,
              source: 'pinned_screen',
            ),
          ),
          PinEntryButton(
            entryId: entry.id,
            isPinned: true,
            store: _store,
            source: 'pinned_screen',
            onChanged: (_) => _load(),
          ),
          RememberThisButton(
            entry: entry,
            store: ActionItemStore.instance(),
            source: 'pinned_screen',
            compact: true,
          ),
        ],
      ),
      onTap: _selection.selecting
          ? () => _selection.toggle(entry.id)
          : () => context.push('/entry/${entry.id}'),
    );
    if (!_selection.selecting) return tile;
    return Row(
      children: [
        Checkbox(
          key: Key('select_pinned_${entry.id}'),
          value: _selection.isSelected(entry.id),
          onChanged: (_) => _selection.toggle(entry.id),
        ),
        Expanded(child: tile),
      ],
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          key: const Key('pinned_evidence_empty'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              PinnedEvidenceCopy.emptyTitle,
              style: ArchiveMobileTypography.responsiveSectionTitle(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              PinnedEvidenceCopy.emptyHelper,
              style: ArchiveMobileTypography.responsiveHelper(
                context,
              ).copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
