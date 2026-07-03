import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/archive_history/archive_history_copy.dart';
import '../../features/archive_history/archive_history_item.dart';
import '../../features/trust/pending_transcript_recovery_copy.dart';
import '../../services/app_services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../record/pending_transcript_recovery_sheet.dart';

/// Bottom sheet listing saved moments with trust/status chips.
class ArchiveHistorySheet extends StatelessWidget {
  const ArchiveHistorySheet({
    super.key,
    required this.content,
    required this.entryCount,
  });

  final ArchiveHistoryContent content;
  final int entryCount;

  static Future<void> show(
    BuildContext context, {
    required ArchiveHistoryContent content,
    required int entryCount,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => ArchiveHistorySheet(
        content: content,
        entryCount: entryCount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: SingleChildScrollView(
          child: Column(
            key: const Key('archive_history_sheet'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                ArchiveHistoryCopy.sheetTitle,
                key: const Key('archive_history_sheet_title'),
                style: ArchiveMobileTypography.responsiveSectionTitle(context),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                ArchiveHistoryCopy.sheetSubtitle,
                key: const Key('archive_history_sheet_subtitle'),
                style:
                    ArchiveMobileTypography.responsiveHelper(context).copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (content.isEmpty) ...[
                Text(
                  ArchiveHistoryCopy.emptyTitle,
                  key: const Key('archive_history_empty_title'),
                  style: ArchiveMobileTypography.cardLabel(context),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  ArchiveHistoryCopy.emptyBody,
                  key: const Key('archive_history_empty_body'),
                  style: ArchiveMobileTypography.explanationBody(context)
                      .copyWith(color: AppColors.textSecondary),
                ),
              ] else ...[
                for (final item in content.items) ...[
                  _ArchiveHistoryRow(
                    item: item,
                    entryCount: entryCount,
                  ),
                  if (item != content.items.last)
                    const SizedBox(height: AppSpacing.md),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ArchiveHistoryRow extends StatelessWidget {
  const _ArchiveHistoryRow({
    required this.item,
    required this.entryCount,
  });

  final ArchiveHistoryItem item;
  final int entryCount;

  String get _statusKey => switch (item.status) {
        ArchiveHistoryStatus.usedAsEvidence => 'used_as_evidence',
        ArchiveHistoryStatus.savedOnly => 'saved_only',
        ArchiveHistoryStatus.transcriptPending => 'transcript_pending',
        ArchiveHistoryStatus.needsYourWords => 'needs_your_words',
        ArchiveHistoryStatus.ignoredForPatterns => 'ignored_for_patterns',
      };

  String get _chipLabel => switch (item.status) {
        ArchiveHistoryStatus.usedAsEvidence =>
          ArchiveHistoryCopy.chipUsedAsEvidence,
        ArchiveHistoryStatus.savedOnly => ArchiveHistoryCopy.chipSavedOnly,
        ArchiveHistoryStatus.transcriptPending =>
          ArchiveHistoryCopy.chipTranscriptPending,
        ArchiveHistoryStatus.needsYourWords =>
          ArchiveHistoryCopy.chipNeedsYourWords,
        ArchiveHistoryStatus.ignoredForPatterns =>
          ArchiveHistoryCopy.chipIgnoredForPatterns,
      };

  Future<void> _openRecovery(BuildContext context) async {
    final entry = await AppServices.instance.journalStore.getById(item.entryId);
    if (entry == null || !context.mounted) return;
    final result = await PendingTranscriptRecovery.open(
      context,
      entry: entry,
      source: 'archive_history_sheet',
      entryCount: entryCount,
    );
    if (result == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(PendingTranscriptRecoveryCopy.savedSuccess),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: Key('archive_history_row_${item.entryId}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                item.dateTimeLabel,
                key: Key('archive_history_date_${item.entryId}'),
                style: ArchiveMobileTypography.cardLabel(context).copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            _StatusChip(
              label: _chipLabel,
              statusKey: _statusKey,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          item.previewText,
          key: Key('archive_history_preview_${item.entryId}'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: ArchiveMobileTypography.explanationBody(context).copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        if (item.evidenceNote != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            item.evidenceNote!,
            key: Key('archive_history_note_${item.entryId}'),
            style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
        if (item.showAddWordsCta) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: Key('archive_history_add_words_${item.entryId}'),
              onPressed: () => unawaited(_openRecovery(context)),
              child: const Text(ArchiveHistoryCopy.addWordsCta),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.statusKey,
  });

  final String label;
  final String statusKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('archive_history_chip_$statusKey'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
