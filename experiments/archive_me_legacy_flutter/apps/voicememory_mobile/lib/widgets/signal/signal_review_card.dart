import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../design/archive_responsive_layout.dart';
import '../../features/signal_review/signal_review_model.dart';
import '../../features/signal_review/signal_review_navigation.dart';
import '../../product/consumer_ui_copy.dart';
import '../../product/loop_mode_copy.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Compact payoff card when a signal journey reaches 3 supporting moments.
class SignalReviewCard extends StatelessWidget {
  const SignalReviewCard({
    super.key,
    required this.review,
    required this.onConfirm,
    required this.onCorrect,
    required this.onKeepWatching,
    this.onViewFull,
  });

  final SignalReview review;
  final VoidCallback onConfirm;
  final VoidCallback onCorrect;
  final VoidCallback onKeepWatching;
  final VoidCallback? onViewFull;

  @override
  Widget build(BuildContext context) {
    final gap = ArchiveResponsiveLayout.gap(context);

    if (review.needsMoreEvidence) {
      return _needsMoreCard(context, gap);
    }

    if (review.isLoopSpecificReview) {
      return _loopCard(context, gap);
    }

    return _genericCard(context, gap);
  }

  Widget _loopCard(BuildContext context, double gap) {
    return Container(
      width: double.infinity,
      padding: ArchiveResponsiveLayout.cardInsets(context),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF0F4FF),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            review.loopTitle ?? LoopModeCopy.capacityReviewTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          if (review.reviewSubtitle?.trim().isNotEmpty == true) ...[
            SizedBox(height: gap),
            Text(
              review.reviewSubtitle!,
              style: ArchiveMobileTypography.explanationBody(context),
            ),
          ],
          SizedBox(height: gap),
          _section(
            context,
            LoopModeCopy.reviewWhatRepeated,
            review.whatRepeated,
          ),
          _section(
            context,
            LoopModeCopy.reviewWhatItCost,
            review.whatItSeemedToCost ?? '',
          ),
          _section(
            context,
            review.isProveEnoughLoopReview
                ? LoopModeCopy.reviewWhatTriggeredEffort
                : LoopModeCopy.reviewWhatTriggeredYes,
            review.commonTrigger ?? '',
          ),
          _sectionList(
            context,
            LoopModeCopy.reviewEvidenceSoFar,
            review.evidenceLines,
          ),
          SizedBox(height: gap),
          if (review.isActionable) ...[
            FilledButton(
              onPressed: onKeepWatching,
              child: Text(LoopModeCopy.reviewKeepWatchingLoop),
            ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton(
              onPressed: onConfirm,
              child: Text(LoopModeCopy.reviewFeelsRight),
            ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton(
              onPressed: onCorrect,
              child: Text(LoopModeCopy.reviewCorrect),
            ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton(
              onPressed: () => SignalReviewNavigation.recordNextEvidence(
                context,
                prompt: review.nextEvidencePrompt,
              ),
              child: Text(
                review.isProveEnoughLoopReview
                    ? LoopModeCopy.reviewRecordNextProve
                    : LoopModeCopy.reviewRecordNextYes,
              ),
            ),
          ] else ...[
            OutlinedButton(
              onPressed: onKeepWatching,
              child: Text(LoopModeCopy.reviewKeepWatchingLoop),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton(
            onPressed:
                onViewFull ??
                () => SignalReviewNavigation.openFullReview(context),
            child: Text(ConsumerUiCopy.signalReviewViewFull),
          ),
        ],
      ),
    );
  }

  Widget _genericCard(BuildContext context, double gap) {
    return Container(
      width: double.infinity,
      padding: ArchiveResponsiveLayout.cardInsets(context),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF0F4FF),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ConsumerUiCopy.signalReviewCardTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          SizedBox(height: gap),
          Text(
            review.signalTitle,
            style: ArchiveMobileTypography.listTitle(context),
          ),
          SizedBox(height: gap),
          _section(
            context,
            ConsumerUiCopy.signalReviewWhatRepeated,
            review.whatRepeated,
          ),
          _section(
            context,
            ConsumerUiCopy.signalReviewWhatChanged,
            review.whatChanged,
          ),
          _sectionList(
            context,
            ConsumerUiCopy.signalReviewEvidenceSoFar,
            review.evidenceLines,
          ),
          _section(
            context,
            ConsumerUiCopy.signalReviewWhatToWatchNext,
            review.whatToWatchNext,
          ),
          SizedBox(height: gap),
          if (review.isActionable) ...[
            FilledButton(
              onPressed: onConfirm,
              child: Text(ConsumerUiCopy.signalReviewFeelsRight),
            ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton(
              onPressed: onCorrect,
              child: Text(ConsumerUiCopy.signalReviewCorrectThis),
            ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton(
              onPressed: onKeepWatching,
              child: Text(ConsumerUiCopy.signalReviewKeepWatching),
            ),
          ] else ...[
            OutlinedButton(
              onPressed: onKeepWatching,
              child: Text(ConsumerUiCopy.signalReviewKeepWatching),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton(
            onPressed:
                onViewFull ??
                () => SignalReviewNavigation.openFullReview(context),
            child: Text(ConsumerUiCopy.signalReviewViewFull),
          ),
        ],
      ),
    );
  }

  Widget _needsMoreCard(BuildContext context, double gap) {
    return Container(
      width: double.infinity,
      padding: ArchiveResponsiveLayout.cardInsets(context),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFFAFAFA),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            review.isLoopSpecificReview
                ? (review.loopTitle ?? ConsumerUiCopy.signalReviewCardTitle)
                : ConsumerUiCopy.signalReviewCardTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          SizedBox(height: gap),
          Text(
            ConsumerUiCopy.signalReviewNeedsMoreEvidence,
            style: ArchiveMobileTypography.explanationBody(context),
          ),
          SizedBox(height: gap),
          FilledButton(
            onPressed: () => SignalReviewNavigation.recordNextEvidence(
              context,
              prompt: review.nextEvidencePrompt,
            ),
            child: Text(
              review.isProveEnoughLoopReview
                  ? LoopModeCopy.reviewRecordNextProve
                  : review.isCapacityLoopReview
                  ? LoopModeCopy.reviewRecordNextYes
                  : ConsumerUiCopy.signalReviewRecordNext,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String label, String body) {
    if (body.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: ArchiveMobileTypography.cardLabel(context)),
          const SizedBox(height: AppSpacing.xs),
          Text(body, style: ArchiveMobileTypography.explanationBody(context)),
        ],
      ),
    );
  }

  Widget _sectionList(BuildContext context, String label, List<String> lines) {
    if (lines.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: ArchiveMobileTypography.cardLabel(context)),
          const SizedBox(height: AppSpacing.xs),
          for (final line in lines.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                '• $line',
                style: ArchiveMobileTypography.explanationBody(context),
              ),
            ),
        ],
      ),
    );
  }
}
