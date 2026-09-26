import 'dart:async';

import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/core/database/database_provider.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/design/locale_date_format.dart';
import 'package:archiveme_mobile/features/evidence_contract/evidence_eligibility_policy.dart';
import 'package:archiveme_mobile/features/insights/pattern_exploration_conversation_state.dart';
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
import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_palette.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/widgets/archive/view_evidence_inline_link.dart';
import 'package:archiveme_mobile/widgets/record/post_save_follow_up.dart';
import 'package:archiveme_mobile/widgets/record/remote_processing_skipped_card.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Single post-save receipt for focused beta — local confirmation, transcript,
/// actions, and optional remote status. No stacked milestone or proof cards.
class MomentSaveReceiptCard extends StatefulWidget {
  const MomentSaveReceiptCard({
    required this.entry,
    required this.entryCount,
    required this.onRecordAnother,
    required this.onViewArchive,
    super.key,
    this.mirror,
    this.remoteStatus = MomentSaveRemoteStatus.none,
    this.syncNote,
    this.similarEntries,
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

  /// Past entries already resolved for this receipt. When omitted, the card
  /// reads the saved embedding and asks the local database.
  final List<SimilarEntry>? similarEntries;
  final VoidCallback onRecordAnother;
  final VoidCallback onViewArchive;
  final VoidCallback? onCorrectText;
  final VoidCallback? onRetryRemote;
  final VoidCallback? onTypeWhatYouSaid;
  final VoidCallback? onChooseWhatLeaves;

  @override
  State<MomentSaveReceiptCard> createState() => _MomentSaveReceiptCardState();
}

class _MomentSaveReceiptCardState extends State<MomentSaveReceiptCard> {
  List<SimilarEntry> _similar = const [];

  JournalEntry get entry => widget.entry;
  int get entryCount => widget.entryCount;
  DailyMirrorResult? get mirror => widget.mirror;
  MomentSaveRemoteStatus get remoteStatus => widget.remoteStatus;
  String? get syncNote => widget.syncNote;
  VoidCallback get onRecordAnother => widget.onRecordAnother;
  VoidCallback get onViewArchive => widget.onViewArchive;
  VoidCallback? get onCorrectText => widget.onCorrectText;
  VoidCallback? get onRetryRemote => widget.onRetryRemote;
  VoidCallback? get onTypeWhatYouSaid => widget.onTypeWhatYouSaid;
  VoidCallback? get onChooseWhatLeaves => widget.onChooseWhatLeaves;

  @override
  void initState() {
    super.initState();
    final provided = widget.similarEntries;
    if (provided != null) {
      _similar = provided;
      return;
    }
    unawaited(_loadSimilarEntries());
  }

  Future<void> _loadSimilarEntries() async {
    if (!AppServices.isInitialized) return;
    try {
      final database = DatabaseProvider(
        AppServices.instance.sqliteDatabase.database,
      );
      final vector = await database.readEmbedding(entry.id);
      if (vector == null || !mounted) return;
      final matches = await database.findSimilarEntries(vector);
      if (!mounted) return;
      setState(() => _similar = matches);
    } on Object {
      return;
    }
  }

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
    ).copyWith(color: context.palette.textPrimary, height: 1.45);
    final secondaryStyle = bodyStyle.copyWith(
      color: context.palette.textSecondary,
    );
    final heardText = postSaveRecordedSummary(entry);

    String receiptDuration(JournalEntry value) {
      final minutes = value.durationSeconds ~/ 60;
      final seconds = value.durationSeconds % 60;
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }

    return Semantics(
      container: true,
      label: MomentSaveReceiptCopy.savedOnDeviceTitle,
      child: Container(
        key: const Key('moment_save_receipt_card'),
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: VoiceMemoryCards.standard(
          context: context,
          background: Theme.of(context).colorScheme.surface,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final content = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_isDegraded && heardText.isNotEmpty) ...[
                  UserWordsQuote(
                    key: const Key('moment_save_receipt_transcript'),
                    text: heardText,
                    fontSize: 28,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${LocaleDateFormat.time(context, entry.createdAt)} · ${receiptDuration(entry)}',
                    key: const Key('moment_save_receipt_when'),
                    style: secondaryStyle,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
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
                  if (onCorrectText != null &&
                      TranscriptCorrectionGate.entryAllowsCorrection(
                        entry,
                      )) ...[
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
                      key: const Key(
                        'moment_save_receipt_relationship_evidence',
                      ),
                      style: secondaryStyle,
                    ),
                  ],
                ],
                if (_similar.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    "You've talked about this before",
                    key: const Key('moment_save_receipt_similar'),
                    style: titleStyle,
                  ),
                  ViewEvidenceInlineLink(
                    entryIds: [for (final match in _similar) match.id],
                    surface: 'moment_save_receipt_similar',
                    claimContext: "You've talked about this before",
                  ),
                  for (final match in _similar) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      LocaleDateFormat.date(context, match.createdAt),
                      key: Key('moment_save_receipt_similar_date_${match.id}'),
                      style: secondaryStyle,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      shortVerbatimQuote(match.transcript),
                      key: Key('moment_save_receipt_similar_quote_${match.id}'),
                      style: bodyStyle,
                    ),
                    if (match.localAudioPath != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _SimilarEntryPlayButton(
                          entryId: match.id,
                          audioPath: match.localAudioPath!,
                        ),
                      ),
                  ],
                ],
                if (_buildRemoteStatus(context, secondaryStyle)
                    case final status?) ...[
                  const SizedBox(height: AppSpacing.sm),
                  status,
                ],
                if (V1CapabilityRegistry.postSaveFollowUp &&
                    !_isDegraded &&
                    heardText.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  PostSaveFollowUp(entry: entry),
                ],
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  key: const Key('moment_save_receipt_record_another'),
                  onPressed: onRecordAnother,
                  child: const Text(MomentSaveReceiptCopy.recordAnother),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextButton(
                  key: const Key('moment_save_receipt_view_archive'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant,
                  ),
                  onPressed: onViewArchive,
                  child: const Text(MomentSaveReceiptCopy.viewArchive),
                ),
                _ContinueExploringCta(entry: entry),
              ],
            );
            if (!constraints.hasBoundedHeight) return content;
            return SingleChildScrollView(child: content);
          },
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

