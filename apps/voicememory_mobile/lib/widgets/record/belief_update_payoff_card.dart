import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/activation/belief_update_payoff.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Four-plus entry payoff — cautious belief update with evidence snippets.
class BeliefUpdatePayoffCard extends StatelessWidget {
  const BeliefUpdatePayoffCard({
    super.key,
    required this.payoff,
    required this.onAddAnother,
    required this.onViewEvidence,
  });

  final BeliefUpdatePayoff payoff;
  final VoidCallback onAddAnother;
  final VoidCallback onViewEvidence;

  @override
  Widget build(BuildContext context) {
    final titleStyle = ArchiveMobileTypography.responsiveSectionTitle(context);
    final bodyStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textPrimary,
      height: 1.45,
    );
    final labelStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w600,
    );
    final footnoteStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.4,
    );

    return Container(
      key: const Key('belief_update_payoff_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: AppColors.backgroundSecondary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            payoff.title,
            key: const Key('belief_update_payoff_title'),
            style: titleStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            payoff.body,
            key: const Key('belief_update_payoff_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            BeliefUpdatePayoffCopy.currentBeliefLabel,
            key: const Key('belief_update_payoff_belief_label'),
            style: labelStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            payoff.currentBelief,
            key: const Key('belief_update_payoff_current_belief'),
            style: bodyStyle,
          ),
          if (payoff.evidenceRows.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              BeliefUpdatePayoffCopy.evidenceLabel,
              key: const Key('belief_update_payoff_evidence_label'),
              style: labelStyle,
            ),
            const SizedBox(height: AppSpacing.xs),
            for (var i = 0; i < payoff.evidenceRows.length; i++) ...[
              Text(
                payoff.evidenceRows[i],
                key: Key('belief_update_payoff_evidence_$i'),
                style: bodyStyle,
              ),
              if (i < payoff.evidenceRows.length - 1)
                const SizedBox(height: AppSpacing.xs),
            ],
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            BeliefUpdatePayoffCopy.whatChangedLabel,
            key: const Key('belief_update_payoff_change_label'),
            style: labelStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            payoff.whatChangedLine,
            key: const Key('belief_update_payoff_change_line'),
            style: bodyStyle,
          ),
          if (payoff.footnoteLine case final footnote?) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              footnote,
              key: const Key('belief_update_payoff_footnote'),
              style: footnoteStyle,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const Key('belief_update_payoff_add_cta'),
            onPressed: onAddAnother,
            child: Text(payoff.primaryCta),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton(
            key: const Key('belief_update_payoff_view_evidence_cta'),
            onPressed: onViewEvidence,
            child: Text(payoff.secondaryCta),
          ),
        ],
      ),
    );
  }
}
