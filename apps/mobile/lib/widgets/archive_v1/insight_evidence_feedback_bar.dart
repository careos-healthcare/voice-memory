import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:archiveme_mobile/widgets/archive_v1/insight_feed_copy.dart';
import 'package:flutter/material.dart';

/// Agree / disagree / correct actions anchored beneath cited evidence.
class InsightEvidenceFeedbackBar extends StatelessWidget {
  const InsightEvidenceFeedbackBar({
    required this.onAgree, required this.onDisagree, required this.onCorrect, super.key,
    this.busy = false,
  });

  final VoidCallback? onAgree;
  final VoidCallback? onDisagree;
  final VoidCallback? onCorrect;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('insight_evidence_feedback_bar'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          InsightFeedCopy.feedbackPrompt,
          style: VoiceMemoryTypography.secondaryStyle(
            color: VoiceMemoryColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: 4,
          children: [
            TextButton(
              key: const Key('insight_feedback_agree'),
              onPressed: busy ? null : onAgree,
              child: const Text(InsightFeedCopy.agreeLabel),
            ),
            TextButton(
              key: const Key('insight_feedback_disagree'),
              onPressed: busy ? null : onDisagree,
              child: const Text(InsightFeedCopy.disagreeLabel),
            ),
            TextButton(
              key: const Key('insight_feedback_correct'),
              onPressed: busy ? null : onCorrect,
              child: const Text(InsightFeedCopy.correctLabel),
            ),
          ],
        ),
      ],
    );
  }
}