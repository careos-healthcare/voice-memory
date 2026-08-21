import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_belief_correction_store.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_belief_thread_copy.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_belief_thread_model.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_heuristics.dart';
import 'package:archiveme_mobile/features/tomorrow_return/active_pattern_thread_coordinator.dart';
import 'package:archiveme_mobile/features/tomorrow_return/active_pattern_thread_model.dart';
import 'package:archiveme_mobile/features/tomorrow_return/watch_for_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/widgets/patterns/archive_belief_correction_actions.dart';
import 'package:archiveme_mobile/widgets/patterns/archive_evidence_timeline.dart';
import 'package:flutter/material.dart';

/// Archive belief card — evolving evidence thread with correction loop.
class ArchiveBeliefThreadCard extends StatefulWidget {
  const ArchiveBeliefThreadCard({
    required this.thread, required this.onRecordMoreEvidence, super.key,
    this.onDismissed,
  });

  final ArchiveBeliefThread thread;
  final VoidCallback onRecordMoreEvidence;
  final VoidCallback? onDismissed;

  @override
  State<ArchiveBeliefThreadCard> createState() =>
      _ArchiveBeliefThreadCardState();
}

class _ArchiveBeliefThreadCardState extends State<ArchiveBeliefThreadCard> {
  String? _statusMessage;

  bool get _hidden =>
      !widget.thread.hasEnoughData ||
      ArchiveBeliefCorrectionStore.isDismissed(widget.thread.suggestionId);

  Future<void> _saveThread() async {
    final now = DateTime.now();
    await ActivePatternThreadCoordinator.writeCurrentForFirstSession(
      ActivePatternThread(
        id: 'thread_${now.millisecondsSinceEpoch}',
        title: widget.thread.currentBelief,
        createdAt: now,
        updatedAt: now,
        watchForText: widget.thread.whatToTest,
        chips: const [],
        status: ActivePatternThreadStatus.active,
        daysActive: 1,
        lastResult: WatchForResult.unclear,
        nextPrompt: widget.thread.whatToTest,
      ),
    );
    ArchiveBeliefCorrectionStore.markSaved(widget.thread.suggestionId);
    setState(() => _statusMessage = ArchiveBeliefThreadCopy.saveThreadThanks);
  }

  void _dismiss(String thanks) {
    ArchiveBeliefCorrectionStore.dismiss(widget.thread.suggestionId);
    setState(() => _statusMessage = thanks);
    widget.onDismissed?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();

    final thread = widget.thread;
    return Container(
      key: const Key('archive_belief_thread_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF5F9F4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ArchiveBeliefThreadCopy.threadTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.md),
          if (thread.previousBeliefLine == null) ...[
            Text(
              ArchiveBeliefThreadCopy.currentBeliefLabel,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              thread.currentBelief,
              style: ArchiveMobileTypography.body(
                context,
              ).copyWith(color: AppColors.textPrimary),
            ),
          ] else ...[
            Text(
              thread.previousBeliefLine!,
              style: ArchiveMobileTypography.body(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${ArchiveBeliefThreadCopy.nowBeliefLabel} ${thread.currentBelief}',
              style: ArchiveMobileTypography.body(
                context,
              ).copyWith(color: AppColors.textPrimary),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            ArchiveBeliefThreadCopy.evidenceLabel,
            style: ArchiveMobileTypography.cardLabel(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            thread.evidenceLine,
            style: ArchiveMobileTypography.body(context),
          ),
          if (thread.worthWatchingLine != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              thread.worthWatchingLine!,
              style: ArchiveMobileTypography.responsiveHelper(context),
            ),
          ],
          if (thread.confidenceBand != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              ArchiveBeliefThreadCopy.confidenceLabel,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              thread.confidenceBand!.label,
              style: ArchiveMobileTypography.body(context),
            ),
          ],

          if (thread.whatReturnedLine != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              ArchiveBeliefThreadCopy.whatReturnedLabel,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              thread.whatReturnedLine!,
              style: ArchiveMobileTypography.body(context),
            ),
          ],
          if (thread.evidenceSnippets.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              ArchiveBeliefThreadCopy.supportingEvidenceLabel,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final snippet in thread.evidenceSnippets) ...[
              Text(
                '“$snippet”',
                style: ArchiveMobileTypography.responsiveHelper(context),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            ArchiveBeliefThreadCopy.whatChangedLabel,
            style: ArchiveMobileTypography.cardLabel(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            thread.whatChanged,
            style: ArchiveMobileTypography.body(context),
          ),
          if (thread.whatFadedLine != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              ArchiveBeliefThreadCopy.whatFadedLabel,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              thread.whatFadedLine!,
              style: ArchiveMobileTypography.body(context),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            ArchiveBeliefThreadCopy.whatToTestLabel,
            style: ArchiveMobileTypography.cardLabel(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(thread.whatToTest, style: ArchiveMobileTypography.body(context)),
          const SizedBox(height: AppSpacing.lg),
          ArchiveEvidenceTimeline(steps: thread.timeline),
          const SizedBox(height: AppSpacing.lg),
          if (_statusMessage != null) ...[
            Text(
              _statusMessage!,
              style: ArchiveMobileTypography.responsiveHelper(context),
            ),
            const SizedBox(height: AppSpacing.sm),
          ] else
            ArchiveBeliefCorrectionActions(
              onRecordMoreEvidence: widget.onRecordMoreEvidence,
              onSaveThread: _saveThread,
              onCloseButDifferent: () =>
                  _dismiss(ArchiveBeliefThreadCopy.closeThanks),
              onNotMe: () => _dismiss(ArchiveBeliefThreadCopy.notMeThanks),
            ),
        ],
      ),
    );
  }
}