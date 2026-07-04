import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../features/voice_capture/audio/audio_debug_actions.dart';
import '../../design/archive_mobile_typography.dart';
import '../../features/archive_evidence/archive_entry_signal_guard.dart';
import '../../features/post_save/post_save_archive_hierarchy.dart';
import '../../features/post_save/post_save_recorded_summary_copy.dart';
import '../../features/record/daily_mirror_engine.dart';
import '../../features/record/daily_mirror_model.dart';
import '../../features/record/daily_mirror_stage.dart';
import '../../features/timeline/timeline_entry_display.dart';
import '../../features/trust/pending_transcript_recovery_copy.dart';
import '../../features/transcript_correction/transcript_correction_copy.dart';
import '../../features/transcript_correction/transcript_correction_gate.dart';
import '../../features/voice_capture/voice_capture_copy.dart';
import '../../widgets/record/pending_transcript_recovery_prompt.dart';
import '../../models/journal_entry.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Post-save card: heard excerpt first, then what this moment added to the archive.
class PostSaveRecordedSummaryCard extends StatelessWidget {
  const PostSaveRecordedSummaryCard({
    super.key,
    required this.entry,
    this.allEntries = const [],
    this.mirror,
    this.showAnalysisPendingNote = false,
    this.degradedBodyCopy,
    this.showSilentInputWarning = false,
    this.onAddMoreDetail,
    this.onBackToRecord,
    this.onAddWhatYouSaid,
    this.onCorrectTranscript,
    this.primaryArchiveResult,
  });

  final JournalEntry entry;
  final List<JournalEntry> allEntries;
  final DailyMirrorResult? mirror;
  final PostSavePrimaryArchiveKind? primaryArchiveResult;
  final bool showAnalysisPendingNote;
  final String? degradedBodyCopy;
  final bool showSilentInputWarning;
  final VoidCallback? onAddMoreDetail;
  final VoidCallback? onBackToRecord;
  final VoidCallback? onAddWhatYouSaid;
  final VoidCallback? onCorrectTranscript;

  List<JournalEntry> get _entries =>
      allEntries.isNotEmpty ? allEntries : [entry];

  bool get _isLowSignal => ArchiveEntrySignalGuard.isLowSignalEntry(entry);

  DailyMirrorResult get _mirror =>
      mirror ?? const DailyMirrorEngine().build(_entries);

  bool get _isFirstSavedEntry => _entries.length == 1;

  bool get _isDegraded => postSaveIsDegradedVoiceCapture(entry);

  bool get _hasHeardText => postSaveHasHeardText(entry);

  bool _shows(PostSavePrimaryArchiveKind kind) =>
      primaryArchiveResult == null || primaryArchiveResult == kind;