class _ContinueExploringCta extends StatelessWidget {
  const _ContinueExploringCta({required this.entry});

  final JournalEntry entry;

  static const String _label = 'Continue exploring this';

  @override
  Widget build(BuildContext context) {
    if (!V1CapabilityRegistry.patternExploration) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: OutlinedButton(
        key: const Key('moment_save_receipt_continue_exploring'),
        onPressed: () => context.push(
          RouteCatalog.explorePatterns,
          extra: ExplorePatternsSeed(
            entryId: entry.id,
            transcript: entry.transcript,
          ),
        ),
        child: const Text(_label),
      ),
    );
  }
}

class _SimilarEntryPlayButton extends StatefulWidget {
  const _SimilarEntryPlayButton({
    required this.entryId,
    required this.audioPath,
  });

  final String entryId;
  final String audioPath;

  @override
  State<_SimilarEntryPlayButton> createState() =>
      _SimilarEntryPlayButtonState();
}

class _SimilarEntryPlayButtonState extends State<_SimilarEntryPlayButton> {
  AudioPlayer? _player;

  @override
  void dispose() {
    unawaited(_player?.dispose());
    super.dispose();
  }

  Future<void> _play() async {
    final player = _player ??= AudioPlayer();
    await player.stop();
    await player.play(DeviceFileSource(widget.audioPath));
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      key: Key('moment_save_receipt_similar_play_${widget.entryId}'),
      onPressed: () => unawaited(_play()),
      icon: const Icon(Icons.play_arrow, size: 18),
      label: const Text('Play'),
    );
  }
}
