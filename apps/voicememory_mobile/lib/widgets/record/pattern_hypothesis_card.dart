import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../design/archive_responsive_layout.dart';
import '../../features/retention/pattern_hypothesis_model.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Working hypothesis card after 2+ recordings.
class PatternHypothesisCard extends StatelessWidget {
  const PatternHypothesisCard({
    super.key,
    required this.hypothesis,
    required this.onFeelsRight,
    required this.onNotMe,
    required this.onRecordNext,
    this.onViewArchive,
  });

  final PatternHypothesis hypothesis;
  final VoidCallback onFeelsRight;
  final VoidCallback onNotMe;
  final VoidCallback onRecordNext;
  final VoidCallback? onViewArchive;

  @override
  Widget build(BuildContext context) {
    if (!hypothesis.hasEnoughData) return const SizedBox.shrink();

    final gap = ArchiveResponsiveLayout.gap(context);

    return Container(
      width: double.infinity,
      padding: ArchiveResponsiveLayout.cardInsets(context),
      decoration:
          VoiceMemoryCards.standard(
            background: AppColors.accentPrimary.withValues(alpha: 0.06),
          ).copyWith(
            border: Border.all(
              color: AppColors.accentPrimary.withValues(alpha: 0.3),
            ),
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ConsumerUiCopy.patternHypothesisTitle,
            style: ArchiveMobileTypography.responsivePageTitle(context),
          ),
          SizedBox(height: gap),
          Text(
            ConsumerUiCopy.patternHypothesisLead,
            style: ArchiveMobileTypography.explanationBody(context),
          ),
          SizedBox(height: gap),
          _Section(
            label: ConsumerUiCopy.patternHypothesisMightBe,
            body: hypothesis.patternMightBe,
          ),
          SizedBox(height: gap),
          Text(
            ConsumerUiCopy.patternHypothesisEvidence,
            style: ArchiveMobileTypography.cardLabel(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final e in hypothesis.evidenceSoFar)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $e',
                style: ArchiveMobileTypography.explanationBody(context),
              ),
            ),
          SizedBox(height: gap),
          _Section(
            label: ConsumerUiCopy.patternHypothesisProveWrong,
            body: hypothesis.wouldProveWrong,
          ),
          SizedBox(height: gap),
          _Section(
            label: ConsumerUiCopy.patternHypothesisWatchNext,
            body: hypothesis.watchNext,
          ),
          SizedBox(height: gap),
          FilledButton(
            onPressed: onFeelsRight,
            child: Text(ConsumerUiCopy.patternHypothesisFeelsRight),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton(
            onPressed: onNotMe,
            child: Text(ConsumerUiCopy.postSaveInsightNotMe),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton(
            onPressed: onRecordNext,
            child: Text(ConsumerUiCopy.postSaveInsightRecordNextEvidence),
          ),
          if (onViewArchive != null) ...[
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: onViewArchive,
              child: Text(ConsumerUiCopy.viewPatternsCta),
            ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.body});

  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: ArchiveMobileTypography.cardLabel(context)),
        const SizedBox(height: AppSpacing.xs),
        Text(body, style: ArchiveMobileTypography.explanationBody(context)),
      ],
    );
  }
}