  @override
  Widget build(BuildContext context) {
    if (_isDegraded) {
      return _DegradedTranscriptionCard(
        entry: entry,
        bodyCopy: degradedBodyCopy ?? VoiceCaptureCopy.transcriptUnavailable,
        showSilentInputWarning: showSilentInputWarning,
        onAddWhatYouSaid: onAddWhatYouSaid,
      );
    }

    final summary = postSaveRecordedSummary(entry);
    final result = _isLowSignal ? null : _mirror;
    final labelStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w600,
    );
    final bodyStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textPrimary,
      height: 1.45,
    );
    final footnoteStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.4,
    );

    return Container(
      key: const Key('post_save_recorded_summary_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: AppColors.backgroundSecondary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            PostSaveRecordedSummaryCopy.title,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            summary,
            key: const Key('post_save_recorded_summary_body'),
            style: bodyStyle,
          ),
          if (onCorrectTranscript != null &&
              TranscriptCorrectionGate.entryAllowsCorrection(entry)) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('post_save_correct_transcript_button'),
                onPressed: onCorrectTranscript,
                child: const Text(TranscriptCorrectionCopy.actionLabel),
              ),
            ),
          ],
          if (_isLowSignal && _shows(PostSavePrimaryArchiveKind.lowSignal)) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              PostSaveRecordedSummaryCopy.whatThisAddedTitle,
              key: const Key('post_save_low_signal_what_this_added_title'),
              style: ArchiveMobileTypography.responsiveSectionTitle(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              PostSaveRecordedSummaryCopy.lowSignalWhatThisAddedBody,
              key: const Key('post_save_low_signal_what_this_added_body'),
              style: bodyStyle,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              PostSaveRecordedSummaryCopy.lowSignalPrompt,
              key: const Key('post_save_low_signal_prompt'),
              style: footnoteStyle,
            ),
            if (onAddMoreDetail != null) ...[
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                key: const Key('post_save_low_signal_add_detail_cta'),
                onPressed: onAddMoreDetail,
                child: const Text(
                  PostSaveRecordedSummaryCopy.lowSignalAddDetailCta,
                ),
              ),
            ],
            if (onBackToRecord != null) ...[
              const SizedBox(height: AppSpacing.xs),
              OutlinedButton(
                key: const Key('post_save_low_signal_back_to_record_cta'),
                onPressed: onBackToRecord,
                child: const Text(
                  PostSaveRecordedSummaryCopy.lowSignalBackToRecordCta,
                ),
              ),
            ],
          ] else if (_shows(PostSavePrimaryArchiveKind.discovery) &&
              result != null &&
              result.stage == DailyMirrorStage.possibleLoop &&
              result.hasGroundedEvidence) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              PostSaveRecordedSummaryCopy.whatThisAddedTitle,
              key: const Key('post_save_what_this_added_title'),
              style: ArchiveMobileTypography.responsiveSectionTitle(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              PostSaveRecordedSummaryCopy.connectToRepeatLabel,
              style: labelStyle,
            ),
            const SizedBox(height: 4),
            Text(
              result.heroBody,
              key: const Key('post_save_what_this_added_loop'),
              style: bodyStyle,
            ),
            if (result.evidenceLine case final evidence?) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                evidence,
                key: const Key('post_save_what_this_added_evidence'),
                style: footnoteStyle,
              ),
            ],
            if (result.nextQuestion case final next?) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                PostSaveRecordedSummaryCopy.tomorrowCheckThisLabel,
                style: labelStyle,
              ),
              const SizedBox(height: 4),
              Text(
                next,
                key: const Key('post_save_check_tomorrow'),
                style: bodyStyle,
              ),
            ],
          ] else if (_shows(PostSavePrimaryArchiveKind.discovery) &&
              result != null &&
              result.stage == DailyMirrorStage.whatChanged &&
              result.hasChange) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              PostSaveRecordedSummaryCopy.whatChangedTitle,
              key: const Key('post_save_what_changed_title'),
              style: ArchiveMobileTypography.responsiveSectionTitle(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              result.heroBody,
              key: const Key('post_save_what_changed_body'),
              style: bodyStyle,
            ),
            if (result.evidenceLine case final evidence?) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                evidence,
                key: const Key('post_save_what_changed_evidence'),
                style: footnoteStyle,
              ),
            ],
            if (result.nextQuestion case final next?) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                PostSaveRecordedSummaryCopy.tomorrowCheckThisLabel,
                style: labelStyle,
              ),
              const SizedBox(height: 4),
              Text(
                next,
                key: const Key('post_save_check_tomorrow'),
                style: bodyStyle,
              ),
            ],
          ] else if (_shows(PostSavePrimaryArchiveKind.firstEntryFootnote) &&
              _isFirstSavedEntry &&
              _hasHeardText) ...[
            const SizedBox(height: AppSpacing.sm),
            if (showAnalysisPendingNote) ...[
              Text(
                VoiceCaptureCopy.analysisUnavailableNote,
                key: const Key('post_save_analysis_pending_note'),
                style: footnoteStyle,
              ),
              const SizedBox(height: 4),
            ],
            Text(
              PostSaveRecordedSummaryCopy.firstEntryFootnote,
              key: const Key('post_save_first_entry_footnote'),
              style: footnoteStyle,
            ),
          ] else if (_shows(PostSavePrimaryArchiveKind.savedPrivately) &&
              result != null &&
              !result.hasGroundedEvidence &&
              !result.hasChange &&
              _hasHeardText) ...[
            const SizedBox(height: AppSpacing.sm),
            if (showAnalysisPendingNote) ...[
              Text(
                VoiceCaptureCopy.analysisUnavailableNote,
                key: const Key('post_save_analysis_pending_note'),
                style: footnoteStyle,
              ),
              const SizedBox(height: 4),
            ],
            Text(
              PostSaveRecordedSummaryCopy.noPatternReassurance,
              key: const Key('post_save_no_pattern_reassurance'),
              style: footnoteStyle,
            ),
          ],
        ],
      ),
    );
  }
}

class _DegradedTranscriptionCard extends StatelessWidget {
  const _DegradedTranscriptionCard({
    required this.entry,
    required this.bodyCopy,
    this.showSilentInputWarning = false,
    this.onAddWhatYouSaid,
  });

  final JournalEntry entry;
  final String bodyCopy;
  final bool showSilentInputWarning;
  final VoidCallback? onAddWhatYouSaid;

  @override
  Widget build(BuildContext context) {
    final successStyle = ArchiveMobileTypography.responsiveSectionTitle(context);
    final bodyStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textPrimary,
      height: 1.45,
    );

    return Container(
      key: const Key('post_save_degraded_transcription_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: AppColors.backgroundSecondary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PendingTranscriptRecoveryPrompt(
            onAddWhatYouSaid: onAddWhatYouSaid,
            compact: true,
          ),
          if (bodyCopy != VoiceCaptureCopy.degradedRecoveryBody &&
              bodyCopy != VoiceCaptureCopy.transcriptionFailedIssue &&
              bodyCopy != PendingTranscriptRecoveryCopy.body) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              bodyCopy,
              key: const Key('post_save_transcription_failed_body'),
              style: bodyStyle.copyWith(color: AppColors.textSecondary),
            ),
          ],
          if (kDebugMode && showSilentInputWarning) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              VoiceCaptureCopy.silentMicrophoneInputDebugWarning,
              key: const Key('post_save_silent_input_debug_warning'),
              style: bodyStyle.copyWith(color: AppColors.textSecondary),
            ),
          ],
          if (kDebugMode && (entry.localAudioPath?.trim().isNotEmpty ?? false)) ...[
            const SizedBox(height: AppSpacing.md),
            _AudioDebugControls(audioPath: entry.localAudioPath!.trim()),
          ],
        ],
      ),
    );
  }
}

class _AudioDebugControls extends StatelessWidget {
  const _AudioDebugControls({required this.audioPath});

  final String audioPath;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          key: const Key('post_save_play_recording_debug'),
          onPressed: () => AudioDebugActions.playRecording(audioPath),
          child: const Text('Play recording'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('post_save_share_audio_debug'),
          onPressed: () => AudioDebugActions.shareRecording(audioPath),
          child: const Text('Share audio file'),
        ),
      ],
    );
  }
}
