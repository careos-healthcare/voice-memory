import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:voicememory_mobile/design/archive_mobile_typography.dart';
import 'package:voicememory_mobile/features/archive_packs/archive_pack.dart';
import 'package:voicememory_mobile/features/archive_packs/archive_pack_store.dart';
import 'package:voicememory_mobile/features/archive_packs/pack_archive_export.dart';
import 'package:voicememory_mobile/features/fact_ledger/fact_ledger_filter.dart';
import 'package:voicememory_mobile/features/fact_ledger/fact_ledger_store.dart';
import 'package:voicememory_mobile/features/fact_ledger/archive_fact.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_store.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/security/user_content_safety.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/theme/app_spacing.dart';
import 'package:voicememory_mobile/widgets/archive_packs/pack_instructions_editor.dart';
import 'package:voicememory_mobile/widgets/fact_ledger/fact_card.dart';
import 'package:voicememory_mobile/widgets/pushed_screen_shell.dart';

class ArchivePackDetailScreen extends StatefulWidget {
  const ArchivePackDetailScreen({
    super.key,
    required this.packId,
    this.store,
    this.journalStore,
  });

  final String packId;
  final ArchivePackStore? store;
  final JournalStore? journalStore;

  @override
  State<ArchivePackDetailScreen> createState() =>
      _ArchivePackDetailScreenState();
}

class _ArchivePackDetailScreenState extends State<ArchivePackDetailScreen> {
  late final ArchivePackStore _store =
      widget.store ?? ArchivePackStore.instance();
  late final JournalStore _journal =
      widget.journalStore ?? AppServices.instance.journalStore;

  var _loading = true;
  ArchivePack? _pack;
  List<JournalEntry> _entries = const [];
  List<PressureCheckInRecord> _records = const [];
  List<ArchiveFact> _facts = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pack = await _store.getById(widget.packId);
    final all = await _journal.loadAll();
    List<PressureCheckInRecord> records = const [];
    if (AppServices.isInitialized) {
      records = await PressureCheckInStore.instance().loadAll();
    }
    final facts = await FactLedgerStore.instance().loadAll();
    if (!mounted) return;
    setState(() {
      _pack = pack;
      _entries = pack == null
          ? const []
          : all.where((e) => pack.contains(e.id)).toList();
      _records = records;
      _facts = FactLedgerFilter.forPack(widget.packId, facts);
      _loading = false;
    });
  }

  Future<void> _exportPack({
    Future<void> Function(String contents, String fileName)? onShare,
  }) async {
    final pack = _pack;
    if (pack == null) return;
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.archivePackExportStarted,
      entryCount: _entries.length,
      source: 'pack_detail',
    );
    final markdown = const PackArchiveExport().buildMarkdown(
      pack: pack,
      packEntries: _entries,
      records: _records,
      facts: _facts,
    );
    final fileName = PackArchiveExport.fileName(DateTime.now());
    final share = onShare ?? _defaultShare;
    await share(markdown, fileName);
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.archivePackExportCompleted,
      entryCount: _entries.length,
      source: 'pack_detail',
    );
  }

  static Future<void> _defaultShare(String contents, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(contents);
    await Share.shareXFiles([
      XFile(file.path),
    ], subject: 'ArchiveMe pack export');
  }

  JournalEntry? _entryFor(String entryId) {
    for (final entry in _entries) {
      if (entry.id == entryId) return entry;
    }
    return null;
  }

  Future<void> _rename() async {
    final pack = _pack;
    if (pack == null) return;
    final controller = TextEditingController(text: pack.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ArchivePacksCopy.renamePack),
        content: TextField(
          key: const Key('rename_pack_field'),
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: ArchivePacksCopy.packName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('rename_pack_confirm'),
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(ArchivePacksCopy.renamePack),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null) return;
    await _store.rename(widget.packId, name);
    await _load();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ArchivePacksCopy.deletePack),
        content: Text(ArchivePacksCopy.deletePackConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('delete_pack_confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(ArchivePacksCopy.deletePack),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _store.delete(widget.packId);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final pack = _pack;
    final pinned = _entries.where((e) => e.isPinned).toList();

    return PushedScreenShell(
      title: pack?.name ?? ArchivePacksCopy.screenTitle,
      actions: [
        PopupMenuButton<String>(
          key: const Key('archive_pack_detail_menu'),
          onSelected: (value) {
            if (value == 'rename') _rename();
            if (value == 'delete') _delete();
            if (value == 'export') _exportPack();
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'export',
              child: Text(ArchivePacksCopy.exportPack),
            ),
            PopupMenuItem(
              value: 'rename',
              child: Text(ArchivePacksCopy.renamePack),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text(ArchivePacksCopy.deletePack),
            ),
          ],
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : pack == null
          ? Center(child: Text(ArchivePacksCopy.emptyTitle))
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                PackInstructionsEditor(
                  packId: pack.id,
                  store: _store,
                  initialInstructions: pack.instructions,
                  onSaved: _load,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  ArchivePacksCopy.pinnedInPack,
                  style: ArchiveMobileTypography.cardLabel(context),
                ),
                if (pinned.isEmpty)
                  Text(
                    'No pinned entries in this pack.',
                    style: ArchiveMobileTypography.responsiveHelper(context),
                  )
                else
                  for (final entry in pinned)
                    ListTile(
                      key: Key('pack_pinned_${entry.id}'),
                      title: Text(
                        UserContentSafety.safeSnippet(
                          entry.transcript,
                          maxChars: 60,
                        ),
                      ),
                    ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        FactLedgerCopy.screenTitle,
                        style: ArchiveMobileTypography.cardLabel(context),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/details'),
                      child: const Text('View all'),
                    ),
                  ],
                ),
                if (_facts.isEmpty)
                  Text(
                    FactLedgerCopy.emptyHelper,
                    style: ArchiveMobileTypography.responsiveHelper(context),
                  )
                else
                  for (final fact in _facts) ...[
                    FactCard(
                      fact: fact,
                      store: FactLedgerStore.instance(),
                      sourceEntry: _entryFor(fact.sourceEntryId),
                      packLabel: pack.name,
                      onChanged: _load,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                const SizedBox(height: AppSpacing.lg),
                Text(
                  ArchivePacksCopy.entriesInPack,
                  style: ArchiveMobileTypography.cardLabel(context),
                ),
                if (_entries.isEmpty)
                  Text(ArchivePacksCopy.emptyHelper)
                else
                  for (final entry in _entries)
                    ListTile(
                      key: Key('pack_entry_${entry.id}'),
                      title: Text(
                        UserContentSafety.safeSnippet(
                          entry.transcript,
                          maxChars: 80,
                        ),
                      ),
                    ),
              ],
            ),
    );
  }
}
