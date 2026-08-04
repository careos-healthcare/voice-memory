import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/early_archive/first_proof_moment_analytics.dart';
import '../../features/early_archive/first_proof_moment_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import '../proof/proof_surface_why_appeared_disclosure.dart';
import '../../features/archive_proof/proof_surface_why_appeared_copy.dart';
import '../account/beta_feedback_sheet.dart';

/// Post-save emotional payoff after the third related save — no extra CTAs.
class FirstProofMomentCard extends StatefulWidget {
  const FirstProofMomentCard({
    super.key,
    required this.moment,
    required this.entryCount,
  });

  final FirstProofMoment moment;
  final int entryCount;

  @override
  State<FirstProofMomentCard> createState() => _FirstProofMomentCardState();
}

class _FirstProofMomentCardState extends State<FirstProofMomentCard> {
  var _whyExpanded = false;

  void _trackSeen() {
    FirstProofMomentAnalytics.seen(
      entryCount: widget.entryCount,
      phraseCount: widget.moment.evidencePhrases.length,
      hasStrongEvidence: widget.moment.hasStrongEvidence,
    );
  }

  void _openWhyExplanation() {
    setState(() => _whyExpanded = true);
  }

  @override
  Widget build(BuildContext context) {
    _trackSeen();
    final moment = widget.moment;
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary);
    final evidenceStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textPrimary, height: 1.4);
    final evidenceLabelStyle = ArchiveMobileTypography.cardLabel(
      context,
    ).copyWith(color: AppColors.textSecondary);

    return Container(
      key: const Key('first_proof_moment_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFFFFBF5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            moment.primaryLabel,
            key: const Key('first_proof_moment_primary_label'),
            style: ArchiveMobileTypography.cardLabel(
              context,
            ).copyWith(color: AppColors.textSecondary, letterSpacing: 0.2),
          ),
          const SizedBox(height: AppSpacing.xs),
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
          if (moment.hasStrongEvidence &&
              moment.evidencePhrases.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              button: true,
              label: moment.evidenceLabel,
              child: InkWell(
                key: const Key('first_proof_moment_evidence_label_tap'),
                onTap: _openWhyExplanation,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    moment.evidenceLabel,
                    key: const Key('first_proof_moment_evidence_label'),
                    style: evidenceLabelStyle,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              key: const Key('first_proof_moment_evidence_phrases'),
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final phrase in moment.evidencePhrases)
                  ActionChip(
                    key: Key('first_proof_moment_evidence_phrase_$phrase'),
                    label: Text(phrase),
                    onPressed: _openWhyExplanation,
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
            style: ArchiveMobileTypography.cardLabel(
              context,
            ).copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            moment.nextLine,
            key: const Key('first_proof_moment_next_line'),
            style: bodyStyle.copyWith(fontSize: 13),
          ),
          ProofSurfaceWhyAppearedDisclosure(
            body: ProofSurfaceWhyAppearedCopy.firstProof,
            surfaceKey: 'first_proof_moment',
            expanded: _whyExpanded,
            onExpandedChanged: (expanded) =>
                setState(() => _whyExpanded = expanded),
          ),
          BetaFeedbackLink(
            source: 'first_proof',
            entryCount: widget.entryCount,
          ),
        ],
      ),
    );
  }
}
