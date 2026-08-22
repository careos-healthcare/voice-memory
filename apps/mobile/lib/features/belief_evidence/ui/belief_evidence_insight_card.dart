import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/belief_evidence/insight_evidence_line.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/cited_claim_text.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_citation_card.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_trust_copy.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/fact_ledger_resolved_citation.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Generic evidence-backed insight shell with inline fact-ledger citations.
class BeliefEvidenceInsightCard extends StatelessWidget {
  const BeliefEvidenceInsightCard({
    required this.headline,
    required this.body,
    required this.supportingEvidence,
    super.key,
    this.subheadline,
    this.footer,
    this.backgroundColor,
    this.onOpenEntry,
  });

  final String headline;
  final String body;
  final List<InsightEvidenceLine> supportingEvidence;
  final String? subheadline;
  final Widget? footer;
  final Color? backgroundColor;
  final ValueChanged<String>? onOpenEntry;

  static const Key cardKey = Key('belief_evidence_insight_card');

  @override
  Widget build(BuildContext context) {
    final titleStyle = ArchiveMobileTypography.responsiveSectionTitle(context);
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textPrimary, height: 1.45);
    final mutedStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);
    final citations = FactLedgerResolvedCitation.fromLines(supportingEvidence);

    return Container(
      key: cardKey,
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: backgroundColor ?? AppColors.backgroundSecondary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            EvidenceTrustCopy.archiveNoticed,
            style: mutedStyle.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          CitedClaimText(
            text: headline,
            style: titleStyle,
            citations: citations,
            indicatorSuffix: 'headline',
          ),
          if (subheadline case final sub?) ...[
            const SizedBox(height: AppSpacing.xs),
            CitedClaimText(
              text: sub,
              style: mutedStyle,
              citations: citations,
              indicatorSuffix: 'subheadline',
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          CitedClaimText(
            text: body,
            style: bodyStyle,
            citations: citations,
            indicatorSuffix: 'body',
          ),
          const SizedBox(height: AppSpacing.sm),
          EvidenceCitationList(
            lines: supportingEvidence,
            onOpenEntry: onOpenEntry,
          ),
          if (footer != null) ...[
            const SizedBox(height: AppSpacing.sm),
            footer!,
          ],
        ],
      ),
    );
  }
}
