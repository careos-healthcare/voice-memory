import 'dart:async';

import 'package:archiveme_mobile/features/archive_home/evidence_ledger_copy.dart';
import 'package:archiveme_mobile/features/archive_home/evidence_ledger_inspect_builder.dart';
import 'package:archiveme_mobile/features/archive_home/evidence_ledger_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:archiveme_mobile/widgets/archive_v1/pattern_match_confidence_badge.dart';
import 'package:flutter/material.dart';

Future<void> showEvidenceLedgerBottomSheet(
  BuildContext context, {
  JournalStore? journalStore,
  List<JournalEntry>? entries,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.transparent,
    isScrollControlled: true,
    builder: (_) => EvidenceLedgerBottomSheet(
      journalStore: journalStore,
      entries: entries,
    ),
  );
}

class EvidenceLedgerBottomSheet extends StatefulWidget {
  const EvidenceLedgerBottomSheet({
    super.key,
    this.journalStore,
    this.entries,
  });

  final JournalStore? journalStore;
  final List<JournalEntry>? entries;

  @override
  State<EvidenceLedgerBottomSheet> createState() =>
      _EvidenceLedgerBottomSheetState();
}

class _EvidenceLedgerBottomSheetState extends State<EvidenceLedgerBottomSheet> {
  static const Color _surface = Color(0xFFFFFBF5);

  final TextEditingController _searchController = TextEditingController();
  List<EvidenceLedgerInspectItem> _items = const [];
  bool _loading = true;
  String _query = '';
  EvidenceLedgerDateFilter _dateFilter = EvidenceLedgerDateFilter.all;

  @override
  void initState() {
    super.initState();
    unawaited(_loadItems());
    _searchController.addListener(() {
      setState(() => _query = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() => _loading = true);
    try {
      final entries = widget.entries ??
          await (widget.journalStore ?? AppServices.instance.journalStore)
              .loadAll();
      final items = await EvidenceLedgerInspectBuilder.buildFromEntries(
        entries,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_, stackTrace) {
      if (!mounted) return;
      setState(() {
        _items = const [];
        _loading = false;
      });
    }
  }

  List<EvidenceLedgerInspectItem> get _visibleItems =>
      EvidenceLedgerInspectFilter.apply(
        items: _items,
        query: _query,
        dateFilter: _dateFilter,
      );

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final visibleItems = _visibleItems;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg + bottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              EvidenceLedgerCopy.sheetTitle,
              style: VoiceMemoryTypography.cardTitleStyle().copyWith(fontSize: 18),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              EvidenceLedgerCopy.sheetSubtitle,
              style: VoiceMemoryTypography.bodyStyle(
                color: AppColors.textSecondary,
              ).copyWith(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('evidence_ledger_search_field'),
              controller: _searchController,
              decoration: InputDecoration(
                hintText: EvidenceLedgerCopy.searchHint,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final filter in EvidenceLedgerDateFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: FilterChip(
                        key: Key('evidence_ledger_date_filter_${filter.name}'),
                        label: Text(_dateFilterLabel(filter)),
                        selected: _dateFilter == filter,
                        onSelected: (_) => setState(() => _dateFilter = filter),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_items.isEmpty)
              _EmptyState()
            else if (visibleItems.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  EvidenceLedgerCopy.noMatches,
                  style: VoiceMemoryTypography.bodyStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: visibleItems.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final item = visibleItems[index];
                    return _InspectRow(item: item);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _dateFilterLabel(EvidenceLedgerDateFilter filter) {
    return switch (filter) {
      EvidenceLedgerDateFilter.all => EvidenceLedgerCopy.filterAll,
      EvidenceLedgerDateFilter.last7Days => EvidenceLedgerCopy.filter7Days,
      EvidenceLedgerDateFilter.last30Days => EvidenceLedgerCopy.filter30Days,
      EvidenceLedgerDateFilter.last90Days => EvidenceLedgerCopy.filter90Days,
    };
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text(
            EvidenceLedgerCopy.emptyTitle,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(fontSize: 16),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            EvidenceLedgerCopy.emptyBody,
            textAlign: TextAlign.center,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _InspectRow extends StatelessWidget {
  const _InspectRow({required this.item});

  final EvidenceLedgerInspectItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('evidence_ledger_row_${item.id}'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary,
        borderRadius: BorderRadius.circular(16),
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
                  item.kindLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              PatternMatchConfidenceBadge(band: item.confidenceBand, compact: true),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            item.title,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (item.subtitle.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}