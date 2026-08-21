import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/archive_search/archive_search_filters.dart';
import 'package:archiveme_mobile/features/fact_ledger/archive_fact.dart';
import 'package:archiveme_mobile/features/fact_ledger/fact_ledger_store.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/fact_ledger/fact_editor_sheet.dart';
import 'package:archiveme_mobile/widgets/fact_ledger/fact_type_chip.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

/// One saved detail in the Details list.
class FactCard extends StatelessWidget {
  const FactCard({
    required this.fact, required this.store, super.key,
    this.sourceEntry,
    this.packLabel,
    this.threadLabel,
    this.onChanged,
  });

  final ArchiveFact fact;
  final FactLedgerStore store;
  final JournalEntry? sourceEntry;
  final String? packLabel;
  final String? threadLabel;
  final VoidCallback? onChanged;

  ArchiveDateFilter get _timeBucket {
    final created = sourceEntry?.createdAt ?? fact.createdAt;
    return ArchiveDateFilter.bucketFor(created, DateTime.now());
  }

  Future<void> _edit(BuildContext context) async {
    final saved = await showFactEditorSheet(
      context,
      store: store,
      existing: fact,
      source: 'details',
    );
    if (saved) onChanged?.call();
  }

  Future<void> _pin(BuildContext context) async {
    await store.togglePin(fact.id);
    onChanged?.call();
  }

  Future<void> _delete(BuildContext context) async {
    await store.delete(fact.id);
    onChanged?.call();
  }

  void _openSource(BuildContext context) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.factSourceOpened,
      source: 'details',
      factType: fact.factType,
    );
    unawaited(context.push('/entry/${fact.sourceEntryId}'));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('fact_card_${fact.id}'),
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
                  fact.label,
                  style: ArchiveMobileTypography.listTitle(context),
                ),
              ),
              if (fact.isPinned)
                const Icon(
                  Icons.push_pin_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            fact.value.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          if (fact.note.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              fact.note.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ArchiveMobileTypography.responsiveHelper(
                context,
              ).copyWith(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              FactTypeChip(factType: fact.factType),
              _metaChip(context, _timeBucket.label),
              if (threadLabel != null) _metaChip(context, threadLabel!),
              if (packLabel != null) _metaChip(context, packLabel!),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton(
                key: Key('fact_edit_${fact.id}'),
                onPressed: () => _edit(context),
                child: const Text(FactLedgerCopy.edit),
              ),
              TextButton(
                key: Key('fact_open_source_${fact.id}'),
                onPressed: () => _openSource(context),
                child: const Text(FactLedgerCopy.openEntry),
              ),
              TextButton(
                key: Key('fact_pin_${fact.id}'),
                onPressed: () => _pin(context),
                child: Text(
                  fact.isPinned ? FactLedgerCopy.unpin : FactLedgerCopy.pin,
                ),
              ),
              TextButton(
                key: Key('fact_delete_${fact.id}'),
                onPressed: () => _delete(context),
                child: const Text(FactLedgerCopy.delete),
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