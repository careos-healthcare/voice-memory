import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/early_archive/first_proof_moment_analytics.dart';
import '../../features/early_archive/first_proof_moment_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Post-save emotional payoff after the third related save — no extra CTAs.
class FirstProofMomentCard extends StatelessWidget {
  const FirstProofMomentCard({
    super.key,
    required this.moment,
    required this.entryCount,
  });

  final FirstProofMoment moment;
  final int entryCount;

  void _trackSeen() {
    FirstProofMomentAnalytics.seen(
      entryCount: entryCount,
      phraseCount: moment.evidencePhrases.length,
      hasStrongEvidence: moment.hasStrongEvidence,
    );
  }

  @override
  Widget build(BuildContext context) {
    _trackSeen();
    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
    );
    final evidenceStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textPrimary,
      height: 1.4,
    );

    return Container(
      key: const Key('first_proof_moment_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: const Color(0xFFFFFBF5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            moment.title,
            key: const Key('first_proof_moment_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            moment.body,
            key: const Key('first_proof_moment_body'),
            style: bodyStyle,
          ),
          if (moment.hasStrongEvidence && moment.evidencePhrases.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              moment.evidenceLabel,
              key: const Key('first_proof_moment_evidence_label'),
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              key: const Key('first_proof_moment_evidence_phrases'),
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final phrase in moment.evidencePhrases)
                  Chip(
                    key: Key('first_proof_moment_evidence_phrase_$phrase'),
                    label: Text(phrase),
                    backgroundColor: const Color(0xFFF4F7F4),
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                    labelStyle: evidenceStyle,
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            moment.whyLine,
            key: const Key('first_proof_moment_why_line'),
            style: ArchiveMobileTypography.cardLabel(context).copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            moment.footer,
            key: const Key('first_proof_moment_footer'),
            style: bodyStyle.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }
}
