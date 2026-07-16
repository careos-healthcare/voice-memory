import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/archive_mobile_typography.dart';
import '../../design/archive_responsive_layout.dart';
import '../../features/archive_proof/visible_archive_proof_copy.dart';
import '../../models/journal_entry.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import '../../theme/voicememory_colors.dart';

/// Patterns tab — exactly one saved entry. One calm card: archive started,
/// needs another moment, optional view of the saved entry.
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

  /// Retained for callers that pass journal entries; the one-entry card is
  /// self-contained and does not duplicate the belief proof layer.
  final List<JournalEntry> entries;

  @override
  Widget build(BuildContext context) {
    final entryId = savedEntryId?.trim();

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const Key('patterns_one_entry_archive_preview_card'),
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: VoiceMemoryCards.standard(
            background: const Color(0xFFF0F7F2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                VisibleArchiveProofCopy.patternsOneEntryTitle,
                key: const Key('patterns_one_entry_title'),
                style: ArchiveMobileTypography.responsiveSectionTitle(context)
                    .copyWith(color: VoiceMemoryColors.captureSuccess),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                VisibleArchiveProofCopy.patternsOneEntryBody,
                key: const Key('patterns_one_entry_body'),
                style: ArchiveMobileTypography.body(
                  context,
                ).copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                VisibleArchiveProofCopy.patternsOneEntryReassurance,
                key: const Key('patterns_one_entry_reassurance'),
                style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton(
                key: const Key('patterns_first_archive_record_another'),
                onPressed: () => context.go('/record'),
                child: Text(
                  VisibleArchiveProofCopy.patternsOneEntryCta,
                  style: ArchiveMobileTypography.responsiveCta(context),
                ),
              ),
              if (entryId != null && entryId.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                OutlinedButton(
                  key: const Key('patterns_first_archive_view_saved_entry'),
                  onPressed: () => context.push('/entry/$entryId'),
                  child: const Text(ConsumerUiCopy.patternsFirstEntryViewSavedCta),
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
