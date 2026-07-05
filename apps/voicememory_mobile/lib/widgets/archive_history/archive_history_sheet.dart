import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/archive_controls/archive_control_copy.dart';
import '../../features/archive_history/archive_history_copy.dart';
import '../../features/archive_history/archive_history_engine.dart';
import '../../features/archive_history/archive_history_filter.dart';
import '../../features/archive_history/archive_history_item.dart';
import '../../features/transcript_correction/transcript_correction_copy.dart';
import '../../features/transcript_correction/transcript_correction_gate.dart';
import '../../features/trust/pending_transcript_recovery_copy.dart';
import '../../services/app_services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../archive_controls/archive_moment_actions_sheet.dart';
import '../record/correct_transcript_sheet.dart';
import '../record/entry_importance_button.dart';
import '../record/pending_transcript_recovery_sheet.dart';

/// Bottom sheet listing saved moments with trust/status chips.
class ArchiveHistorySheet extends StatefulWidget {
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
  State<ArchiveHistorySheet> createState() => _ArchiveHistorySheetState();
}

class _ArchiveHistorySheetState extends State<ArchiveHistorySheet> {
  ArchiveHistoryFilter _activeFilter = ArchiveHistoryFilterEngine.defaultFilter;
  late ArchiveHistoryContent _content = widget.content;
  late int _entryCount = widget.entryCount;

  List<ArchiveHistoryItem> get _filteredItems => ArchiveHistoryFilterEngine.apply(
        items: _content.items,
        filter: _activeFilter,
      );

  Future<void> _reloadContent() async {
    if (!AppServices.isInitialized) return;
    final entries = await AppServices.instance.journal.loadAll();
    if (!mounted) return;
    setState(() {
      _content = ArchiveHistoryEngine.build(entries: entries);
      _entryCount = entries.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _filteredItems;

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
              if (!_content.isEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                _ArchiveHistoryFilterChips(
                  activeFilter: _activeFilter,
                  onFilterSelected: (filter) {
                    setState(() => _activeFilter = filter);
                  },
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              if (_content.isEmpty) ...[
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
              ] else if (filteredItems.isEmpty) ...[
                Text(
                  ArchiveHistoryCopy.filteredEmptyTitle,
                  key: const Key('archive_history_filtered_empty_title'),
                  style: ArchiveMobileTypography.cardLabel(context),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  ArchiveHistoryCopy.filteredEmptyBody,
                  key: const Key('archive_history_filtered_empty_body'),
                  style: ArchiveMobileTypography.explanationBody(context)
                      .copyWith(color: AppColors.textSecondary),
                ),
              ] else ...[
                for (final item in filteredItems) ...[
                  _ArchiveHistoryRow(
                    item: item,
                    entryCount: _entryCount,
                    onMomentDeleted: _reloadContent,
                  ),
                  if (item != filteredItems.last)
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

class _ArchiveHistoryFilterChips extends StatelessWidget {
  const _ArchiveHistoryFilterChips({
    required this.activeFilter,
    required this.onFilterSelected,
  });

  final ArchiveHistoryFilter activeFilter;
  final ValueChanged<ArchiveHistoryFilter> onFilterSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const Key('archive_history_filter_chips'),
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final filter in ArchiveHistoryFilterEngine.orderedFilters)
          FilterChip(
            key: Key(
              'archive_history_filter_chip_${ArchiveHistoryFilterEngine.filterKey(filter)}',
            ),
            label: Text(ArchiveHistoryFilterEngine.label(filter)),
            selected: activeFilter == filter,
            showCheckmark: false,
            onSelected: (_) => onFilterSelected(filter),
          ),
      ],
    );
  }
}

class _ArchiveHistoryRow extends StatefulWidget {
  const _ArchiveHistoryRow({
    required this.item,
    required this.entryCount,
    required this.onMomentDeleted,
  });

  final ArchiveHistoryItem item;
  final int entryCount;
  final Future<void> Function() onMomentDeleted;

  @override
  State<_ArchiveHistoryRow> createState() => _ArchiveHistoryRowState();
}

class _ArchiveHistoryRowState extends State<_ArchiveHistoryRow> {
  ArchiveHistoryItem get item => widget.item;
  int get entryCount => widget.entryCount;

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

  Future<void> _openCorrection(BuildContext context) async {
    final entry = await AppServices.instance.journalStore.getById(item.entryId);
    if (entry == null || !context.mounted) return;
    final updated = await TranscriptCorrection.open(
      context,
      entry: entry,
      source: 'archive_history_sheet',
      entryCount: entryCount,
    );
    if (updated == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(TranscriptCorrectionCopy.savedSuccess),
      ),
    );
    await widget.onMomentDeleted();
  }

  Future<void> _deleteMoment(BuildContext context) async {
    final result = await ArchiveMomentDeleteActions.deleteMoment(
      context: context,
      entryId: item.entryId,
      source: 'archive_history_sheet',
    );
    if (result?.deleted == true) {
      await widget.onMomentDeleted();
    }
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
        if (item.helpedNote != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            item.helpedNote!,
            key: Key('archive_history_helped_${item.entryId}'),
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
        if (item.showCorrectTranscriptCta) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: Key('archive_history_correct_transcript_${item.entryId}'),
              onPressed: () => unawaited(_openCorrection(context)),
              child: const Text(TranscriptCorrectionCopy.actionLabel),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: Key('archive_history_delete_moment_${item.entryId}'),
            onPressed: () => unawaited(_deleteMoment(context)),
            child: const Text(ArchiveControlCopy.deleteMomentButton),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        EntryImportanceButton(
          entryId: item.entryId,
          source: 'archive_history_sheet',
          entryCount: entryCount,
          compact: true,
          onChanged: () => setState(() {}),
        ),
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
