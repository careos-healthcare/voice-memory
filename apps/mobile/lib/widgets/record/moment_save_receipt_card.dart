import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/evidence_contract/evidence_eligibility_policy.dart';
import 'package:archiveme_mobile/features/post_save/moment_save_receipt_copy.dart';
import 'package:archiveme_mobile/features/post_save/moment_save_receipt_model.dart';
import 'package:archiveme_mobile/features/post_save/post_save_repeat_copy.dart';
import 'package:archiveme_mobile/features/record/daily_mirror_model.dart';
import 'package:archiveme_mobile/features/timeline/timeline_entry_display.dart';
import 'package:archiveme_mobile/features/transcript_correction/transcript_correction_gate.dart';
import 'package:archiveme_mobile/features/trust/pending_transcript_recovery_copy.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_copy.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_quality.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/widgets/record/remote_processing_skipped_card.dart';
import 'package:flutter/material.dart';

/// Single post-save receipt for focused beta — local confirmation, transcript,
/// actions, and optional remote status. No stacked milestone or proof cards.
class MomentSaveReceiptCard extends StatelessWidget {
  const MomentSaveReceiptCard({
    required this.entry,
    required this.entryCount,
    required this.onRecordAnother,
    required this.onViewArchive,
    super.key,
    this.mirror,
    this.remoteStatus = MomentSaveRemoteStatus.none,
    this.syncNote,
    this.onCorrectText,
    this.onRetryRemote,
    this.onTypeWhatYouSaid,
    this.onChooseWhatLeaves,
  });

  final JournalEntry entry;
  final int entryCount;
  final DailyMirrorResult? mirror;
  final MomentSaveRemoteStatus remoteStatus;
  final String? syncNote;
  final VoidCallback onRecordAnother;
  final VoidCallback onViewArchive;
  final VoidCallback? onCorrectText;
  final VoidCallback? onRetryRemote;
  final VoidCallback? onTypeWhatYouSaid;
  final VoidCallback? onChooseWhatLeaves;

  bool get _isDegraded => VoiceCaptureQuality.isDegradedVoiceCapture(entry);

  String? get _relationshipLine {
    if (entryCount < EvidenceEligibilityPolicy.relatedMomentsMinimum ||
        mirror == null) {
      return null;
    }
    final display = PostSaveRepeatCopy.resolve(
      mirror!,
      admittedMomentCount: entryCount,
    );
    if (!display.show) return null;
    return display.body.trim().isNotEmpty ? display.body.trim() : null;
  }

  String? get _relationshipEvidence {
    if (entryCount < EvidenceEligibilityPolicy.relatedMomentsMinimum ||
        mirror == null) {
      return null;
    }
    final display = PostSaveRepeatCopy.resolve(
      mirror!,
      admittedMomentCount: entryCount,
    );
    return display.evidenceLine?.trim();
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = ArchiveMobileTypography.responsiveSectionTitle(context);
    final bodyStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textPrimary, height: 1.45);
    final secondaryStyle = bodyStyle.copyWith(color: AppColors.textSecondary);
    final heardText = postSaveRecordedSummary(entry);

    return Semantics(
      container: true,
      label: MomentSaveReceiptCopy.savedOnDeviceTitle,
      child: Container(
        key: const Key('moment_save_receipt_card'),
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: VoiceMemoryCards.standard(
          background: AppColors.backgroundSecondary,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                MomentSaveReceiptCopy.savedOnDeviceTitle,
                key: const Key('moment_save_receipt_title'),
                style: titleStyle,
              ),
            ),
            if (_isDegraded) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                PendingTranscriptRecoveryCopy.postSaveBody,
                key: const Key('moment_save_receipt_degraded_body'),
                style: bodyStyle,
              ),
              if (onTypeWhatYouSaid != null) ...[
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  key: const Key('moment_save_receipt_type_what_you_said'),
                  onPressed: onTypeWhatYouSaid,
                  child: const Text(VoiceCaptureCopy.typeWhatYouSaid),
                ),
              ],
            ] else if (heardText.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Semantics(
                label: 'Saved text',
                readOnly: true,
                child: Text(
                  heardText,
                  key: const Key('moment_save_receipt_transcript'),
                  style: bodyStyle,
                ),
              ),
              if (onCorrectText != null &&
                  TranscriptCorrectionGate.entryAllowsCorrection(entry)) ...[
                const SizedBox(height: AppSpacing.xs),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const Key('moment_save_receipt_correct_text'),
                    onPressed: onCorrectText,
                    child: const Text(MomentSaveReceiptCopy.correctText),
                  ),
                ),
              ],
            ],
            if (_relationshipLine case final line?) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                line,
                key: const Key('moment_save_receipt_relationship'),
                style: secondaryStyle,
              ),
              if (_relationshipEvidence case final evidence?) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  evidence,
                  key: const Key('moment_save_receipt_relationship_evidence'),
                  style: secondaryStyle,
                ),
              ],
            ],
            if (_buildRemoteStatus(context, secondaryStyle) case final status?) ...[
              const SizedBox(height: AppSpacing.sm),
              status,
            ],
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const Key('moment_save_receipt_record_another'),
              onPressed: onRecordAnother,
              child: const Text(MomentSaveReceiptCopy.recordAnother),
            ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton(
              key: const Key('moment_save_receipt_view_archive'),
              onPressed: onViewArchive,
              child: const Text(MomentSaveReceiptCopy.viewArchive),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildRemoteStatus(BuildContext context, TextStyle secondaryStyle) {
    switch (remoteStatus) {
      case MomentSaveRemoteStatus.none:
        if (syncNote == null || syncNote!.trim().isEmpty) return null;
        if (syncNote == VoiceCaptureCopy.remoteProcessingConsentPausedNote) {
          return RemoteProcessingSkippedCard(
            onChooseWhatLeaves: onChooseWhatLeaves,
          );
        }
        return Text(
          syncNote!,
          key: const Key('moment_save_receipt_sync_note'),
          style: secondaryStyle,
        );
      case MomentSaveRemoteStatus.pending:
        return Text(
          MomentSaveReceiptCopy.remoteProcessingPending,
          key: const Key('moment_save_receipt_remote_pending'),
          style: secondaryStyle,
        );
      case MomentSaveRemoteStatus.failedRetryable:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              MomentSaveReceiptCopy.remoteProcessingFailed,
              key: const Key('moment_save_receipt_remote_failed'),
              style: secondaryStyle,
            ),
            if (onRetryRemote != null) ...[
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                key: const Key('moment_save_receipt_remote_retry'),
                onPressed: onRetryRemote,
                child: const Text(MomentSaveReceiptCopy.remoteProcessingRetry),
              ),
            ],
          ],
        );
    }
  }
}
