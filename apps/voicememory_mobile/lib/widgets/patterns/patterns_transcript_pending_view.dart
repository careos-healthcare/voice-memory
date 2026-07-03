import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/archive_mobile_typography.dart';
import '../../design/archive_responsive_layout.dart';
import '../../features/archive_evidence/transcript_pending_copy.dart';
import '../../features/trust/pending_transcript_recovery_gate.dart';
import '../../models/journal_entry.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import '../record/pending_transcript_recovery_prompt.dart';
import '../record/pending_transcript_recovery_sheet.dart';

/// Patterns tab — saved moments exist but none have comparable transcript yet.
class PatternsTranscriptPendingView extends StatelessWidget {
  const PatternsTranscriptPendingView({
    super.key,
    this.fillViewport = false,
    this.savedEntryId,
    this.recoverableEntry,
    this.entryCount = 1,
  });

  final bool fillViewport;
  final String? savedEntryId;
  final JournalEntry? recoverableEntry;
  final int entryCount;

  Future<void> _openRecovery(BuildContext context) async {
    final entry = recoverableEntry;
    if (entry == null) return;
    await PendingTranscriptRecovery.open(
      context,
      entry: entry,
      source: 'patterns_pending_transcript',
      entryCount: entryCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    final gap = ArchiveResponsiveLayout.gap(context);
    final entryId = savedEntryId?.trim();
    final showRecovery = recoverableEntry != null &&
        PendingTranscriptRecoveryGate.entryNeedsRecovery(recoverableEntry!);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const Key('patterns_transcript_pending_card'),
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: VoiceMemoryCards.standard(
            background: AppColors.backgroundSecondary,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showRecovery)
                PendingTranscriptRecoveryPrompt(
                  onAddWhatYouSaid: () => _openRecovery(context),
                )
              else ...[
                Text(
                  TranscriptPendingCopy.patternsSavedTitle,
                  style: ArchiveMobileTypography.responsivePageTitle(context),
                ),
                SizedBox(height: gap),
                Text(
                  TranscriptPendingCopy.patternsSavedBody,
                  style: ArchiveMobileTypography.explanationBody(context),
                ),
              ],
              SizedBox(height: gap + 4),
              FilledButton(
                key: const Key('patterns_transcript_pending_record'),
                onPressed: () => context.go('/record'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  'Record another moment',
                  style: ArchiveMobileTypography.responsiveCta(context),
                ),
              ),
              if (entryId != null && entryId.isNotEmpty) ...[
                const SizedBox(height: 8),
                TextButton(
                  key: const Key('patterns_transcript_pending_view_entry'),
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
