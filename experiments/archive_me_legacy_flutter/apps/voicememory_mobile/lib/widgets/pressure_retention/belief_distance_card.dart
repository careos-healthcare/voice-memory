import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/referral/invite_funnel_metrics.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../features/memory/memory_control_model.dart';
import '../../features/memory/memory_control_store.dart';
import '../../features/pressure_retention/belief_distance_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import '../memory/memory_card_visibility_controls.dart';
import '../../features/memory/wrong_thread_feedback.dart';
import 'value_accuracy_feedback_row.dart';

/// Compact belief-distance card: a repeated belief-like phrase in the user's
/// own words, how often it appeared, the exact evidence behind it, and one
/// gentle line of distance. Renders nothing without a safely formed phrase.
class BeliefDistanceCard extends StatelessWidget {
  const BeliefDistanceCard({super.key, required this.belief});

  final BeliefDistance belief;

  @override
  Widget build(BuildContext context) {
    if (!belief.hasBelief) return const SizedBox.shrink();
    // "Not related" suppresses this suggested connection for the session.
    if (MemoryControlStore.isSuppressed(MemoryCardType.beliefDistance) ||
        WrongThreadFeedback.isSessionSuppressed(
          MemoryCardType.beliefDistance,
        )) {
      return const SizedBox.shrink();
    }

    final governance = MemoryCardVisibilityGate.evaluateGovernance(
      cardType: MemoryCardType.beliefDistance,
      memoryUsed: true,
      entryCount: belief.entryIds.length,
    );
    final reliability = governance?.reliability;
    final blockClaim = MemoryCardVisibilityGate.blocksStrongClaim(
      cardType: MemoryCardType.beliefDistance,
      memoryUsed: true,
      entryCount: belief.entryIds.length,
      governance: governance,
      reliability: reliability,
    );
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.beliefDistanceSeen,
      oncePerSession: true,
    );
    // Invited funnel mirror — additive, attribution-gated.
    InviteFunnelMetrics.valueMomentSeen('belief_distance');

    return Container(
      key: const Key('belief_distance_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFFAF6F1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.format_quote_outlined,
                size: 20,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  belief.title,
                  style: ArchiveMobileTypography.responsiveSectionTitle(
                    context,
                  ),
                ),
              ),
            ],
          ),
          if (blockClaim)
            MemoryCardVisibilityControls(
              cardType: MemoryCardType.beliefDistance,
              memoryUsed: true,
              entryCount: belief.entryIds.length,
              reliability: reliability,
              governance: governance,
              showCrossThreadGate: true,
            ),
          if (!blockClaim) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              belief.beliefLine,
              style: ArchiveMobileTypography.body(
                context,
              ).copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              belief.frequencyLine,
              style: ArchiveMobileTypography.responsiveHelper(
                context,
              ).copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                _pill(context, belief.confidenceLabel),
                for (final term in belief.sourceTerms) _termChip(context, term),
              ],
            ),
            if (belief.evidenceSnippets.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                BeliefDistance.evidenceHeading,
                style: ArchiveMobileTypography.responsiveHelper(context)
                    .copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              for (final snippet in belief.evidenceSnippets)
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
              belief.distanceLine,
              key: const Key('belief_distance_line'),
              style: ArchiveMobileTypography.responsiveHelper(
                context,
              ).copyWith(color: AppColors.textSecondary),
            ),
            MemoryCardVisibilityControls(
              cardType: MemoryCardType.beliefDistance,
              memoryUsed: true,
              entryCount: belief.entryIds.length,
              reliability: reliability,
              governance: governance,
            ),
          ],
          const ValueAccuracyFeedbackRow(cardType: 'belief_distance'),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(
        label,
        style: ArchiveMobileTypography.responsiveHelper(
          context,
        ).copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
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
