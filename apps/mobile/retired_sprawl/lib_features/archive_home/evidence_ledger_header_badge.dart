import 'dart:async';

import 'package:archiveme_mobile/features/archive_home/evidence_ledger_bottom_sheet.dart';
import 'package:archiveme_mobile/features/archive_home/evidence_ledger_copy.dart';
import 'package:archiveme_mobile/features/archive_home/evidence_ledger_count_controller.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Compact header badge showing live citable-fact counts from SQLite.
class EvidenceLedgerHeaderBadge extends StatefulWidget {
  const EvidenceLedgerHeaderBadge({
    super.key,
    this.journalStore,
    this.entries,
    this.compact = false,
  });

  final JournalStore? journalStore;
  final List<JournalEntry>? entries;
  final bool compact;

  @override
  State<EvidenceLedgerHeaderBadge> createState() =>
      _EvidenceLedgerHeaderBadgeState();
}

class _EvidenceLedgerHeaderBadgeState extends State<EvidenceLedgerHeaderBadge> {
  @override
  void initState() {
    super.initState();
    unawaited(EvidenceLedgerCountController.instance.refresh());
  }

  Future<void> _openInspectSheet() async {
    await showEvidenceLedgerBottomSheet(
      context,
      journalStore: widget.journalStore,
      entries: widget.entries,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: EvidenceLedgerCountController.instance,
      builder: (context, _) {
        final counts = EvidenceLedgerCountController.instance.counts;
        final label = EvidenceLedgerCopy.badgeLabel(
          citableFactCount: counts.citableFactCount,
          entryCount: counts.entryCount,
        );
        final semantics = EvidenceLedgerCopy.badgeSemantics(
          citableFactCount: counts.citableFactCount,
          entryCount: counts.entryCount,
        );

        return Semantics(
          button: true,
          label: semantics,
          child: Material(
            color: AppColors.transparent,
            child: InkWell(
              key: const Key('evidence_ledger_header_badge'),
              onTap: _openInspectSheet,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.compact ? 10 : 12,
                  vertical: widget.compact ? 6 : 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accentPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.accentPrimary.withValues(alpha: 0.28),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: widget.compact ? 14 : 16,
                      color: AppColors.accentPrimary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.accentPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: widget.compact ? 11 : 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}