import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/archive_proof/visible_archive_proof_copy.dart';
import '../../features/post_save/post_save_focused_actions_copy.dart';
import '../../features/post_save/post_save_recorded_summary_copy.dart';
import '../../features/post_save/post_save_repeat_copy.dart';
import '../../features/record/daily_mirror_model.dart';
import '../../features/timeline/timeline_entry_display.dart';
import '../../features/transcript_correction/transcript_correction_copy.dart';
import '../../features/transcript_correction/transcript_correction_gate.dart';
import '../../models/journal_entry.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import '../../theme/voicememory_colors.dart';
import '../record/entry_importance_button.dart';

/// Repeat-detected post-save — one calm proof card with collapsed transcript.
class RepeatPostSaveCard extends StatefulWidget {
  const RepeatPostSaveCard({
    super.key,
    required this.entry,
    required this.allEntries,
    required this.mirror,
    required this.onViewEvidence,
    required this.onAddOneMoreMoment,
    required this.onDoneForToday,
    this.onCorrectTranscript,
    this.onViewThoughtMap,
  });

  final JournalEntry entry;
  final List<JournalEntry> allEntries;
  final DailyMirrorResult mirror;
  final VoidCallback onViewEvidence;
  final VoidCallback onAddOneMoreMoment;
  final VoidCallback onDoneForToday;
  final VoidCallback? onCorrectTranscript;
  final VoidCallback? onViewThoughtMap;

  @override
  State<RepeatPostSaveCard> createState() => _RepeatPostSaveCardState();
}

class _RepeatPostSaveCardState extends State<RepeatPostSaveCard> {
  bool _heardExpanded = false;

  String get _repeatPhrase {
    final display = PostSaveRepeatCopy.resolve(widget.mirror);
    if (display.phrase.trim().isNotEmpty) {
      return display.phrase.trim();
    }
    if (display.body.trim().isNotEmpty) {
      return display.body.trim();
    }
    return widget.mirror.heroBody.trim();
  }

  @override
  Widget build(BuildContext context) {
    final phrase = _repeatPhrase;
    final heardSummary = postSaveRecordedSummary(widget.entry);
    final bodyStyle = ArchiveMobileTypography.body(
      context,
    ).copyWith(color: AppColors.textPrimary, height: 1.45);
    final labelStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600);
    final quoteStyle = bodyStyle.copyWith(fontStyle: FontStyle.italic);

    return Container(
      key: const Key('repeat_post_save_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF0F7F2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle_outline,
                color: VoiceMemoryColors.captureSuccess,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  VisibleArchiveProofCopy.repeatPostSaveTitle,
                  key: const Key('repeat_post_save_title'),
                  style: ArchiveMobileTypography.responsiveSectionTitle(
                    context,
                  ).copyWith(color: VoiceMemoryColors.captureSuccess),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            VisibleArchiveProofCopy.repeatPostSaveRepeatLabel,
            key: const Key('repeat_post_save_repeat_label'),
            style: labelStyle,
          ),
          if (phrase.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '"$phrase"',
              key: const Key('repeat_post_save_phrase'),
              style: quoteStyle,
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            VisibleArchiveProofCopy.repeatPostSaveBody,
            key: const Key('repeat_post_save_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          InkWell(
            key: const Key('repeat_post_save_heard_toggle'),
            onTap: () => setState(() => _heardExpanded = !_heardExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      PostSaveRecordedSummaryCopy.title,
                      style: labelStyle.copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Icon(
                    _heardExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_heardExpanded) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              heardSummary,
              key: const Key('repeat_post_save_heard_body'),
              style: ArchiveMobileTypography.responsiveHelper(
                context,
              ).copyWith(color: AppColors.textPrimary, height: 1.45),
            ),
            if (widget.onCorrectTranscript != null &&
                TranscriptCorrectionGate.entryAllowsCorrection(
                  widget.entry,
                )) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('repeat_post_save_correct_transcript_button'),
                  onPressed: widget.onCorrectTranscript,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    minimumSize: const Size(0, 32),
                  ),
                  child: const Text(TranscriptCorrectionCopy.actionLabel),
                ),
              ),
            ],
            EntryImportanceButton(
              entryId: widget.entry.id,
              source: 'repeat_post_save',
              entryCount: widget.allEntries.length,
              compact: true,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const Key('repeat_post_save_view_evidence_cta'),
            onPressed: widget.onViewEvidence,
            child: const Text(PostSaveFocusedActionsCopy.viewEvidence),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton(
            key: const Key('repeat_post_save_add_one_more_moment_cta'),
            onPressed: widget.onAddOneMoreMoment,
            child: const Text(PostSaveFocusedActionsCopy.addOneMoreMoment),
          ),
          if (widget.onViewThoughtMap != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                key: const Key('repeat_post_save_view_thought_map_cta'),
                onPressed: widget.onViewThoughtMap,
                child: const Text(PostSaveFocusedActionsCopy.viewPatterns),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              key: const Key('repeat_post_save_done_for_today_cta'),
              onPressed: widget.onDoneForToday,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 36),
              ),
              child: const Text(
                VisibleArchiveProofCopy.firstSaveDoneForTodayCta,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
