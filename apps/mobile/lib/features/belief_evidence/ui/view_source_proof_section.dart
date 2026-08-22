import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_trust_copy.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/fact_ledger_resolved_citation.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/source_citation_indicator.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/view_source_proof_sheet.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Inline source count plus tap-to-open [ViewSourceProofSheet].
class ViewSourceProofSection extends StatelessWidget {
  const ViewSourceProofSection({
    required this.citations,
    super.key,
    this.leadLine,
    this.showArchiveNoticed = false,
    this.claimContext,
  });

  final List<FactLedgerResolvedCitation> citations;
  final String? leadLine;
  final bool showArchiveNoticed;
  final String? claimContext;

  static const Key sectionKey = Key('view_source_proof_section');
  static const Key toggleKey = Key('view_source_proof_toggle');

  @override
  Widget build(BuildContext context) {
    if (citations.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textMuted,
      height: 1.4,
    );
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: AppColors.textMuted,
      fontWeight: FontWeight.w600,
    );

    return Column(
      key: ViewSourceProofSection.sectionKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showArchiveNoticed) ...[
          Text(EvidenceTrustCopy.archiveNoticed, style: labelStyle),
          const SizedBox(height: 4),
        ],
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            SourceCitationIndicator(
              citations: citations,
              claimContext: claimContext,
            ),
            TextButton(
              key: ViewSourceProofSection.toggleKey,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: AppColors.textMuted,
                textStyle: muted?.copyWith(
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.textMuted.withValues(alpha: 0.5),
                ),
              ),
              onPressed: () => ViewSourceProofSheet.show(
                context,
                citations: citations,
                claimContext: claimContext,
              ),
              child: const Text(EvidenceTrustCopy.viewSourceProof),
            ),
          ],
        ),
        if (leadLine case final lead?) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(lead, style: muted),
        ],
      ],
    );
  }
}
