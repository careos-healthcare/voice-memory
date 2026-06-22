import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../design/user_facing_date.dart';
import '../../features/activation/capture_context_tags.dart';
import '../../features/archive_proof/visible_archive_proof_copy.dart';
import '../../features/timeline/timeline_entry_display.dart';
import '../../models/journal_entry.dart';
import '../../storage/journal_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import '../../widgets/archive/edit_context_tag_sheet.dart';

/// One eligible entry row in an evidence map context drilldown.
class ArchiveEvidenceContextList extends StatelessWidget {
  const ArchiveEvidenceContextList({
    super.key,
    required this.entries,
    required this.journalStore,
    required this.onEntriesChanged,
    required this.onOpenEntry,
  });

  final List<JournalEntry> entries;
  final JournalStore journalStore;
  final VoidCallback onEntriesChanged;
  final ValueChanged<JournalEntry> onOpenEntry;

  Future<void> _editContext(BuildContext context, JournalEntry entry) async {
    final result = await showEditContextTagSheet(
      context,
      initialTagId: entry.captureContextTag,
    );
    if (result == null || result.action == EditContextTagAction.cancel) {
      return;
    }

    final nextTagId = switch (result.action) {
      EditContextTagAction.cancel => entry.captureContextTag,
      EditContextTagAction.clear => null,
      EditContextTagAction.save => result.tagId,
    };
    await journalStore.updateCaptureContextTag(entry.id, tagId: nextTagId);
    onEntriesChanged();
  }

  String _contextLabel(JournalEntry entry) {
    final label = CaptureContextTags.labelForEntry(entry);
    if (label == null) {
      return VisibleArchiveProofCopy.entryContextTagNone;
    }
    return VisibleArchiveProofCopy.entryContextTagPresent(label);
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = ArchiveMobileTypography.cardLabel(context);
    final bodyStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textPrimary,
      height: 1.45,
    );
    final metaStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textSecondary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in entries) ...[
          Container(
            key: Key('archive_evidence_context_item_${entry.id}'),
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: VoiceMemoryCards.standard(
              background: AppColors.backgroundSecondary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  formatUserFacingDate(entry.createdAt),
                  key: Key('archive_evidence_context_date_${entry.id}'),
                  style: metaStyle,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  timelineEntryTitle(entry),
                  key: Key('archive_evidence_context_title_${entry.id}'),
                  style: titleStyle,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  postSaveRecordedSummary(entry),
                  key: Key('archive_evidence_context_preview_${entry.id}'),
                  style: bodyStyle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _contextLabel(entry),
                  key: Key('archive_evidence_context_tag_${entry.id}'),
                  style: metaStyle,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    OutlinedButton(
                      key: Key('archive_evidence_context_edit_${entry.id}'),
                      onPressed: () => _editContext(context, entry),
                      child: Text(VisibleArchiveProofCopy.entryContextTagEdit),
                    ),
                    FilledButton(
                      key: Key('archive_evidence_context_open_${entry.id}'),
                      onPressed: () => onOpenEntry(entry),
                      child: Text(
                        VisibleArchiveProofCopy.archiveEvidenceContextOpenEntry,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}
