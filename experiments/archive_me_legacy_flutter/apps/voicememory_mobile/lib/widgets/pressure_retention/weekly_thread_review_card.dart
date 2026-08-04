import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/referral/invite_funnel_metrics.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../features/memory/memory_control_model.dart';
import '../../features/memory/memory_control_store.dart';
import '../../features/pressure_retention/weekly_thread_review_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import '../memory/memory_card_visibility_controls.dart';
import '../../features/memory/wrong_thread_feedback.dart';
import 'value_accuracy_feedback_row.dart';

/// Compact weekly review card: what returned, faded, or changed across the
/// archive this week, the exact evidence behind it, and one calm thing to
/// look at next week. Renders nothing without a real review. No buttons,
/// no Pro gate, no streaks.
class WeeklyThreadReviewCard extends StatelessWidget {
  const WeeklyThreadReviewCard({super.key, required this.review});

  final WeeklyThreadReview review;

  /// A specific connection is suggested only when a returned/faded/changed
  /// claim exists — bare evidence counting carries no memory controls.
  bool get _suggestsConnection =>
      review.returnedLine.isNotEmpty ||
      review.fadedLine.isNotEmpty ||
      review.changedLine.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!review.hasReview) return const SizedBox.shrink();
    // "Not related" suppresses this suggested connection for the session.
    if (_suggestsConnection &&
        (MemoryControlStore.isSuppressed(MemoryCardType.weeklyReview) ||
            WrongThreadFeedback.isSessionSuppressed(
              MemoryCardType.weeklyReview,
            ))) {
      return const SizedBox.shrink();
    }

    final governance = _suggestsConnection
        ? MemoryCardVisibilityGate.evaluateGovernance(
            cardType: MemoryCardType.weeklyReview,
            memoryUsed: true,
            entryCount: review.entryIds.length,
          )
        : null;
    final reliability = governance?.reliability;
    final blockClaim =
        _suggestsConnection &&
        MemoryCardVisibilityGate.blocksStrongClaim(
          cardType: MemoryCardType.weeklyReview,
          memoryUsed: true,
          entryCount: review.entryIds.length,
          governance: governance,
          reliability: reliability,
        );
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.weeklyThreadReviewSeen,
      oncePerSession: true,
    );
    // Invited funnel mirror — additive, attribution-gated.
    InviteFunnelMetrics.valueMomentSeen('weekly_review');

    final lines = <String>[
      if (review.evidenceLine.isNotEmpty) review.evidenceLine,
      if (review.returnedLine.isNotEmpty) review.returnedLine,
      if (review.fadedLine.isNotEmpty) review.fadedLine,
      if (review.changedLine.isNotEmpty) review.changedLine,
    ];

    return Container(
      key: const Key('weekly_thread_review_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF3F5FA),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.history_outlined,
                size: 20,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  review.title,
                  style: ArchiveMobileTypography.responsiveSectionTitle(
                    context,
                  ),
                ),
              ),
            ],
          ),
          if (_suggestsConnection && blockClaim)
            MemoryCardVisibilityControls(
              cardType: MemoryCardType.weeklyReview,
              memoryUsed: true,
              entryCount: review.entryIds.length,
              reliability: reliability,
              governance: governance,
              showCrossThreadGate: true,
            ),
          if (!blockClaim) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              review.weekSummaryLine,
              style: ArchiveMobileTypography.responsiveHelper(
                context,
              ).copyWith(color: AppColors.textSecondary),
            ),
            if (review.takeawayLine.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                review.takeawayLine,
                key: const Key('weekly_review_takeaway'),
                style: ArchiveMobileTypography.body(context).copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < lines.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(
                      Icons.circle,
                      size: 6,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      lines[i],
                      style: ArchiveMobileTypography.body(
                        context,
                      ).copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ],
            if (review.sourceTerms.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final term in review.sourceTerms)
                    _termChip(context, term),
                ],
              ),
            ],
            if (review.evidenceSnippets.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                WeeklyThreadReview.evidenceHeading,
                style: ArchiveMobileTypography.responsiveHelper(context)
                    .copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              for (final snippet in review.evidenceSnippets)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    '\u201C$snippet\u201D',
                    style: ArchiveMobileTypography.responsiveHelper(
                      context,
                    ).copyWith(color: AppColors.textPrimary),
                  ),
                ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              review.nextWeekLine,
              key: const Key('weekly_review_next_week'),
              style: ArchiveMobileTypography.responsiveHelper(
                context,
              ).copyWith(color: AppColors.textSecondary),
            ),
            if (_suggestsConnection)
              MemoryCardVisibilityControls(
                cardType: MemoryCardType.weeklyReview,
                memoryUsed: true,
                entryCount: review.entryIds.length,
                reliability: reliability,
                governance: governance,
              ),
          ],
          const ValueAccuracyFeedbackRow(cardType: 'weekly_thread_review'),
        ],
      ),
    );
  }

  Widget _termChip(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(
        label,
        style: ArchiveMobileTypography.responsiveHelper(
          context,
        ).copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
      ),
    );
  }
}
