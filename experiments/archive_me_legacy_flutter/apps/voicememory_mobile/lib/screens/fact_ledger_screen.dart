import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../design/archive_mobile_typography.dart';
import '../features/archive_packs/archive_pack.dart';
import '../features/archive_packs/archive_pack_store.dart';
import '../features/archive_search/archive_search_filters.dart';
import '../features/fact_ledger/archive_fact.dart';
import '../features/fact_ledger/fact_ledger_export.dart';
import '../features/fact_ledger/fact_ledger_filter.dart';
import '../features/fact_ledger/fact_ledger_store.dart';
import '../features/memory/archive_thread.dart';
import '../features/memory/archive_thread_store.dart';
import '../models/journal_entry.dart';
import '../services/activation_funnel_analytics.dart';
import '../services/app_services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/fact_ledger/fact_card.dart';
import '../widgets/pushed_screen_shell.dart';
import '../widgets/retention/tiny_record_again_cta.dart';

/// Saved details the user chose to keep — not auto-extracted facts.
class FactLedgerScreen extends StatefulWidget {
  const FactLedgerScreen({
    super.key,
    this.store,
    this.packId,
    this.initialFacts,
  });

  final FactLedgerStore? store;

  /// When set, shows only facts linked to this pack.
  final String? packId;
  final List<ArchiveFact>? initialFacts;

  @override
  State<FactLedgerScreen> createState() => _FactLedgerScreenState();
}

class _FactLedgerScreenState extends State<FactLedgerScreen> {
  late final FactLedgerStore _store =
      widget.store ?? FactLedgerStore.instance();
  var _loading = true;
  var _trackedOpen = false;
  var _search = '';
  String? _typeFilter;
  List<ArchiveFact> _facts = const [];
  List<JournalEntry> _entries = const [];
  List<ArchivePack> _packs = const [];
  List<ArchiveThread> _threads = const [];

  @override
  void initState() {
    super.initState();
    final initialFacts = widget.initialFacts;
    if (initialFacts == null) {
      _load();
    } else {
      _facts = initialFacts;
      _loading = false;
    }
  }

  Future<void> _load() async {
    final facts = await _store.loadAll();
    var entries = const <JournalEntry>[];
    var packs = const <ArchivePack>[];
    var threads = const <ArchiveThread>[];
    try {
      entries = await AppServices.instance.journalStore.loadAll();
      packs = await ArchivePackStore.instance().loadAll();
      threads = await ArchiveThreadStore.instance().loadAll();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _facts = facts;
      _entries = entries;
      _packs = packs;
      _threads = threads;
      _loading = false;
    });
    if (!_trackedOpen) {
      _trackedOpen = true;
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.detailsOpened,
        source: widget.packId == null ? 'settings' : 'pack_detail',
        factCountBucket: ActivationFunnelAnalytics.resultCountBucket(
          facts.length,
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

  List<ArchiveFact> get _visibleFacts => FactLedgerFilter.search(
    _facts,
    _search,
    factTypeId: _typeFilter,
    packId: widget.packId,
  );

  Future<void> _export() async {
    final exportable = FactLedgerFilter.exportableFacts(
      _facts,
      packId: widget.packId,
    );
    if (exportable.isEmpty) return;
    final bucket = ActivationFunnelAnalytics.resultCountBucket(
      exportable.length,
    );
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.factExportStarted,
      source: 'details',
      factCountBucket: bucket,
    );
    final markdown = const FactLedgerExport().buildMarkdown(facts: exportable);
    final fileName = FactLedgerExport.fileName(DateTime.now());
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(markdown);
    await Share.shareXFiles([XFile(file.path)], subject: 'ArchiveMe details');
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.factExportCompleted,
      source: 'details',
      factCountBucket: bucket,
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleFacts;
    return PushedScreenShell(
      title: FactLedgerCopy.screenTitle,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                TextField(
                  key: const Key('fact_ledger_search_field'),
                  decoration: InputDecoration(
                    hintText: ArchiveSearchCopy.searchPlaceholder,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (text) => setState(() => _search = text),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final type in FactType.values)
                      FilterChip(
                        key: Key('fact_filter_type_${type.id}'),
                        label: Text(type.label),
                        selected: _typeFilter == type.id,
                        onSelected: (_) => setState(
                          () => _typeFilter = _typeFilter == type.id
                              ? null
                              : type.id,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                TinyRecordAgainCta(
                  entryCount: _entries.where((e) => !e.isArchived).length,
                  source: 'details',
                  onRecord: () => context.go('/record'),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (visible.isEmpty)
                  Text(
                    '${FactLedgerCopy.emptyTitle}. ${FactLedgerCopy.emptyHelper}',
                    key: const Key('fact_ledger_empty'),
                    style: ArchiveMobileTypography.responsiveHelper(
                      context,
                    ).copyWith(color: AppColors.textSecondary),
                  )
                else ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: const Key('fact_ledger_export_button'),
                      onPressed: _export,
                      child: const Text(FactLedgerCopy.exportDetails),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final fact in visible) ...[
                    FactCard(
                      fact: fact,
                      store: _store,
                      sourceEntry: _entryFor(fact.sourceEntryId),
                      packLabel: _packLabel(fact.archivePackId),
                      threadLabel: _threadLabel(fact.archiveThreadId),
                      onChanged: _load,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ],
            ),
    );
  }
}
