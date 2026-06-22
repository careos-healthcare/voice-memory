import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/activation/third_entry_belief_payoff.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Third-entry payoff — cautious archive belief from saved words.
class ThirdEntryBeliefPayoffCard extends StatelessWidget {
  const ThirdEntryBeliefPayoffCard({
    super.key,
    required this.payoff,
    required this.onAddAnother,
    required this.onViewArchive,
  });

  final ThirdEntryBeliefPayoff payoff;
  final VoidCallback onAddAnother;
  final VoidCallback onViewArchive;

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
      key: const Key('third_entry_belief_payoff_card'),
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
            key: const Key('third_entry_belief_payoff_title'),
            style: titleStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            payoff.bodyIntro,
            key: const Key('third_entry_belief_payoff_body_intro'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            payoff.bodySource,
            key: const Key('third_entry_belief_payoff_body_source'),
            style: bodyStyle,
          ),
          if (payoff.evidenceRows.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              ThirdEntryBeliefPayoffCopy.evidenceLabel,
              key: const Key('third_entry_belief_payoff_evidence_label'),
              style: labelStyle,
            ),
            const SizedBox(height: AppSpacing.xs),
            for (var i = 0; i < payoff.evidenceRows.length; i++) ...[
              Text(
                payoff.evidenceRows[i],
                key: Key('third_entry_belief_payoff_evidence_$i'),
                style: bodyStyle,
              ),
              if (i < payoff.evidenceRows.length - 1)
                const SizedBox(height: AppSpacing.xs),
            ],
          ],
          if (payoff.thinEvidenceNote case final thinNote?) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              thinNote,
              key: const Key('third_entry_belief_payoff_thin_note'),
              style: bodyStyle,
            ),
          ],
          if (payoff.thinEvidenceAction case final thinAction?) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              thinAction,
              key: const Key('third_entry_belief_payoff_thin_action'),
              style: bodyStyle,
            ),
          ],
          if (payoff.footnoteLine case final footnote?) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              footnote,
              key: const Key('third_entry_belief_payoff_footnote'),
              style: footnoteStyle,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const Key('third_entry_belief_payoff_add_cta'),
            onPressed: onAddAnother,
            child: Text(payoff.primaryCta),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton(
            key: const Key('third_entry_belief_payoff_view_archive_cta'),
            onPressed: onViewArchive,
            child: Text(payoff.secondaryCta),
          ),
        ],
      ),
    );
  }
}
