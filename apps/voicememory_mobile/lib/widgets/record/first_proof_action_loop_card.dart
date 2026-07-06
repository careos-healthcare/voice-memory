import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/first_proof_action_loop/first_proof_action_loop_analytics.dart';
import '../../features/first_proof_action_loop/first_proof_action_loop_copy.dart';
import '../../features/first_proof_action_loop/first_proof_action_loop_model.dart';
import '../../features/pattern_correction/pattern_correction_copy.dart';
import '../../features/first_proof_truth/first_proof_truth_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Next actions after the user answers the first proof truth question.
class FirstProofActionLoopCard extends StatelessWidget {
  const FirstProofActionLoopCard({
    super.key,
    required this.content,
    required this.entryCount,
    required this.onWatchThisNext,
    this.onViewPatternDetails,
    this.onRenamePattern,
    this.onKeepRecording,
    this.onCorrectTranscript,
    this.onRemoveFromPattern,
    this.onOpenPatternCorrection,
  });

  final FirstProofActionLoopContent content;
  final int entryCount;
  final VoidCallback onWatchThisNext;
  final VoidCallback? onViewPatternDetails;
  final VoidCallback? onRenamePattern;
  final VoidCallback? onKeepRecording;
  final VoidCallback? onCorrectTranscript;
  final VoidCallback? onRemoveFromPattern;
  final VoidCallback? onOpenPatternCorrection;

  String get _answerKey => switch (content.answer) {
        FirstProofTruthAnswer.yes => 'yes',
        FirstProofTruthAnswer.sortOf => 'sort_of',
        FirstProofTruthAnswer.no => 'no',
      };

  void _track(FirstProofActionType action) {
    FirstProofActionLoopAnalytics.selected(
      source: 'record',
      entryCount: entryCount,
      answer: _answerKey,
      action: action,
    );
  }

  String _labelFor(FirstProofActionType action) => switch (action) {
        FirstProofActionType.watchThisNext =>
          FirstProofActionLoopCopy.watchThisNextCta,
        FirstProofActionType.viewPatternDetails =>
          FirstProofActionLoopCopy.viewPatternDetailsCta,
        FirstProofActionType.renamePattern =>
          FirstProofActionLoopCopy.renamePatternCta,
        FirstProofActionType.keepRecording =>
          FirstProofActionLoopCopy.keepRecordingCta,
        FirstProofActionType.correctTranscript =>
          FirstProofActionLoopCopy.correctTranscriptCta,
        FirstProofActionType.removeFromPattern =>
          FirstProofActionLoopCopy.removeFromPatternCta,
      };

  VoidCallback? _handlerFor(FirstProofActionType action) => switch (action) {
        FirstProofActionType.watchThisNext => onWatchThisNext,
        FirstProofActionType.viewPatternDetails => onViewPatternDetails,
        FirstProofActionType.renamePattern => onRenamePattern,
        FirstProofActionType.keepRecording => onKeepRecording,
        FirstProofActionType.correctTranscript => onCorrectTranscript,
        FirstProofActionType.removeFromPattern => onRemoveFromPattern,
      };

  Key _keyFor(FirstProofActionType action) =>
      Key('first_proof_action_loop_${FirstProofActionLoopAnalytics.actionKey(action)}');

  @override
  Widget build(BuildContext context) {
    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
    );
    final actions = content.actions;

    return Container(
      key: Key('first_proof_action_loop_card_${content.answer.name}'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.flat(background: const Color(0xFFF8FAFC)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            content.title,
            key: const Key('first_proof_action_loop_title'),
            style: ArchiveMobileTypography.cardLabel(context),
          ),
          if (actions.isEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              FirstProofActionLoopCopy.keepRecordingCta,
              style: bodyStyle,
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.md),
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.xs),
              _ActionButton(
                actionKey: _keyFor(actions[i]),
                label: _labelFor(actions[i]),
                primary: i == 0,
                onPressed: () {
                  _track(actions[i]);
                  _handlerFor(actions[i])?.call();
                },
              ),
            ],
          ],
          if (content.answer == FirstProofTruthAnswer.no &&
              content.canShowPatternCorrection &&
              onOpenPatternCorrection != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('pattern_correction_control'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: onOpenPatternCorrection,
                child: Text(
                  PatternCorrectionCopy.controlLabel,
                  style: ArchiveMobileTypography.responsiveHelper(context)
                      .copyWith(
                    color: AppColors.textSecondary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.actionKey,
    required this.label,
    required this.primary,
    required this.onPressed,
  });

  final Key actionKey;
  final String label;
  final bool primary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (primary) {
      return FilledButton(
        key: actionKey,
        onPressed: onPressed,
        child: Text(label),
      );
    }
    return TextButton(
      key: actionKey,
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
