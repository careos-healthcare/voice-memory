import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../design/archive_mobile_typography.dart';
import '../features/action_items/action_item_filter.dart';
import '../features/action_items/action_item_store.dart';
import '../features/action_items/action_items_export.dart';
import '../features/action_items/archive_action_item.dart';
import '../features/archive_packs/archive_pack.dart';
import '../features/archive_packs/archive_pack_store.dart';
import '../features/archive_search/archive_search_filters.dart';
import '../features/memory/archive_thread.dart';
import '../features/memory/archive_thread_store.dart';
import '../models/journal_entry.dart';
import '../services/activation_funnel_analytics.dart';
import '../services/app_services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/action_items/action_item_card.dart';
import '../widgets/retention/tiny_record_again_cta.dart';
import '../widgets/pushed_screen_shell.dart';

/// Action items the user chose to remember — not auto-created tasks.
class ActionItemsScreen extends StatefulWidget {
  const ActionItemsScreen({super.key, this.store});

  final ActionItemStore? store;

  @override
  State<ActionItemsScreen> createState() => _ActionItemsScreenState();
}

class _ActionItemsScreenState extends State<ActionItemsScreen> {
  late final ActionItemStore _store =
      widget.store ?? ActionItemStore.instance();
  var _loading = true;
  var _trackedOpen = false;
  var _search = '';
  List<ArchiveActionItem> _items = const [];
  List<JournalEntry> _entries = const [];
  List<ArchivePack> _packs = const [];
  List<ArchiveThread> _threads = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _store.loadAll();
    var entries = const <JournalEntry>[];
    var packs = const <ArchivePack>[];
    var threads = const <ArchiveThread>[];
    try {
      entries = await AppServices.instance.journalStore.loadAll();
      packs = await ArchivePackStore.instance().loadAll();
      threads = await ArchiveThreadStore.instance().loadAll();
    } catch (_) {
      // Metadata loads are optional — action items still render without them.
    }
    if (!mounted) return;
    setState(() {
      _items = items;
      _entries = entries;
      _packs = packs;
      _threads = threads;
      _loading = false;
    });
    if (!_trackedOpen) {
      _trackedOpen = true;
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.actionItemsOpened,
        source: 'settings',
        actionItemCountBucket: ActivationFunnelAnalytics.resultCountBucket(
          items.where((i) => !i.isDismissed).length,
        ),
        oncePerSession: true,
      );
    }
  }

  JournalEntry? _entryFor(String entryId) {
    for (final entry in _entries) {
      if (entry.id == entryId) return entry;
    }
    return null;
  }

  String? _packLabel(String? packId) {
    if (packId == null) return null;
    for (final pack in _packs) {
      if (pack.id == packId) return pack.name;
    }
    return null;
  }

  String? _threadLabel(String? threadId) {
    if (threadId == null) return null;
    for (final thread in _threads) {
      if (thread.id == threadId) return thread.name;
    }
    return null;
  }

  List<ArchiveActionItem> get _visibleItems =>
      ActionItemFilter.search(_items, _search);

  Future<void> _export() async {
    final exportable = ActionItemFilter.exportableItems(_items);
    if (exportable.isEmpty) return;
    final bucket = ActivationFunnelAnalytics.resultCountBucket(
      exportable.length,
    );
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.actionItemExportStarted,
      source: 'action_items',
      actionItemCountBucket: bucket,
    );
    final markdown = const ActionItemsExport().buildMarkdown(items: exportable);
    final fileName = ActionItemsExport.fileName(DateTime.now());
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(markdown);
    await Share.shareXFiles([
      XFile(file.path),
    ], subject: 'ArchiveMe action items');
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.actionItemExportCompleted,
      source: 'action_items',
      actionItemCountBucket: bucket,
    );
  }

  void _openSource(ArchiveActionItem item) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.actionItemSourceOpened,
      source: 'action_items',
      status: item.status,
    );
    context.push('/entry/${item.sourceEntryId}');
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleItems;
    return PushedScreenShell(
      title: ActionItemsCopy.screenTitle,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                TextField(
                  key: const Key('action_items_search_field'),
                  decoration: InputDecoration(
                    hintText: ArchiveSearchCopy.searchPlaceholder,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (text) => setState(() => _search = text),
                ),
                const SizedBox(height: AppSpacing.xs),
                TinyRecordAgainCta(
                  entryCount: _entries.where((e) => !e.isArchived).length,
                  source: 'action_items',
                  onRecord: () => context.go('/record'),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (visible.isEmpty)
                  Text(
                    '${ActionItemsCopy.emptyTitle}. ${ActionItemsCopy.emptyHelper}',
                    key: const Key('action_items_empty'),
                    style: ArchiveMobileTypography.responsiveHelper(
                      context,
                    ).copyWith(color: AppColors.textSecondary),
                  )
                else ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: const Key('action_items_export_button'),
                      onPressed: _export,
                      child: const Text(ActionItemsCopy.exportActionItems),
                    ),
                  ),
                  for (final item in visible) ...[
                    ActionItemCard(
                      item: item,
                      store: _store,
                      sourceEntry: _entryFor(item.sourceEntryId),
                      packLabel: _packLabel(item.archivePackId),
                      threadLabel: _threadLabel(item.archiveThreadId),
                      onChanged: _load,
                      onOpenSource: () => _openSource(item),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                ],
              ],
            ),
    );
  }
}
