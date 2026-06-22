import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/archive_mobile_typography.dart';
import '../../design/archive_responsive_layout.dart';
import '../../features/archive_proof/visible_archive_proof_copy.dart';
import '../../models/journal_entry.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Patterns tab — exactly one saved entry. Confirms the archive started and
/// nudges a second entry without zero-entry upload copy.
class PatternsFirstArchiveView extends StatelessWidget {
  const PatternsFirstArchiveView({
    super.key,
    this.fillViewport = false,
    this.savedEntryId,
    this.entries = const [],
  });

  final bool fillViewport;

  /// When set, shows a secondary action to open the saved entry detail.
  final String? savedEntryId;

  /// Retained for callers that pass journal entries; the one-entry preview
  /// card is self-contained and does not duplicate the belief proof layer.
  final List<JournalEntry> entries;

  @override
  Widget build(BuildContext context) {
    final gap = ArchiveResponsiveLayout.gap(context);
    final entryId = savedEntryId?.trim();

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const Key('patterns_one_entry_archive_preview_card'),
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F9F4),
            borderRadius: BorderRadius.circular(VoiceMemoryCards.radius),
            border: Border.all(
              color: AppColors.accentPrimary.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: VoiceMemoryCards.standard().boxShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                VisibleArchiveProofCopy.patternsEmptyPreviewBadge,
                style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              SizedBox(height: gap),
              Text(
                VisibleArchiveProofCopy.patternsOneEntryTitle,
                style: ArchiveMobileTypography.responsivePageTitle(context),
              ),
              SizedBox(height: gap),
              Text(
                VisibleArchiveProofCopy.patternsOneEntryBody,
                style: ArchiveMobileTypography.explanationBody(context),
              ),
              SizedBox(height: gap),
              _PreviewRow(
                label: 'Current belief',
                value: VisibleArchiveProofCopy.patternsOneEntryBeliefRow,
              ),
              SizedBox(height: gap),
              _PreviewRow(
                label: 'Evidence',
                value: VisibleArchiveProofCopy.patternsOneEntryEvidenceRow,
              ),
              SizedBox(height: gap),
              _PreviewRow(
                label: 'What changes next',
                value: VisibleArchiveProofCopy.patternsOneEntryChangedRow,
              ),
              SizedBox(height: gap + 4),
              FilledButton(
                key: const Key('patterns_first_archive_record_another'),
                onPressed: () => context.go('/record'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  VisibleArchiveProofCopy.patternsOneEntryCta,
                  style: ArchiveMobileTypography.responsiveCta(context),
                ),
              ),
              if (entryId != null && entryId.isNotEmpty) ...[
                const SizedBox(height: 8),
                TextButton(
                  key: const Key('patterns_first_archive_view_saved_entry'),
                  onPressed: () => context.push('/entry/$entryId'),
                  child: const Text('View saved entry'),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    final padded = ArchiveResponsiveLayout.page(
      context: context,
      maxWidth: ArchiveResponsiveLayout.cardMaxWidth,
      child: content,
    );

    return SingleChildScrollView(
      physics: fillViewport
          ? const AlwaysScrollableScrollPhysics()
          : const ClampingScrollPhysics(),
      child: padded,
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: ArchiveMobileTypography.cardLabel(context),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: ArchiveMobileTypography.body(context),
        ),
      ],
    );
  }
}
