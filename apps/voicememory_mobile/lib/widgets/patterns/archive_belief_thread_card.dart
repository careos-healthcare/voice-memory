import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/archive_reactivity/archive_display_copy_guard.dart';
import '../../features/archive_evidence/archive_evidence_heuristics.dart';
import '../../features/archive_evidence/archive_belief_correction_store.dart';
import '../../features/archive_evidence/archive_belief_thread_copy.dart';
import '../../features/archive_evidence/archive_belief_thread_model.dart';
import '../../features/patterns/pattern_display_copy_gate.dart';
import '../../features/patterns/patterns_human_copy.dart';
import '../../features/tomorrow_return/active_pattern_thread_coordinator.dart';
import '../../features/tomorrow_return/active_pattern_thread_model.dart';
import '../../features/tomorrow_return/watch_for_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import 'archive_belief_correction_actions.dart';
import 'archive_evidence_timeline.dart';

/// Archive belief card — evolving evidence thread with correction loop.
class ArchiveBeliefThreadCard extends StatefulWidget {
  const ArchiveBeliefThreadCard({
    super.key,
    required this.thread,
    required this.onRecordMoreEvidence,
    this.humanCopy,
    this.onDismissed,
  });

  final ArchiveBeliefThread thread;
  final PatternHumanCopyBundle? humanCopy;
  final VoidCallback onRecordMoreEvidence;
  final VoidCallback? onDismissed;

  @override
  State<ArchiveBeliefThreadCard> createState() => _ArchiveBeliefThreadCardState();
}

class _ArchiveBeliefThreadCardState extends State<ArchiveBeliefThreadCard> {
  String? _statusMessage;

  bool get _hidden =>
      !widget.thread.hasEnoughData ||
      ArchiveBeliefCorrectionStore.isDismissed(widget.thread.suggestionId);

  Future<void> _saveThread() async {
    final now = DateTime.now();
    final currentBelief = ArchiveDisplayCopyGuard.grammarDisplayOrFallback(
      field: PatternDisplayField.currentBelief,
      text: widget.thread.currentBelief,
    );
    final whatToTest = ArchiveDisplayCopyGuard.grammarDisplayOrFallback(
      field: PatternDisplayField.whatToTest,
      text: widget.thread.whatToTest,
    );
    await ActivePatternThreadCoordinator.writeCurrentForFirstSession(
      ActivePatternThread(
        id: 'thread_${now.millisecondsSinceEpoch}',
        title: currentBelief,
        createdAt: now,
        updatedAt: now,
        watchForText: whatToTest,
        chips: const [],
        status: ActivePatternThreadStatus.active,
        daysActive: 1,
        lastResult: WatchForResult.unclear,
        nextPrompt: whatToTest,
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
    final copy = widget.humanCopy;
    final cardTitle = copy?.cardTitle ?? ArchiveBeliefThreadCopy.threadTitle;
    final evidenceFirst = copy?.isEvidenceFirstLayout ?? false;
    final repeatedPhrases = copy?.exactEvidencePhrases ?? const <String>[];
    final interpretationLabel =
        copy?.interpretationLabel ?? ArchiveBeliefThreadCopy.currentBeliefLabel;
    final confidenceLabel =
        copy?.whatChangedTitle ?? ArchiveBeliefThreadCopy.whatChangedLabel;
    final whatToNoticeLabel =
        copy?.whatToTestTitle ?? ArchiveBeliefThreadCopy.whatToTestLabel;
    final timelineTitle =
        copy?.threadOverTimeTitle ?? ArchiveBeliefThreadCopy.timelineTitle;

    final interpretation = ArchiveDisplayCopyGuard.validateAndNormalize(
      field: 'currentBelief',
      text: thread.currentBelief,
    );
    final confidenceCopy = ArchiveDisplayCopyGuard.validateAndNormalize(
      field: 'whatChanged',
      text: thread.whatChanged,
    );
    final whatToNotice = ArchiveDisplayCopyGuard.validateAndNormalize(
      field: 'whatToNotice',
      text: thread.whatToTest,
      requireSpecificity: false,
    );
    final gatedPhrases = repeatedPhrases.isNotEmpty
        ? repeatedPhrases
        : thread.evidenceSnippets;
    final whatReturned = thread.whatReturnedLine == null
        ? null
        : ArchiveDisplayCopyGuard.grammarDisplayOrFallback(
            field: PatternDisplayField.whatReturned,
            text: thread.whatReturnedLine!,
          );
    final previousBelief = thread.previousBeliefLine == null
        ? null
        : ArchiveDisplayCopyGuard.grammarDisplayOrFallback(
            field: PatternDisplayField.currentBelief,
            text: thread.previousBeliefLine!,
          );
    final whatFaded = thread.whatFadedLine == null
        ? null
        : ArchiveDisplayCopyGuard.grammarDisplayOrFallback(
            field: PatternDisplayField.whatChanged,
            text: thread.whatFadedLine!,
          );
    final worthWatching = thread.worthWatchingLine == null
        ? null
        : ArchiveDisplayCopyGuard.grammarDisplayOrFallback(
            field: PatternDisplayField.evidence,
            text: thread.worthWatchingLine!,
          );
    if (interpretation.isEmpty) return const SizedBox.shrink();

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
            cardTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.md),
          if (evidenceFirst && gatedPhrases.isNotEmpty) ...[
            Text(
              copy?.evidenceLabel ?? PatternHumanCopy.repeatedWordsLabel,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final phrase in gatedPhrases) ...[
              Text(
                '“$phrase”',
                style: ArchiveMobileTypography.body(
                  context,
                ).copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              interpretationLabel,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              interpretation,
              style: ArchiveMobileTypography.body(
                context,
              ).copyWith(color: AppColors.textPrimary),
            ),
          ] else if (thread.previousBeliefLine == null) ...[
            Text(
              interpretationLabel,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              interpretation,
              style: ArchiveMobileTypography.body(
                context,
              ).copyWith(color: AppColors.textPrimary),
            ),
          ] else ...[
            Text(
              previousBelief!,
              style: ArchiveMobileTypography.body(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${ArchiveBeliefThreadCopy.nowBeliefLabel} $interpretation',
              style: ArchiveMobileTypography.body(
                context,
              ).copyWith(color: AppColors.textPrimary),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            confidenceLabel,
            style: ArchiveMobileTypography.cardLabel(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            confidenceCopy,
            style: ArchiveMobileTypography.body(context),
          ),
          if (worthWatching != null &&
              !evidenceFirst &&
              worthWatching != confidenceCopy) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              worthWatching,
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

          if (whatReturned != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              ArchiveBeliefThreadCopy.whatReturnedLabel,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              whatReturned,
              style: ArchiveMobileTypography.body(context),
            ),
          ],
          if (!evidenceFirst && thread.evidenceSnippets.isNotEmpty) ...[
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
            whatToNoticeLabel,
            style: ArchiveMobileTypography.cardLabel(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            whatToNotice,
            style: ArchiveMobileTypography.body(context),
          ),
          if (whatFaded != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              ArchiveBeliefThreadCopy.whatFadedLabel,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              whatFaded,
              style: ArchiveMobileTypography.body(context),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          ArchiveEvidenceTimeline(steps: thread.timeline, title: timelineTitle),
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
              onSaveThread: () => _saveThread(),
              onCloseButDifferent: () =>
                  _dismiss(ArchiveBeliefThreadCopy.closeThanks),
              onNotMe: () => _dismiss(ArchiveBeliefThreadCopy.notMeThanks),
            ),
        ],
      ),
    );
  }
}
