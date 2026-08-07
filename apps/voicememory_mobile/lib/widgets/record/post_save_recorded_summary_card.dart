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
import '../../models/journal_entry.dart';
import '../../widgets/record/entry_importance_button.dart';
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
        onAddWhatYouSaid: onAddWhatYouSaid,
        onRecordAgain: onBackToRecord,
      );
    }

    final summary = postSaveRecordedSummary(entry);
    final result = _isLowSignal ? null : _mirror;
    final labelStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600);
    final bodyStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textPrimary, height: 1.45);
    final footnoteStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.4);

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
          const SizedBox(height: AppSpacing.sm),
          EntryImportanceButton(
            entryId: entry.id,
            source: 'post_save_summary',
            entryCount: _entries.length,
          ),
        ],
      ),
    );
  }
}

class _DegradedTranscriptionCard extends StatefulWidget {
  const _DegradedTranscriptionCard({
    required this.entry,
    this.onAddWhatYouSaid,
    this.onRecordAgain,
  });

  final JournalEntry entry;
  final VoidCallback? onAddWhatYouSaid;
  final VoidCallback? onRecordAgain;

  @override
  State<_DegradedTranscriptionCard> createState() =>
      _DegradedTranscriptionCardState();
}

class _DegradedTranscriptionCardState
    extends State<_DegradedTranscriptionCard> {
  bool _moreOptionsExpanded = false;

  String? get _audioPath {
    final trimmed = widget.entry.localAudioPath?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = ArchiveMobileTypography.responsiveSectionTitle(context);
    final bodyStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textPrimary, height: 1.45);
    final noteStyle = bodyStyle.copyWith(color: AppColors.textSecondary);

    return Container(
      key: const Key('post_save_degraded_transcription_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: AppColors.backgroundSecondary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            PendingTranscriptRecoveryCopy.postSaveTitle,
            key: const Key('degraded_transcript_post_save_title'),
            style: titleStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            PendingTranscriptRecoveryCopy.postSaveBody,
            key: const Key('degraded_transcript_post_save_body'),
            style: bodyStyle,
          ),
          if (widget.onAddWhatYouSaid != null) ...[
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const Key('pending_transcript_recovery_add_what_you_said'),
              onPressed: widget.onAddWhatYouSaid,
              child: Text(PendingTranscriptRecoveryCopy.primaryAction),
            ),
          ],
          if (widget.onRecordAgain != null) ...[
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton(
              key: const Key('post_save_degraded_record_again'),
              onPressed: widget.onRecordAgain,
              child: Text(VoiceCaptureCopy.recordAgainCta),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('post_save_degraded_more_options'),
              onPressed: () =>
                  setState(() => _moreOptionsExpanded = !_moreOptionsExpanded),
              child: Text(PendingTranscriptRecoveryCopy.moreOptionsLabel),
            ),
          ),
          if (_moreOptionsExpanded) ...[
            if (_audioPath != null) ...[
              OutlinedButton(
                key: const Key('post_save_play_recording'),
                onPressed: () => AudioDebugActions.playRecording(_audioPath),
                child: const Text('Play recording'),
              ),
              const SizedBox(height: AppSpacing.xs),
              OutlinedButton(
                key: const Key('post_save_share_audio'),
                onPressed: () => AudioDebugActions.shareRecording(_audioPath),
                child: const Text('Share audio file'),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            Text(
              PendingTranscriptRecoveryCopy.bluetoothAccessoryNote,
              key: const Key('post_save_degraded_bluetooth_note'),
              style: noteStyle,
            ),
          ],
        ],
      ),
    );
  }
}
