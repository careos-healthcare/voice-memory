import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_change_moment_copy.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_change_moment_model.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_trust_copy.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/fact_ledger_resolved_citation.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/view_source_proof_section.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Belief-change pattern card with fact-ledger source proof expansion.
class BeliefChangePatternCard extends StatelessWidget {
  const BeliefChangePatternCard({
    required this.moment,
    super.key,
    this.compact = false,
    this.footer,
    this.trailing,
  });

  final BeliefChangeMoment moment;
  final bool compact;
  final Widget? footer;
  final Widget? trailing;

  static const Key cardKey = Key('belief_change_pattern_card');

  @override
  Widget build(BuildContext context) {
    final titleStyle = ArchiveMobileTypography.responsiveSectionTitle(context);
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);
    final labelStyle = ArchiveMobileTypography.cardLabel(
      context,
    ).copyWith(color: AppColors.textSecondary);
    final exampleStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textPrimary, height: 1.4);

    final citations = FactLedgerResolvedCitation.fromEntryQuotes(
      items: [
        (
          entryId: moment.earlierSnippet.entryId,
          quote: moment.earlierSnippet.quote,
          label: moment.earlierSnippet.label,
        ),
        (
          entryId: moment.laterSnippet.entryId,
          quote: moment.laterSnippet.quote,
          label: moment.laterSnippet.label,
        ),
      ],
    );

    return Container(
      key: cardKey,
      width: double.infinity,
      padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF4FAF7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            EvidenceTrustCopy.archiveNoticed,
            style: labelStyle.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(BeliefChangeMomentCopy.title, style: titleStyle),
          if (!compact) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(BeliefChangeMomentCopy.body, style: bodyStyle),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(BeliefChangeMomentCopy.beliefLine, style: labelStyle),
          const SizedBox(height: 2),
          Text('"${moment.earlierBeliefExample}"', style: exampleStyle),
          const SizedBox(height: AppSpacing.sm),
          Text(BeliefChangeMomentCopy.changeLine, style: labelStyle),
          const SizedBox(height: 2),
          Text('"${moment.changeExample}"', style: exampleStyle),
          const SizedBox(height: AppSpacing.sm),
          ViewSourceProofSection(
            citations: citations,
            leadLine: EvidenceTrustCopy.supportedByEntries(citations.length),
          ),
          if (!compact) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(BeliefChangeMomentCopy.footer, style: bodyStyle),
          ],
          if (footer != null) footer!,
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
