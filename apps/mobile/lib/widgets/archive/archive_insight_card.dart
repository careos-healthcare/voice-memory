import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_citation_card.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_trust_copy.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/fact_ledger_resolved_citation.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/view_source_proof_section.dart';
import 'package:archiveme_mobile/features/insights/archive_insight.dart';
import 'package:archiveme_mobile/product/belief_product_copy.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:flutter/material.dart';

/// What / Why / Evidence for a single [ArchiveInsight].
class ArchiveInsightCard extends StatelessWidget {
  const ArchiveInsightCard({required this.insight, super.key, this.onTap});

  final ArchiveInsight insight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final citations = FactLedgerResolvedCitation.fromLines(
      insight.supportingEvidence,
    );

    final child = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(EvidenceTrustCopy.archiveNoticed),
        const SizedBox(height: 4),
        Text(insight.what, style: VoiceMemoryTypography.cardTitleStyle()),
        const SizedBox(height: AppSpacing.md),
        _label(BeliefProductCopy.labelWhy),
        const SizedBox(height: 4),
        Text(
          insight.why,
          style: VoiceMemoryTypography.bodyStyle(
            color: AppColors.textSecondary,
          ),
        ),
        if (insight.archiveConclusion != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _label(ConsumerUiCopy.labelWhatThisMeans),
          const SizedBox(height: 4),
          Text(
            insight.archiveConclusion!,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        // Always visible, directly under the claim: the words this is built
        // from, or an explicit statement that there are none.
        EvidenceCitationList(lines: insight.supportingEvidence),
        if (citations.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          ViewSourceProofSection(
            citations: citations,
            leadLine: EvidenceTrustCopy.supportedByEntries(citations.length),
          ),
        ],
      ],
    );

    final box = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(),
      child: child,
    );

    if (onTap == null) return box;

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(VoiceMemoryCards.radius),
        child: box,
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: VoiceMemoryTypography.metadataStyle(
      color: AppColors.accentPrimary,
    ).copyWith(fontWeight: FontWeight.w600),
  );
}
