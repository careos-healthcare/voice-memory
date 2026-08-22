import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_trust_copy.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/fact_ledger_resolved_citation.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/view_source_proof_sheet.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Always-visible inline citation count; opens [ViewSourceProofSheet] on tap.
class SourceCitationIndicator extends StatelessWidget {
  const SourceCitationIndicator({
    required this.citations,
    super.key,
    this.claimContext,
  });

  final List<FactLedgerResolvedCitation> citations;
  final String? claimContext;

  static Key indicatorKeyFor(String suffix) =>
      Key('source_citation_indicator_$suffix');

  @override
  Widget build(BuildContext context) {
    final count = citations.length;
    final label = EvidenceTrustCopy.sourceCount(count);
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: AppColors.textMuted,
      fontWeight: FontWeight.w600,
      height: 1.2,
    );

    if (count == 0) {
      return Text(
        label,
        key: indicatorKeyFor('empty'),
        style: style?.copyWith(color: AppColors.textMuted.withValues(alpha: 0.7)),
      );
    }

    return Semantics(
      button: true,
      label: '$label. ${EvidenceTrustCopy.viewSourceProof}',
      child: InkWell(
        key: indicatorKeyFor('tap_$count'),
        onTap: () => ViewSourceProofSheet.show(
          context,
          citations: citations,
          claimContext: claimContext,
        ),
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          child: Text(
            label,
            style: style?.copyWith(
              decoration: TextDecoration.underline,
              decorationColor: AppColors.textMuted.withValues(alpha: 0.45),
            ),
          ),
        ),
      ),
    );
  }
}
